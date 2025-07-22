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
      raise "Embedding function not provided during initialization."
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
      raise "Embedding function not provided during initialization."
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
        raise "Embedding function not provided for string query."
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

    dist_func = (@distance_metric == "cosine") ? method(:cosine_distance) : method(:euclidean_distance)

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
    Math.sqrt(vec1.zip(vec2).map { |p, q| (p - q)**2 }.sum)
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
    cosine_similarity = cosine_similarity.clamp(-1.0, 1.0)

    1.0 - cosine_similarity
  end
end