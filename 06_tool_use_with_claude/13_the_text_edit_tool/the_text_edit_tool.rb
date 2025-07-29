require "dotenv/load"
require "anthropic"
require "json"
require "fileutils"

# Load env variables and create client
CLIENT = Anthropic::Client.new
MODEL = "claude-3-5-sonnet-20241022"

# Helper functions
def add_user_message(messages, message)
  user_message = {
    role: "user",
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    role: "assistant",
    content: message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << assistant_message
end

def chat(messages, system: nil, temperature: 1.0, stop_sequences: [], tools: nil)
  params = {
    model: MODEL,
    max_tokens: 1000,
    messages: messages,
    temperature: temperature,
    stop_sequences: stop_sequences
  }

  params[:tools] = tools if tools
  params[:system] = system if system

  CLIENT.messages.create(**params)
end

def text_from_message(message)
  message.content
    .select { |block| block.type == :text }
    .map(&:text)
    .join("\n")
end

# Implementation of the TextEditorTool
class TextEditorTool
  def initialize(base_dir: "", backup_dir: "")
    @base_dir = base_dir.empty? ? Dir.pwd : base_dir
    @backup_dir = backup_dir.empty? ? File.join(@base_dir, ".backups") : backup_dir
    FileUtils.mkdir_p(@backup_dir)
  end

  private

  def validate_path(file_path)
    abs_path = File.expand_path(File.join(@base_dir, file_path))
    unless abs_path.start_with?(@base_dir)
      raise ArgumentError, "Access denied: Path '#{file_path}' is outside the allowed directory"
    end
    abs_path
  end

  def backup_file(file_path)
    return "" unless File.exist?(file_path)

    file_name = File.basename(file_path)
    backup_path = File.join(@backup_dir, "#{file_name}.#{File.mtime(file_path).to_i}")
    FileUtils.cp(file_path, backup_path, preserve: true)
    backup_path
  end

  def restore_backup(file_path)
    file_name = File.basename(file_path)
    backups = Dir.entries(@backup_dir)
      .select { |f| f.start_with?("#{file_name}.") }

    raise Errno::ENOENT, "No backups found for #{file_path}" if backups.empty?

    latest_backup = backups.max
    backup_path = File.join(@backup_dir, latest_backup)

    FileUtils.cp(backup_path, file_path, preserve: true)
    "Successfully restored #{file_path} from backup"
  end

  def count_matches(content, old_str)
    content.scan(old_str).length
  end

  public

  def view(file_path, view_range: nil)
    abs_path = validate_path(file_path)

    if File.directory?(abs_path)
      begin
        return Dir.entries(abs_path).reject { |f| f.start_with?(".") }.join("\n")
      rescue Errno::EACCES
        raise Errno::EACCES, "Permission denied. Cannot list directory contents."
      end
    end

    raise Errno::ENOENT, "File not found" unless File.exist?(abs_path)

    begin
      content = File.read(abs_path, encoding: "utf-8")
    rescue Encoding::UndefinedConversionError
      raise Encoding::UndefinedConversionError, "File contains non-text content and cannot be displayed."
    end

    if view_range
      start_line, end_line = view_range
      lines = content.split("\n")

      end_line = lines.length if end_line == -1

      selected_lines = lines[(start_line - 1)...end_line]

      result = []
      selected_lines.each_with_index do |line, index|
        result << "#{start_line + index}: #{line}"
      end

    else
      lines = content.split("\n")
      result = []
      lines.each_with_index do |line, index|
        result << "#{index + 1}: #{line}"
      end

    end
    result.join("\n")
  rescue Errno::EACCES
    raise Errno::EACCES, "Permission denied. Cannot access file."
  end

  def str_replace(file_path, old_str, new_str)
    abs_path = validate_path(file_path)

    raise Errno::ENOENT, "File not found" unless File.exist?(abs_path)

    content = File.read(abs_path, encoding: "utf-8")

    match_count = count_matches(content, old_str)

    if match_count == 0
      raise ArgumentError, "No match found for replacement. Please check your text and try again."
    elsif match_count > 1
      raise ArgumentError, "Found #{match_count} matches for replacement text. Please provide more context to make a unique match."
    end

    backup_file(abs_path)

    new_content = content.gsub(old_str, new_str)

    File.write(abs_path, new_content, encoding: "utf-8")

    "Successfully replaced text at exactly one location."
  rescue Errno::EACCES
    raise Errno::EACCES, "Permission denied. Cannot modify file."
  end

  def create(file_path, file_text)
    abs_path = validate_path(file_path)

    if File.exist?(abs_path)
      raise Errno::EEXIST, "File already exists. Use str_replace to modify it."
    end

    FileUtils.mkdir_p(File.dirname(abs_path))

    File.write(abs_path, file_text, encoding: "utf-8")

    "Successfully created #{file_path}"
  rescue Errno::EACCES
    raise Errno::EACCES, "Permission denied. Cannot create file."
  end

  def insert(file_path, insert_line, new_str)
    abs_path = validate_path(file_path)

    raise Errno::ENOENT, "File not found" unless File.exist?(abs_path)

    backup_file(abs_path)

    lines = File.readlines(abs_path, chomp: false)

    new_str = "\n#{new_str}" if !lines.empty? && !lines[-1].end_with?("\n")

    if insert_line == 0
      lines.unshift("#{new_str}\n")
    elsif insert_line > 0 && insert_line <= lines.length
      lines.insert(insert_line, "#{new_str}\n")
    else
      raise IndexError, "Line number #{insert_line} is out of range. File has #{lines.length} lines."
    end

    File.write(abs_path, lines.join)

    "Successfully inserted text after line #{insert_line}"
  rescue Errno::EACCES
    raise Errno::EACCES, "Permission denied. Cannot modify file."
  end

  def undo_edit(file_path)
    abs_path = validate_path(file_path)

    raise Errno::ENOENT, "File not found" unless File.exist?(abs_path)

    restore_backup(abs_path)
  rescue Errno::ENOENT => e
    raise Errno::ENOENT, "No previous edits to undo" if e.message.include?("No backups found")
    raise
  rescue Errno::EACCES
    raise Errno::EACCES, "Permission denied. Cannot restore file."
  end
end

# Process Tool Call Requests
TEXT_EDITOR_TOOL = TextEditorTool.new(base_dir: Dir.pwd)

def run_tool(tool_name, tool_input)
  case tool_name
  when "str_replace_editor"
    command = tool_input[:command]
    case command
    when "view"
      TEXT_EDITOR_TOOL.view(
        tool_input[:path],
        view_range: tool_input[:view_range]
      )
    when "str_replace"
      TEXT_EDITOR_TOOL.str_replace(
        tool_input[:path],
        tool_input[:old_str],
        tool_input[:new_str]
      )
    when "create"
      TEXT_EDITOR_TOOL.create(
        tool_input[:path],
        tool_input[:file_text]
      )
    when "insert"
      TEXT_EDITOR_TOOL.insert(
        tool_input[:path],
        tool_input[:insert_line],
        tool_input[:new_str]
      )
    when "undo_edit"
      TEXT_EDITOR_TOOL.undo_edit(tool_input[:path])
    else
      raise StandardError, "Unknown text editor command: #{command}"
    end
  else
    raise StandardError, "Unknown tool name: #{tool_name}"
  end
end

def run_tools(message)
  tool_requests = message.content.select { |block| block.type == :tool_use }
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

# Make the text edit schema based on the model version being used
def get_text_edit_schema(model)
  case model
  when /^claude-3-5-sonnet/
    {
      type: "text_editor_20250124",
      name: "str_replace_editor"
    }
  when /^claude-3-7-sonnet/
    {
      type: "text_editor_20250124",
      name: "str_replace_editor"
    }
  else
    raise ArgumentError, "Editor schema version not known for model: #{model}. Reference Anthropic docs for the correct schema version."
  end
end

# Run the conversation in a loop until the model doesn't ask for a tool use
def run_conversation(messages)
  loop do
    response = chat(
      messages,
      tools: [get_text_edit_schema(MODEL)]
    )

    add_assistant_message(messages, response)
    puts text_from_message(response)

    break if response.stop_reason != :tool_use

    tool_results = run_tools(response)
    add_user_message(messages, tool_results)
  end

  messages
end

messages = []

add_user_message(
  messages,
  # "Open the ./main.rb file and write out a method to calculate pi to the 5th digit. Then create a `/test.rb` file to test your implementation."
  "Open the 06_tool_use_with_claude/13_the_text_edit_tool/main.rb file and summarize its contents. if it cannot be found, list the paths that were checked."
)

run_conversation(messages)
