require "dotenv/load"
require "anthropic"
require "voyageai"
require "json"
require_relative "../../helpers/vcr"

# Client Setup
VOYAGEAI_CLIENT = VoyageAI::Client.new
ANTHROPIC_CLIENT = Anthropic::Client.new
MODEL = "claude-3-7-sonnet-latest"

# Helper functions
def add_user_message(messages, message)
  user_message = {
    "role" => "user",
    "content" => message.is_a?(Anthropic::Message) ? message.content : message
  }
  messages << user_message
end

def add_assistant_message(messages, message)
  assistant_message = {
    "role" => "assistant",
    "content" => message.is_a?(Anthropic::Message) ? message.content : message
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

  ANTHROPIC_CLIENT.messages.create(**params)
end

def text_from_message(message)
  message.content.select { |block| block.type == :text }.map(&:text).join("\n")
end

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

# VectorIndex implementation
class VectorIndex
  attr_reader :vectors, :documents

  def initialize(distance_metric: "cosine", embedding_fn: nil)
    @vectors = []
    @documents = []
    @vector_dim = nil
    unless ["cosine", "euclidean"].include?(distance_metric)
      raise ArgumentError, "distance_metric must be 'cosine' or 'euclidean'"
    end
    @distance_metric = distance_metric
    @embedding_fn = embedding_fn
  end

  def add_document(document)
    raise ArgumentError, "Embedding function not provided during initialization." unless @embedding_fn
    raise TypeError, "Document must be a hash." unless document.is_a?(Hash)
    raise ArgumentError, "Document hash must contain a 'content' key." unless document.key?("content")

    content = document["content"]
    raise TypeError, "Document 'content' must be a string." unless content.is_a?(String)

    vector = @embedding_fn.call(content)
    add_vector(vector: vector, document: document)
  end

  def add_documents(documents)
    raise ArgumentError, "Embedding function not provided during initialization." unless @embedding_fn
    raise TypeError, "Documents must be an array of hashes." unless documents.is_a?(Array)

    return if documents.empty?

    contents = []
    documents.each_with_index do |doc, i|
      raise TypeError, "Document at index #{i} must be a hash." unless doc.is_a?(Hash)
      raise ArgumentError, "Document at index #{i} must contain a 'content' key." unless doc.key?("content")
      raise TypeError, "Document 'content' at index #{i} must be a string." unless doc["content"].is_a?(String)
      contents << doc["content"]
    end

    vectors = @embedding_fn.call(contents)

    vectors.zip(documents).each do |vector, document|
      add_vector(vector: vector, document: document)
    end
  end

  def search(query, k: 1)
    return [] if @vectors.empty?

    query_vector = if query.is_a?(String)
      raise ArgumentError, "Embedding function not provided for string query." unless @embedding_fn
      @embedding_fn.call(query)
    elsif query.is_a?(Array) && query.all? { |x| x.is_a?(Numeric) }
      query
    else
      raise TypeError, "Query must be either a string or an array of numbers."
    end

    return [] if @vector_dim.nil?

    if query_vector.length != @vector_dim
      raise ArgumentError, "Query vector dimension mismatch. Expected #{@vector_dim}, got #{query_vector.length}"
    end

    raise ArgumentError, "k must be a positive integer." if k <= 0

    dist_func = (@distance_metric == "cosine") ? method(:cosine_distance) : method(:euclidean_distance)

    distances = []
    @vectors.each_with_index do |stored_vector, i|
      distance = dist_func.call(query_vector, stored_vector)
      distances << [distance, @documents[i]]
    end

    distances.sort_by!(&:first)

    distances.first(k).map { |dist, doc| [doc, dist] }
  end

  def add_vector(vector:, document:)
    unless vector.is_a?(Array) && vector.all? { |x| x.is_a?(Numeric) }
      raise TypeError, "Vector must be an array of numbers."
    end
    raise TypeError, "Document must be a hash." unless document.is_a?(Hash)
    raise ArgumentError, "Document hash must contain a 'content' key." unless document.key?("content")

    if @vectors.empty?
      @vector_dim = vector.length
    elsif vector.length != @vector_dim
      raise ArgumentError, "Inconsistent vector dimension. Expected #{@vector_dim}, got #{vector.length}"
    end

    @vectors << vector.dup
    @documents << document
  end

  def length
    @vectors.length
  end

  def to_s
    has_embed_fn = @embedding_fn ? "Yes" : "No"
    "VectorIndex(count=#{length}, dim=#{@vector_dim}, metric='#{@distance_metric}', has_embedding_fn='#{has_embed_fn}')"
  end

  private

  def euclidean_distance(vec1, vec2)
    raise ArgumentError, "Vectors must have the same dimension" if vec1.length != vec2.length
    Math.sqrt(vec1.zip(vec2).sum { |p, q| (p - q)**2 })
  end

  def dot_product(vec1, vec2)
    raise ArgumentError, "Vectors must have the same dimension" if vec1.length != vec2.length
    vec1.zip(vec2).sum { |p, q| p * q }
  end

  def magnitude(vec)
    Math.sqrt(vec.sum { |x| x * x })
  end

  def cosine_distance(vec1, vec2)
    raise ArgumentError, "Vectors must have the same dimension" if vec1.length != vec2.length

    mag1 = magnitude(vec1)
    mag2 = magnitude(vec2)

    return 0.0 if mag1 == 0 && mag2 == 0
    return 1.0 if mag1 == 0 || mag2 == 0

    dot_prod = dot_product(vec1, vec2)
    cosine_similarity = dot_prod / (mag1 * mag2)
    cosine_similarity = cosine_similarity.clamp(-1.0, 1.0)

    1.0 - cosine_similarity
  end
end

# BM25 implementation
class BM25Index
  attr_reader :documents

  def initialize(k1: 1.5, b: 0.75, tokenizer: nil)
    @documents = []
    @corpus_tokens = []
    @doc_len = []
    @doc_freqs = {}
    @avg_doc_len = 0.0
    @idf = {}
    @index_built = false

    @k1 = k1
    @b = b
    @tokenizer = tokenizer || method(:default_tokenizer)
  end

  def add_document(document)
    raise TypeError, "Document must be a hash." unless document.is_a?(Hash)
    raise ArgumentError, "Document hash must contain a 'content' key." unless document.key?("content")

    content = document["content"] || ""
    raise TypeError, "Document 'content' must be a string." unless content.is_a?(String)

    doc_tokens = @tokenizer.call(content)

    @documents << document
    @corpus_tokens << doc_tokens
    update_stats_add(doc_tokens)
  end

  def add_documents(documents)
    raise TypeError, "Documents must be an array of hashes." unless documents.is_a?(Array)

    return if documents.empty?

    documents.each_with_index do |doc, i|
      raise TypeError, "Document at index #{i} must be a hash." unless doc.is_a?(Hash)
      raise ArgumentError, "Document at index #{i} must contain a 'content' key." unless doc.key?("content")
      raise TypeError, "Document 'content' at index #{i} must be a string." unless doc["content"].is_a?(String)

      content = doc["content"]
      doc_tokens = @tokenizer.call(content)

      @documents << doc
      @corpus_tokens << doc_tokens
      update_stats_add(doc_tokens)
    end

    @index_built = false
  end

  def search(query, k: 1, score_normalization_factor: 0.1)
    return [] if @documents.empty?

    query_text = if query.is_a?(String)
      query
    else
      raise TypeError, "Query must be a string for BM25Index."
    end

    raise ArgumentError, "k must be a positive integer." if k <= 0

    build_index unless @index_built

    return [] if @avg_doc_len == 0

    query_tokens = @tokenizer.call(query_text)
    return [] if query_tokens.empty?

    raw_scores = []
    @documents.length.times do |i|
      raw_score = compute_bm25_score(query_tokens, i)
      raw_scores << [raw_score, @documents[i]] if raw_score > 1e-9
    end

    raw_scores.sort_by! { |score, _| -score }

    normalized_results = []
    raw_scores.first(k).each do |raw_score, doc|
      normalized_score = Math.exp(-score_normalization_factor * raw_score)
      normalized_results << [doc, normalized_score]
    end

    normalized_results.sort_by!(&:last)

    normalized_results
  end

  def length
    @documents.length
  end

  def to_s
    "BM25VectorStore(count=#{length}, k1=#{@k1}, b=#{@b}, index_built=#{@index_built})"
  end

  private

  def default_tokenizer(text)
    text = text.downcase
    tokens = text.split(/\W+/)
    tokens.reject(&:empty?)
  end

  def update_stats_add(doc_tokens)
    @doc_len << doc_tokens.length

    seen_in_doc = Set.new
    doc_tokens.each do |token|
      unless seen_in_doc.include?(token)
        @doc_freqs[token] = (@doc_freqs[token] || 0) + 1
        seen_in_doc << token
      end
    end

    @index_built = false
  end

  def calculate_idf
    n = @documents.length
    @idf = {}
    @doc_freqs.each do |term, freq|
      idf_score = Math.log(((n - freq + 0.5) / (freq + 0.5)) + 1)
      @idf[term] = idf_score
    end
  end

  def build_index
    if @documents.empty?
      @avg_doc_len = 0.0
      @idf = {}
      @index_built = true
      return
    end

    @avg_doc_len = @doc_len.sum.to_f / @documents.length
    calculate_idf
    @index_built = true
  end

  def compute_bm25_score(query_tokens, doc_index)
    score = 0.0
    doc_term_counts = @corpus_tokens[doc_index].tally
    doc_length = @doc_len[doc_index]

    query_tokens.each do |token|
      next unless @idf.key?(token)

      idf = @idf[token]
      term_freq = doc_term_counts[token] || 0

      numerator = idf * term_freq * (@k1 + 1)
      denominator = term_freq + @k1 * (1 - @b + @b * (doc_length / @avg_doc_len))
      score += numerator / (denominator + 1e-9)
    end

    score
  end
end

# Retriever implementation
class Retriever
  def initialize(*indexes, reranker_fn: nil)
    raise ArgumentError, "At least one index must be provided" if indexes.empty?
    @indexes = indexes
    @reranker_fn = reranker_fn
  end

  def add_document(document)
    unless document.key?("id")
      document["id"] = Array.new(4) { [*"a".."z", *"A".."Z", *"0".."9"].sample }.join
    end

    @indexes.each do |index|
      index.add_document(document)
    end
  end

  def add_documents(documents)
    @indexes.each do |index|
      index.add_documents(documents)
    end
  end

  def search(query_text, k: 1, k_rrf: 60)
    raise TypeError, "Query text must be a string." unless query_text.is_a?(String)
    raise ArgumentError, "k must be a positive integer." if k <= 0
    raise ArgumentError, "k_rrf must be non-negative." if k_rrf < 0

    all_results = @indexes.map do |index|
      index.search(query_text, k: k * 5)
    end

    doc_ranks = {}
    all_results.each_with_index do |results, idx|
      results.each_with_index do |(doc, _), rank|
        doc_id = doc.object_id
        unless doc_ranks.key?(doc_id)
          doc_ranks[doc_id] = {
            "doc_obj" => doc,
            "ranks" => Array.new(@indexes.length, Float::INFINITY)
          }
        end
        doc_ranks[doc_id]["ranks"][idx] = rank + 1
      end
    end

    calc_rrf_score = lambda do |ranks, k_rrf|
      ranks.sum { |r| (r == Float::INFINITY) ? 0 : 1.0 / (k_rrf + r) }
    end

    scored_docs = doc_ranks.values.map do |ranks|
      [ranks["doc_obj"], calc_rrf_score.call(ranks["ranks"], k_rrf)]
    end

    filtered_docs = scored_docs.select { |_, score| score > 0 }
    filtered_docs.sort_by! { |_, score| -score }

    result = filtered_docs.first(k)

    if @reranker_fn
      docs_only = result.map(&:first)

      docs_only.each do |doc|
        unless doc.key?("id")
          doc["id"] = Array.new(4) { [*"a".."z", *"A".."Z", *"0".."9"].sample }.join
        end
      end

      doc_lookup = docs_only.to_h { |doc| [doc["id"], doc] }
      reranked_ids = @reranker_fn.call(docs_only, query_text, k)

      new_result = []
      original_scores = result.to_h { |doc, score| [doc.object_id, score] }

      reranked_ids.each do |doc_id|
        if doc_lookup.key?(doc_id)
          doc = doc_lookup[doc_id]
          score = original_scores[doc.object_id] || 0.0
          new_result << [doc, score]
        end
      end

      result = new_result
    end

    result
  end
end

# Chunk source text by section
text = File.read(File.join(__dir__, "..", "report.md"))
chunks = chunk_by_section(text)

# Reranker function
def reranker_fn(docs, query_text, k)
  joined_docs = docs.map do |doc|
    <<~DOC

      <document>
      <document_id>#{doc["id"]}</document_id>
      <document_content>#{doc["content"]}</document_content>
      </document>
    DOC
  end.join

  prompt = <<~PROMPT
    You are about to be given a set of documents, along with an id of each.
    Your task is to select and sort the #{k} most relevant documents to answer the user's question.

    Here is the user's question:
    <question>
    #{query_text}
    </question>

    Here are the documents to select from:
    <documents>
    #{joined_docs}
    </documents>

    Respond in the following format:
    ```json
    {
        "document_ids": str[] # List document ids, #{k} elements long, sorted in order of decreasing relevance to the user's query. The most relevant documents should be listed first.
    }
    ```
  PROMPT

  messages = []
  add_user_message(messages, prompt)
  add_assistant_message(messages, "```json")

  result = chat(messages, stop_sequences: ["```"])

  JSON.parse(text_from_message(result))["document_ids"]
end

with_vcr(:reranking_results) do
  # Create a vector index, a bm25 index, then use them to create a Retriever
  vector_index = VectorIndex.new(embedding_fn: method(:generate_embedding))
  bm25_index = BM25Index.new

  retriever = Retriever.new(bm25_index, vector_index, reranker_fn: method(:reranker_fn))

  # Add all chunks to the retriever, which internally passes them along to both indexes
  # Note: converted to a bulk operation to avoid rate limiting errors from VoyageAI
  retriever.add_documents(chunks.map { |chunk| {"content" => chunk} })

  results = retriever.search("what did the eng team do with INC-2023-Q4-011?", k: 2)

  results.each do |doc, score|
    puts score
    puts doc["content"][0, 200]
    puts "---\n"
  end
end
