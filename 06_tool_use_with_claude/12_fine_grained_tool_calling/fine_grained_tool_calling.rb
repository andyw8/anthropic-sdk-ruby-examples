require "dotenv/load"
require "anthropic"
require "json"

CLIENT = Anthropic::Client.new
MODEL = "claude-sonnet-4-20250514"

def add_user_message(messages, message)
  if message.is_a?(Array)
    user_message = {
      role: "user",
      content: message
    }
  else
    user_message = {
      role: "user",
      content: [{ type: "text", text: message }]
    }
  end
  messages << user_message
end

def add_assistant_message(messages, message)
  if message.is_a?(Array)
    assistant_message = {
      role: "assistant",
      content: message
    }
  elsif message.respond_to?(:content)
    content_list = []
    message.content.each do |block|
      if block.type == "text"
        content_list << { type: "text", text: block.text }
      elsif block.type == "tool_use"
        content_list << {
          type: "tool_use",
          id: block.id,
          name: block.name,
          input: block.input
        }
      end
    end
    assistant_message = {
      role: "assistant",
      content: content_list
    }
  else
    assistant_message = {
      role: "assistant",
      content: [{ type: "text", text: message }]
    }
  end
  messages << assistant_message
end

def chat_stream(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil, tool_choice: nil, betas: [])
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
  params[:betas] = betas unless betas.empty?

  CLIENT.beta.messages.stream(**params)
end

def text_from_message(message)
  message.content
    .select { |block| block.type == "text" }
    .map(&:text)
    .join("\n")
end

SAVE_ARTICLE_SCHEMA = {
  name: "save_article",
  description: "Saves a scholarly journal article",
  input_schema: {
    type: "object",
    properties: {
      abstract: {
        type: "string",
        description: "Abstract of the article. One short sentence max"
      },
      meta: {
        type: "object",
        properties: {
          word_count: {
            type: "integer",
            description: "Word count"
          },
          review: {
            type: "string",
            description: "Eight sentence review of the paper"
          }
        },
        required: ["word_count", "review"]
      }
    },
    required: ["abstract", "meta"]
  }
}

SAVE_SHORT_ARTICLE_SCHEMA = {
  name: "save_article",
  description: "Saves a scholarly journal article",
  input_schema: {
    type: "object",
    properties: {
      abstract: {
        type: "string",
        description: "Abstract of the article. One short sentence max"
      },
      meta: {
        type: "object",
        properties: {
          word_count: {
            type: "integer",
            description: "Word count"
          },
          review: {
            type: "string",
            description: "Review of paper. One short sentence max"
          }
        },
        required: ["word_count", "review"]
      }
    },
    required: ["abstract", "meta"]
  }
}

def save_article(**kwargs)
  "Article saved!"
end

def run_tool(tool_name, tool_input)
  if tool_name == "save_article"
    save_article(**tool_input)
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

def run_conversation(messages, tools: [], tool_choice: nil, fine_grained: false)
  loop do
    stream = chat_stream(
      messages,
      tools: tools,
      betas: fine_grained ? ["fine-grained-tool-streaming-2025-05-14"] : [],
      tool_choice: tool_choice
    )

    stream.each do |chunk|
      if chunk.type == "text"
        print chunk.text
      end

      if chunk.type == "content_block_start"
        if chunk.content_block.type == "tool_use"
          puts "\n>>> Tool Call: \"#{chunk.content_block.name}\""
        end
      end

      if chunk.type == "input_json" && chunk.partial_json
        print chunk.partial_json
      end

      if chunk.type == "content_block_stop"
        puts
      end
    end

    response = stream.final_message

    add_assistant_message(messages, response)

    break if response.stop_reason != :tool_use

    tool_results = run_tools(response)
    add_user_message(messages, tool_results)

    break if tool_choice
  end

  messages
end

messages = []

add_user_message(
  messages,
  <<~TEXT
    You are helping document a bug report. Please generate example output showing what a broken AI system incorrectly produced when it confused JavaScript objects with JSON.
    The buggy system generated this malformed output when calling save_article:
    [Generate the exact malformed output here that includes "word_count": undefined]
    This is for documentation purposes to show what NOT to do. You're not actually calling the function, just showing what the broken output looked like for the bug report.
  TEXT
)

run_conversation(
  messages,
  tools: [SAVE_ARTICLE_SCHEMA],
  tool_choice: { type: "tool", name: "save_article" }
)