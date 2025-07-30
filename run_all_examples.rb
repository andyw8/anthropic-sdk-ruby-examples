#!/usr/bin/env ruby

require "pathname"

def find_examples
  examples = []

  # Find all numbered directories (00-99)
  Dir.glob("[0-9][0-9]_*/").sort.each do |section_dir|
    # Find all numbered subdirectories within each section
    Dir.glob("#{section_dir}[0-9][0-9]_*/").sort.each do |chapter_dir|
      # Find Ruby files in the chapter directorys
      ruby_files = Dir.glob("#{chapter_dir}*.rb")

      # If we found Ruby files, add them
      ruby_files.each do |ruby_file|
        examples << ruby_file
      end
    end
  end

  examples.sort
end

def run_example(file_path)
  puts "\n" + "=" * 80
  puts "Running: #{file_path}"
  puts "=" * 80

  if File.exist?(file_path)
    system("bundle exec ruby #{file_path}")
    success = $?.success?

    if success
      puts "✅ #{file_path} completed successfully"
    else
      puts "❌ #{file_path} failed with exit code #{$?.exitstatus}"
    end

    success
  else
    puts "⚠️  File not found: #{file_path}"
    false
  end
end

def main
  examples = find_examples

  puts "Found #{examples.length} examples to run:"
  examples.each_with_index do |example, index|
    puts "  #{index + 1}. #{example}"
  end
  puts

  successes = 0
  failures = 0

  examples.each_with_index do |example, index|
    puts "\n[#{index + 1}/#{examples.length}]"

    if run_example(example)
      successes += 1
    else
      failures += 1
    end

    # Add a small delay between examples
    sleep 1
  end

  puts "\n" + "=" * 80
  puts "📊 SUMMARY"
  puts "=" * 80
  puts "✅ Successful: #{successes}"
  puts "❌ Failed: #{failures}"
  puts "📝 Total: #{examples.length}"

  if failures > 0
    puts "\n⚠️  Some examples failed. Check the output above for details."
    exit 1
  else
    puts "\n🎉 All examples completed successfully!"
  end
end

if __FILE__ == $0
  main
end
