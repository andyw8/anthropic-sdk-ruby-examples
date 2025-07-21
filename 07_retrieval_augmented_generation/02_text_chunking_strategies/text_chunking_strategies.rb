require "bundler/setup"
require "dotenv/load"

# Chunk by a set number of characters
def chunk_by_char(text, chunk_size: 150, chunk_overlap: 20)
  chunks = []
  start_idx = 0

  while start_idx < text.length
    end_idx = [start_idx + chunk_size, text.length].min

    chunk_text = text[start_idx...end_idx]
    chunks << chunk_text

    start_idx = if end_idx < text.length
      end_idx - chunk_overlap
    else
      text.length
    end
  end

  chunks
end

# Chunk by sentence
def chunk_by_sentence(text, max_sentences_per_chunk: 5, overlap_sentences: 1)
  sentences = text.split(/(?<=[.!?])\s+/)

  chunks = []
  start_idx = 0

  while start_idx < sentences.length
    end_idx = [start_idx + max_sentences_per_chunk, sentences.length].min

    current_chunk = sentences[start_idx...end_idx]
    chunks << current_chunk.join(" ")

    start_idx += max_sentences_per_chunk - overlap_sentences

    start_idx = 0 if start_idx < 0
  end

  chunks
end

# Chunk by section
def chunk_by_section(document_text)
  pattern = /\n## /
  document_text.split(pattern)
end

if __FILE__ == $0
  File.open("./report.md", "r") do |f|
    text = f.read

    chunks = chunk_by_char(text)

    chunks.each { |chunk| puts chunk + "\n----\n" }
  end
end
