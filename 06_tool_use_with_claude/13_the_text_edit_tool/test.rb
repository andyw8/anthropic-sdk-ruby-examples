#!/usr/bin/env ruby

require_relative 'main'

# Test the calculate_pi method
puts "Testing calculate_pi method..."

calculated_pi = calculate_pi
expected_pi = 3.14159

puts "Calculated pi: #{calculated_pi}"
puts "Expected pi:   #{expected_pi}"

if calculated_pi == expected_pi
  puts "✅ Test passed! Pi was calculated correctly to 5 decimal places."
else
  puts "❌ Test failed! Pi calculation is not accurate to 5 decimal places."
  puts "Difference: #{(calculated_pi - expected_pi).abs}"
end