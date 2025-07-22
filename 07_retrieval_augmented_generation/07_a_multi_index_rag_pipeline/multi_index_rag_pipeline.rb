require "dotenv/load"
require "voyageai"

# Client Setup
VOYAGEAI_CLIENT = VoyageAI::Client.new

# Chunk by section
def chunk_by_section(document_text)
  document_text.split(/\n## /)
end

# Embedding Generation
def generate_embedding(chunks, model: "voyage-3-large", input_type: "query")
  is_list = chunks.is_a?(Array)
  input = is_list ? chunks : [chunks]
  result = VOYAGEAI_CLIENT.embed(input: input, model: model, input_type: input_type)
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
    unless @embedding_fn
      raise RuntimeError, "Embedding function not provided during initialization."
    end
    unless document.is_a?(Hash)
      raise TypeError, "Document must be a hash."
    end
    unless document.key?("content")
      raise ArgumentError, "Document hash must contain a 'content' key."
    end

    content = document["content"]
    unless content.is_a?(String)
      raise TypeError, "Document 'content' must be a string."
    end

    vector = @embedding_fn.call(content)
    add_vector(vector: vector, document: document)
  end

  def add_documents(documents)
    unless @embedding_fn
      raise RuntimeError, "Embedding function not provided during initialization."
    end

    unless documents.is_a?(Array)
      raise TypeError, "Documents must be an array of hashes."
    end

    return if documents.empty?

    contents = []
    documents.each_with_index do |doc, i|
      unless doc.is_a?(Hash)
        raise TypeError, "Document at index #{i} must be a hash."
      end
      unless doc.key?("content")
        raise ArgumentError, "Document at index #{i} must contain a 'content' key."
      end
      unless doc["content"].is_a?(String)
        raise TypeError, "Document 'content' at index #{i} must be a string."
      end
      contents << doc["content"]
    end

    vectors = @embedding_fn.call(contents)

    vectors.zip(documents).each do |vector, document|
      add_vector(vector: vector, document: document)
    end
  end

  def search(query, k: 1)
    return [] if @vectors.empty?

    if query.is_a?(String)
      unless @embedding_fn
        raise RuntimeError, "Embedding function not provided for string query."
      end
      query_vector = @embedding_fn.call(query)
    elsif query.is_a?(Array) && query.all? { |x| x.is_a?(Numeric) }
      query_vector = query
    else
      raise TypeError, "Query must be either a string or an array of numbers."
    end

    return [] if @vector_dim.nil?

    if query_vector.length != @vector_dim
      raise ArgumentError, "Query vector dimension mismatch. Expected #{@vector_dim}, got #{query_vector.length}"
    end

    if k <= 0
      raise ArgumentError, "k must be a positive integer."
    end

    dist_func = @distance_metric == "cosine" ? method(:cosine_distance) : method(:euclidean_distance)

    distances = []
    @vectors.each_with_index do |stored_vector, i|
      distance = dist_func.call(query_vector, stored_vector)
      distances << [distance, @documents[i]]
    end

    distances.sort_by! { |item| item[0] }

    distances[0...k].map { |dist, doc| [doc, dist] }
  end

  def add_vector(vector:, document:)
    unless vector.is_a?(Array) && vector.all? { |x| x.is_a?(Numeric) }
      raise TypeError, "Vector must be an array of numbers."
    end
    unless document.is_a?(Hash)
      raise TypeError, "Document must be a hash."
    end
    unless document.key?("content")
      raise ArgumentError, "Document hash must contain a 'content' key."
    end

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
    if vec1.length != vec2.length
      raise ArgumentError, "Vectors must have the same dimension"
    end
    Math.sqrt(vec1.zip(vec2).map { |p, q| (p - q) ** 2 }.sum)
  end

  def dot_product(vec1, vec2)
    if vec1.length != vec2.length
      raise ArgumentError, "Vectors must have the same dimension"
    end
    vec1.zip(vec2).map { |p, q| p * q }.sum
  end

  def magnitude(vec)
    Math.sqrt(vec.map { |x| x * x }.sum)
  end

  def cosine_distance(vec1, vec2)
    if vec1.length != vec2.length
      raise ArgumentError, "Vectors must have the same dimension"
    end

    mag1 = magnitude(vec1)
    mag2 = magnitude(vec2)

    if mag1 == 0 && mag2 == 0
      return 0.0
    elsif mag1 == 0 || mag2 == 0
      return 1.0
    end

    dot_prod = dot_product(vec1, vec2)
    cosine_similarity = dot_prod / (mag1 * mag2)
    cosine_similarity = [[-1.0, cosine_similarity].max, 1.0].min

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
    unless document.is_a?(Hash)
      raise TypeError, "Document must be a hash."
    end
    unless document.key?("content")
      raise ArgumentError, "Document hash must contain a 'content' key."
    end

    content = document["content"] || ""
    unless content.is_a?(String)
      raise TypeError, "Document 'content' must be a string."
    end

    doc_tokens = @tokenizer.call(content)

    @documents << document
    @corpus_tokens << doc_tokens
    update_stats_add(doc_tokens)
  end

  def add_documents(documents)
    unless documents.is_a?(Array)
      raise TypeError, "Documents must be an array of hashes."
    end

    return if documents.empty?

    documents.each_with_index do |doc, i|
      unless doc.is_a?(Hash)
        raise TypeError, "Document at index #{i} must be a hash."
      end
      unless doc.key?("content")
        raise ArgumentError, "Document at index #{i} must contain a 'content' key."
      end
      unless doc["content"].is_a?(String)
        raise TypeError, "Document 'content' at index #{i} must be a string."
      end

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

    if query.is_a?(String)
      query_text = query
    else
      raise TypeError, "Query must be a string for BM25Index."
    end

    if k <= 0
      raise ArgumentError, "k must be a positive integer."
    end

    build_index unless @index_built

    return [] if @avg_doc_len == 0

    query_tokens = @tokenizer.call(query_text)
    return [] if query_tokens.empty?

    raw_scores = []
    @documents.each_with_index do |doc, i|
      raw_score = compute_bm25_score(query_tokens, i)
      if raw_score > 1e-9
        raw_scores << [raw_score, doc]
      end
    end

    raw_scores.sort_by! { |item| -item[0] }

    normalized_results = []
    raw_scores[0...k].each do |raw_score, doc|
      normalized_score = Math.exp(-score_normalization_factor * raw_score)
      normalized_results << [doc, normalized_score]
    end

    normalized_results.sort_by! { |item| item[1] }

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
        seen_in_doc.add(token)
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
  def initialize(*indexes)
    if indexes.empty?
      raise ArgumentError, "At least one index must be provided"
    end
    @indexes = indexes
  end

  def add_document(document)
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
    unless query_text.is_a?(String)
      raise TypeError, "Query text must be a string."
    end
    if k <= 0
      raise ArgumentError, "k must be a positive integer."
    end
    if k_rrf < 0
      raise ArgumentError, "k_rrf must be non-negative."
    end

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

    calc_rrf_score = lambda do |ranks|
      ranks.map { |r| r == Float::INFINITY ? 0 : 1.0 / (k_rrf + r) }.sum
    end

    scored_docs = doc_ranks.values.map do |ranks|
      [ranks["doc_obj"], calc_rrf_score.call(ranks["ranks"])]
    end

    filtered_docs = scored_docs.select { |doc, score| score > 0 }
    filtered_docs.sort_by! { |x| -x[1] }

    filtered_docs[0...k]
  end
end

# Chunk source text by section
text = File.read("./report.md")
chunks = chunk_by_section(text)

# Create a vector index, a bm25 index, then use them to create a Retriever
vector_index = VectorIndex.new(embedding_fn: method(:generate_embedding))
bm25_index = BM25Index.new

retriever = Retriever.new(bm25_index, vector_index)

# Add all chunks to the retriever, which internally passes them along to both indexes
# Note: converted to a bulk operation to avoid rate limiting errors from VoyageAI
retriever.add_documents(chunks.map { |chunk| {"content" => chunk} })