# Client Setup
require "dotenv/load"
require "voyageai"
require_relative "vector_index"

VOYAGEAI_CLIENT = VoyageAI::Client.new

# Chunk by section
def chunk_by_section(document_text)
  pattern = /\n## /
  document_text.split(pattern)
end

# Embedding Generation
def generate_embedding(chunks, model: "voyage-3-large", input_type: "query")
  is_list = chunks.is_a?(Array)
  input = is_list ? chunks : [chunks]
  result = VOYAGEAI_CLIENT.embed(input, model: model, input_type: input_type)
  is_list ? result.embeddings : result.embeddings[0]
end

text = File.read(File.join(__dir__, "report.md"))

# 1. Chunk the text by section
chunks = chunk_by_section(text)

# 2. Generate embeddings for each chunk
embeddings = generate_embedding(chunks)

# 3. Create a vector store and add each embedding to it
store = VectorIndex.new

embeddings.zip(chunks) do |embedding, chunk|
  store.add_vector(vector: embedding, document: {"content" => chunk})
end

# 4. Some time later, a user will ask a question. Generate an embedding for it
user_embedding = generate_embedding("What did the software engineering dept do last year?")

# 5. Search the store with the embedding, find the 2 most relevant chunks
results = store.search(user_embedding, k: 2)

results.each do |doc, distance|
  puts distance
  puts
  puts doc.fetch("content")[...200]
  puts
end
