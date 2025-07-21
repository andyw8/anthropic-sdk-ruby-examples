require "dotenv/load"
require "anthropic"
require "date"
require "json"

# Load env variables and create client
CLIENT = Anthropic::Client.new
MODEL = "claude-3-5-sonnet-20241022"

# Helper functions
def add_user_message(messages, message)
  user_message = {
    role: "user",
    content: message.is_a?(Anthropic::Messages::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    role: "assistant",
    content: message.is_a?(Anthropic::Messages::Message) ? message.content : message
  }
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil, tool_choice: nil)
  params = {
    model: MODEL,
    max_tokens: 1000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  params[:tool_choice] = tool_choice if tool_choice
  params[:tools] = tools if tools
  params[:system] = system if system

  message = CLIENT.messages(params)
  message
end

def text_from_message(message)
  message.content.select { |block| block.type == "text" }.map(&:text).join("\n")
end

# Tools and Schemas
ARTICLE_SUMMARY_SCHEMA = {
  name: "article_summary",
  description: "Creates a summary of an article with its key insights. Use this tool when you need to generate a structured summary of an article, research paper, or any textual content. The tool requires the article's title, author name, and a list of the most important insights or takeaways from the content. Each insight should be a concise statement capturing a significant point from the article.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "The title of the article being summarized."
      },
      author: {
        type: "string",
        description: "The name of the author who wrote the article."
      },
      key_insights: {
        type: "array",
        items: { type: "string" },
        description: "A list of the most important takeaways or insights from the article. Each insight should be a complete, concise statement."
      }
    },
    required: %w[title author key_insights]
  }
}

def add_duration_to_datetime(datetime_str, duration: 0, unit: "days", input_format: "%Y-%m-%d")
  date = Date.strptime(datetime_str, input_format)
  
  new_date = case unit
  when "seconds"
    date + Rational(duration, 86400) # seconds in a day
  when "minutes"
    date + Rational(duration, 1440) # minutes in a day
  when "hours"
    date + Rational(duration, 24) # hours in a day
  when "days"
    date + duration
  when "weeks"
    date + (duration * 7)
  when "months"
    date >> duration
  when "years"
    date >> (duration * 12)
  else
    raise ArgumentError, "Unsupported time unit: #{unit}"
  end

  new_date.strftime("%A, %B %d, %Y %I:%M:%S %p")
end

def set_reminder(content:, timestamp:)
  puts "----\nSetting the following reminder for #{timestamp}:\n#{content}\n----"
end

ADD_DURATION_TO_DATETIME_SCHEMA = {
  name: "add_duration_to_datetime",
  description: "Adds a specified duration to a datetime string and returns the resulting datetime in a detailed format. This tool converts an input datetime string to a Ruby Date object, adds the specified duration in the requested unit, and returns a formatted string of the resulting datetime. It handles various time units including seconds, minutes, hours, days, weeks, months, and years, with special handling for month and year calculations to account for varying month lengths and leap years. The output is always returned in a detailed format that includes the day of the week, month name, day, year, and time with AM/PM indicator (e.g., 'Thursday, April 03, 2025 10:30:00 AM').",
  input_schema: {
    type: "object",
    properties: {
      datetime_str: {
        type: "string",
        description: "The input datetime string to which the duration will be added. This should be formatted according to the input_format parameter."
      },
      duration: {
        type: "number",
        description: "The amount of time to add to the datetime. Can be positive (for future dates) or negative (for past dates). Defaults to 0."
      },
      unit: {
        type: "string",
        description: "The unit of time for the duration. Must be one of: 'seconds', 'minutes', 'hours', 'days', 'weeks', 'months', or 'years'. Defaults to 'days'."
      },
      input_format: {
        type: "string",
        description: "The format string for parsing the input datetime_str, using Ruby's strptime format codes. For example, '%Y-%m-%d' for ISO format dates like '2025-04-03'. Defaults to '%Y-%m-%d'."
      }
    },
    required: %w[datetime_str]
  }
}

SET_REMINDER_SCHEMA = {
  name: "set_reminder",
  description: "Creates a timed reminder that will notify the user at the specified time with the provided content. This tool schedules a notification to be delivered to the user at the exact timestamp provided. It should be used when a user wants to be reminded about something specific at a future point in time. The reminder system will store the content and timestamp, then trigger a notification through the user's preferred notification channels (mobile alerts, email, etc.) when the specified time arrives. Reminders are persisted even if the application is closed or the device is restarted. Users can rely on this function for important time-sensitive notifications such as meetings, tasks, medication schedules, or any other time-bound activities.",
  input_schema: {
    type: "object",
    properties: {
      content: {
        type: "string",
        description: "The message text that will be displayed in the reminder notification. This should contain the specific information the user wants to be reminded about, such as 'Take medication', 'Join video call with team', or 'Pay utility bills'."
      },
      timestamp: {
        type: "string",
        description: "The exact date and time when the reminder should be triggered, formatted as an ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS) or a Unix timestamp. The system handles all timezone processing internally, ensuring reminders are triggered at the correct time regardless of where the user is located. Users can simply specify the desired time without worrying about timezone configurations."
      }
    },
    required: %w[content timestamp]
  }
}

