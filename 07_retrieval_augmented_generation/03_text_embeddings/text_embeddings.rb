require "dotenv/load"
require "voyageai"
require_relative "../../helpers/vcr"

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

with_vcr(:text_embeddings) do
  text = File.read(File.join(__dir__, "..", "report.md"))

  chunks = chunk_by_section(text)

  pp generate_embedding(chunks[0])
end
