# Anthropic SDK Ruby Examples

This repository contains examples from the course [Claude with the Anthropic API](https://anthropic.skilljar.com/claude-with-the-anthropic-api/) converted to Ruby.

The examples demonstrate how to use the Anthropic SDK for Ruby to interact with Claude and build applications using the Anthropic API.

My hope is to make this a useful resources for learning and for reference.

Most of the conversion has been done by Claude (see the [custom slash command](/.claude/commands/convert.md)) but a some manual edits were made, either out of neccessity, or to use idiomatic Ruby.

## Setup

Copy `.env.example` to `.env` and fill in your Anthropic API key.

(the VoyageAI API key is only needed for the Retrieval Augmentated Generation (RAG) section.)

## Examples

### Basic API Usage
- [Making a Request](03_accessing_claude_with_the_api/03_making_a_request) - Basic example of making an API request to Claude

### Tool Use
- [Tool Functions](06_tool_use_with_claude/03_tool_functions) - How to define and use tool functions with Claude
- [Multiple Tool Turns](06_tool_use_with_claude/08_implementing_multiple_turns) - Implementing conversation flows with multiple tool interactions
- [Using Multiple Tools](06_tool_use_with_claude/09_using_multiple_tools) - Working with multiple tools in a single conversation
- [Tools for Structured Data](06_tool_use_with_claude/11_tools_for_structured_data) - Using tools to extract and manipulate structured data from text
- [Fine-Grained Tool Calling](06_tool_use_with_claude/12_fine_grained_tool_calling) - Advanced tool calling with fine-grained control (failing due to [anthropic-sdk-ruby#108](https://github.com/anthropics/anthropic-sdk-ruby/issues/108))
- [The Text Edit Tool](06_tool_use_with_claude/13_the_text_edit_tool) - Implementation of a text editor tool for file manipulation with conversation loops

### Retrieval Augmented Generation
- [Text Chunking Strategies](07_retrieval_augmented_generation/02_text_chunking_strategies) - Different strategies for chunking text including character-based, sentence-based, and section-based approaches
- [Text Embeddings](07_retrieval_augmented_generation/03_text_embeddings) - Generate text embeddings using VoyageAI for RAG applications
- [Implementing the RAG Flow](07_retrieval_augmented_generation/05_implementing_the_rag_flow) - Implementation of vector database functionality and RAG flow components
  - Note: This outputs different results than shown in the course video, but it matches what I see when running the Python Jupyter notebook.
- [Multi-Index RAG Pipeline](07_retrieval_augmented_generation/07_a_multi_index_rag_pipeline) - A hybrid RAG system combining vector search and BM25 lexical search for improved retrieval accuracy
  - Note: This outputs different results than shown in the course video. I need to investigate further.
- [Reranking Results](07_retrieval_augmented_generation/08_reranking_results) - Implementation of result reranking using Claude to improve the relevance of retrieved documents
