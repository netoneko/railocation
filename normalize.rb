#coding: utf-8
require 'text'
require 'redis'
require 'unicode_utils'

def normalize(key)
  key = UnicodeUtils.downcase(key)
  key = key.sub('площадь', 'пл').sub('пл', 'площадь ') if key.start_with?('пл')
  key = key.sub('пер ', 'переулок ')
  key = key.sub('ул', '') if key.start_with?('ул')
  key = key.sub('  ', ' ').sub(' - ', '')
end

r = Redis.new(:port => 6790)
ekb_coords = '56.837814,60.596842'

all = r.hgetall('620:tram_stations')

no_coords = []
has_coords = []
puts all.each_pair {|name, coords| (coords == ekb_coords ? no_coords : has_coords) << normalize(name)}

puts no_coords & has_coords

exit(0)

keys = r.hkeys('620:tram_stations')

if true
  keys = keys.collect {|key| normalize(key)}
  keys.sort!
  keys.uniq!
  puts keys.size
end

puts '*' * 10

puts Text::Levenshtein.distance("технический университет (угту-упи)", "технический университет (уту-упи)")
puts Text::Levenshtein.distance("9 января", "9 янавря" )

result = []
matches = {}
keys.each_index do |i|
  k_i = keys[i]
  k_i_1 = keys[i + 1]
  if i + 1 < keys.size && Text::Levenshtein.distance(k_i, k_i_1) == 1
    matches[k_i.size < k_i_1.size ? k_i: k_i_1] = k_i.size < k_i_1.size ? k_i_1: k_i
  end
end

puts result
puts '*' * 10
puts matches

matches.keys.each {|key| keys.delete key}

keys.sort!
puts keys.size