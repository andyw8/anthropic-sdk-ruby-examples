# Anthropic SDK Ruby Examples

This repository contains examples from the course [Claude with the Anthropic API](https://anthropic.skilljar.com/claude-with-the-anthropic-api/) converted to Ruby.

The examples demonstrate how to use the Anthropic SDK for Ruby to interact with Claude and build applications using the Anthropic API.

My hope is to make this a useful resources for learning and for reference.

Most of the conversion has been done by Claude (see the [custom slash command](/.claude/commands/convert.md)) but a few few manual edits were necessary.

## Examples

### Basic API Usage
- [Making a Request](03_accessing_claude_with_the_api/03_making_a_request/making_a_request.rb) - Basic example of making an API request to Claude

### Tool Use
- [Tool Functions](06_tool_use_with_claude/03_tool_functions/tool_functions.rb) - How to define and use tool functions with Claude
- [Multiple Tool Turns](06_tool_use_with_claude/08_implementing_multiple_turns/implementing_multiple_turns.rb) - Implementing conversation flows with multiple tool interactions
- [Using Multiple Tools](06_tool_use_with_claude/09_using_multiple_tools/using_multiple_tools.rb) - Working with multiple tools in a single conversation
- [Tools for Structured Data](06_tool_use_with_claude/11_tools_for_structured_data/tools_for_structured_data.rb) - Using tools to extract and manipulate structured data from text
