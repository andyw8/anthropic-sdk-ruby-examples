require "dotenv"
require "anthropic"
require "date"

# Load environment variables
Dotenv.load

# Create Anthropic client
CLIENT = Anthropic::Client.new
MODEL = "claude-3-5-sonnet-20241022"

# Helper methods
def add_user_message(messages, text)
  user_message = {role: :user, content: text}
  messages << user_message
end

def add_assistant_message(messages, text)
  assistant_message = {role: :assistant, content: text}
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [])
  params = {
    model: MODEL,
    max_tokens: 1000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  params[:system] = system if system

  message = CLIENT.messages.create(**params)
  message.content.first.text
end

# Date and time utility methods
def add_months(date, months)
  new_date = date >> months
  # Handle month-end edge cases
  if date.day != new_date.day && new_date.day == 1
    new_date -= 1
  end
  new_date
end

def add_duration_to_datetime(datetime_str, duration: 0, unit: "days", input_format: "%Y-%m-%d")
  date = DateTime.strptime(datetime_str, input_format)

  new_date = case unit
  when "seconds" then date + Rational(duration, 86400)
  when "minutes" then date + Rational(duration, 1440)
  when "hours" then date + Rational(duration, 24)
  when "days" then date + duration
  when "weeks" then date + (duration * 7)
  when "months" then add_months(date, duration)
  when "years" then date >> (duration * 12)
  else raise "Unsupported time unit: #{unit}"
  end

  new_date.strftime("%A, %B %d, %Y %I:%M:%S %p")
end

def set_reminder(content, timestamp)
  puts "----\nSetting the following reminder for #{timestamp}:\n#{content}\n----"
end

# Tool definitions
TOOLS = [
  {
    name: "add_duration_to_datetime",
    description: "Add a specified duration to a given datetime string and return the new datetime as a formatted string.",
    input_schema: {
      type: "object",
      properties: {
        datetime_str: {
          type: "string",
          description: "The initial datetime string."
        },
        duration: {
          type: "integer",
          description: "The duration to add (can be negative for subtraction).",
          default: 0
        },
        unit: {
          type: "string",
          enum: ["seconds", "minutes", "hours", "days", "weeks", "months", "years"],
          description: "The unit of the duration.",
          default: "days"
        },
        input_format: {
          type: "string",
          description: "The format of the input datetime string.",
          default: "%Y-%m-%d"
        }
      },
      required: ["datetime_str"]
    }
  },
  {
    name: "set_reminder",
    description: "Set a reminder with specific content for a given timestamp.",
    input_schema: {
      type: "object",
      properties: {
        content: {
          type: "string",
          description: "The content of the reminder."
        },
        timestamp: {
          type: "string",
          description: "The timestamp for when the reminder should trigger."
        }
      },
      required: ["content", "timestamp"]
    }
  }
]

# Example usage
if __FILE__ == $0
  # Test the functionality
  messages = []
  add_user_message(messages, "Set a reminder for tomorrow to call my dentist")

  system_prompt = "You are a helpful assistant that can manage dates and set reminders. Use the provided tools when appropriate."

  response = chat(messages, system: system_prompt)
  puts "Assistant response: #{response}"
end
