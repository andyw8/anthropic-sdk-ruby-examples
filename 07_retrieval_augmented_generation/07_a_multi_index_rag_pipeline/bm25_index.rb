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
