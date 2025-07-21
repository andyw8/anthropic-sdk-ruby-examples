# Install VoyageAI lib
# gem install voyageai

require "dotenv/load"
require "voyageai"

# Client Setup
CLIENT = VoyageAI::Client.new

# Chunk by section
def chunk_by_section(document_text)
  pattern = /\n## /
  document_text.split(pattern)
end

# Embedding Generation
def generate_embedding(text, model: "voyage-3-large", input_type: "query")
  result = CLIENT.embed([text], model: model, input_type: input_type)

  result.embeddings[0]
end

text = File.read("./report.md")

chunks = chunk_by_section(text)

generate_embedding(chunks[0])