BATCH_TOOL_SCHEMA = {
  name: "batch_tool",
  description: "Invoke multiple other tool calls simultaneously",
  input_schema: {
    type: "object",
    properties: {
      invocations: {
        type: "array",
        description: "The tool calls to invoke",
        items: {
          type: "object",
          properties: {
            name: {
              type: "string",
              description: "The name of the tool to invoke"
            },
            arguments: {
              type: "string",
              description: "The arguments to the tool, encoded as a JSON string"
            }
          },
          required: %w[name arguments]
        }
      }
    },
    required: %w[invocations]
  }
}

# get_current_datetime tool function
def get_current_datetime(date_format: "%Y-%m-%d %H:%M:%S")
  raise ArgumentError, "date_format cannot be empty" if date_format.nil? || date_format.empty?
  
  Time.now.strftime(date_format)
end

GET_CURRENT_DATETIME_SCHEMA = {
  name: "get_current_datetime",
  description: "Returns the current date and time formatted according to the specified format string. This tool provides the current system time formatted as a string. Use this tool when you need to know the current date and time, such as for timestamping records, calculating time differences, or displaying the current time to users. The default format returns the date and time in ISO-like format (YYYY-MM-DD HH:MM:SS).",
  input_schema: {
    type: "object",
    properties: {
      date_format: {
        type: "string",
        description: "A string specifying the format of the returned datetime. Uses Ruby's strftime format codes. For example, '%Y-%m-%d' returns just the date in YYYY-MM-DD format, '%H:%M:%S' returns just the time in HH:MM:SS format, '%B %d, %Y' returns a date like 'May 07, 2025'. The default is '%Y-%m-%d %H:%M:%S' which returns a complete timestamp like '2025-05-07 14:32:15'.",
        default: "%Y-%m-%d %H:%M:%S"
      }
    },
    required: []
  }
}

# Tool Running
def run_batch(invocations: [])
  batch_output = []

  invocations.each do |invocation|
    name = invocation["name"]
    args = JSON.parse(invocation["arguments"])

    tool_output = run_tool(name, args)

    batch_output << { tool_name: name, output: tool_output }
  end

  batch_output
end

def run_tool(tool_name, tool_input)
  case tool_name
  when "get_current_datetime"
    get_current_datetime(**tool_input.transform_keys(&:to_sym))
  when "add_duration_to_datetime"
    add_duration_to_datetime(**tool_input.transform_keys(&:to_sym))
  when "set_reminder"
    set_reminder(**tool_input.transform_keys(&:to_sym))
  when "batch_tool"
    run_batch(**tool_input.transform_keys(&:to_sym))
  else
    raise ArgumentError, "Unknown tool: #{tool_name}"
  end
end

def run_tools(message)
  tool_requests = message.content.select { |block| block.type == "tool_use" }
  tool_result_blocks = []

  tool_requests.each do |tool_request|
    begin
      tool_output = run_tool(tool_request.name, tool_request.input)
      tool_result_block = {
        type: "tool_result",
        tool_use_id: tool_request.id,
        content: JSON.dump(tool_output),
        is_error: false
      }
    rescue => e
      tool_result_block = {
        type: "tool_result",
        tool_use_id: tool_request.id,
        content: "Error: #{e}",
        is_error: true
      }
    end

    tool_result_blocks << tool_result_block
  end

  tool_result_blocks
end

# Run conversation
def run_conversation(messages)
  loop do
    response = chat(
      messages,
      tools: [
        GET_CURRENT_DATETIME_SCHEMA,
        ADD_DURATION_TO_DATETIME_SCHEMA,
        SET_REMINDER_SCHEMA,
        BATCH_TOOL_SCHEMA
      ]
    )

    add_assistant_message(messages, response)
    puts text_from_message(response)

    break if response.stop_reason != :tool_use

    tool_results = run_tools(response)
    add_user_message(messages, tool_results)
  end

  messages
end

# Example usage
messages = []
add_user_message(
  messages,
  "Write a one-paragraph scholarly article about computer science. Include a title and author name."
)
response = chat(messages)
puts text_from_message(response)

# Example usage with article summary tool
messages = []
add_user_message(messages, text_from_message(response))
response = chat(
  messages,
  tools: [ARTICLE_SUMMARY_SCHEMA],
  tool_choice: { type: "tool", name: "article_summary" }
)
puts response.content[0].input