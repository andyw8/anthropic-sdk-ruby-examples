# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Ruby examples converted from the Anthropic "Claude with the Anthropic API" course. It demonstrates how to use the Anthropic SDK for Ruby to build AI-powered applications across 13 structured sections covering basic API usage, tool use, RAG implementation, and advanced Claude features.

## Common Commands

- `bundle install` - Install dependencies
- `bundle exec standardrb` - Run linter/formatter (required before commits)
- `bundle exec standardrb --fix` - Auto-fix style issues
- `bundle exec ruby -wc filename.rb` - Check Ruby syntax validity

## Code Architecture

### Directory Structure
- `03_accessing_claude_with_the_api/` - Course sections (numbered directories)
- `03_accessing_claude_with_the_api/03_making_a_request Course chapters (numbered directories)

### Key Patterns
- Client initialization: `CLIENT = Anthropic::Client.new` (constant, not variable)
- VoyageAI client: `VOYAGEAI_CLIENT` (for embeddings in RAG examples)
- Environment loading: `require "dotenv/load"` at top of files
- Message helpers: `add_user_message`, `add_assistant_message` functions
- Tool schemas use keyword arguments over positional arguments
- Use `is_a?(Anthropic::ClassName)` for type checks, not `respond_to?`
- String comparisons use symbols (e.g., `response.stop_reason == :tool_use`)

## Dependencies

Core gems from Gemfile:
- `anthropic` (from GitHub) - Official Anthropic SDK
- `dotenv` - Environment variable management
- `voyageai` - Embeddings for RAG examples
- `standard` - Ruby code formatting/linting
- `debug` - Debugging support

## Development Notes

- Examples are meant to be run individually, not as a test suite
- StandardRB is enforced via CI - always run before committing
- Many examples require ANTHROPIC_API_KEY in .env file, assume already present.
- Run examples from the root directory ensure the .env file is loaded
- RAG examples additionally require VOYAGEAI_API_KEY
- Some examples have known issues (see README for details)
