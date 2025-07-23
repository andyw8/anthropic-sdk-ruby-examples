require "dotenv/load"
require "voyageai"
require_relative "vector_index"
require_relative "bm25_index"
require_relative "retriever"

# Client Setup
VOYAGEAI_CLIENT = VoyageAI::Client.new

# Chunk by section
def chunk_by_section(document_text)
  document_text.split("\n## ")
end

# Embedding Generation
def generate_embedding(chunks, model: "voyage-3-large", input_type: "query")
  is_list = chunks.is_a?(Array)
  input = is_list ? chunks : [chunks]
  result = VOYAGEAI_CLIENT.embed(input, model: model, input_type: input_type)
  is_list ? result.embeddings : result.embeddings[0]
end

# Chunk source text by section
text = File.read(File.join(__dir__, "..", "report.md"))
chunks = chunk_by_section(text)

# Create a vector index, a bm25 index, then use them to create a Retriever
vector_index = VectorIndex.new(embedding_fn: method(:generate_embedding))
bm25_index = BM25Index.new

retriever = Retriever.new(bm25_index, vector_index)

# Add all chunks to the retriever, which internally passes them along to both indexes
# Note: converted to a bulk operation to avoid rate limiting errors from VoyageAI
retriever.add_documents(chunks.map { |chunk| {"content" => chunk} })

results = retriever.search("what happened with INC-2023-Q4-011?", k: 3)

results.each do |doc, score|
  puts score
  puts doc["content"][...200]
  puts "---"
end
