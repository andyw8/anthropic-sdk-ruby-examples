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
      ranks.map { |r| (r == Float::INFINITY) ? 0 : 1.0 / (k_rrf + r) }.sum
    end

    scored_docs = doc_ranks.values.map do |ranks|
      [ranks["doc_obj"], calc_rrf_score.call(ranks["ranks"])]
    end

    filtered_docs = scored_docs.select { |doc, score| score > 0 }
    filtered_docs.sort_by! { |x| -x[1] }

    filtered_docs[0...k]
  end
end