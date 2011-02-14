#coding: utf-8
require 'text'
require 'redis'
require 'unicode_utils'

def normalize(key)
  key = UnicodeUtils.downcase(key).gsub(',', '').gsub('.', '').strip()
  key = key.sub('площадь', 'пл').sub('пл', 'площадь ') if key.start_with?('пл')
  key = key.sub('пер ', 'переулок ')
  key = key.sub('ул', '') if key.start_with?('ул')
  key = key.sub('  ', ' ').sub(' - ', '').sub(' (конечная)', '').sub(' (электростанция)', '').sub(' (новомосковская)', '')
  key = key.sub('театр музыкальной комедии', 'архитектурный институт').sub('протезно-ортопедическое предприятие', 'ортопедическое предприятие').sub('цпк и о', 'цпкио').sub('техническое ', 'тех').sub('янавря', 'января')
  key.strip()
end

def normalize_stations(keys)
  matches = {}
  keys.each_index do |i|
    k_i = keys[i]
    k_i_1 = keys[i + 1]
    if i + 1 < keys.size && Text::Levenshtein.distance(k_i, k_i_1) == 1
      matches[k_i.size < k_i_1.size ? k_i: k_i_1] = k_i.size < k_i_1.size ? k_i_1: k_i
    end
  end
  
  matches
end

def clean_db
  r = Redis.new(:port => 6790)
  ekb_coords = '56.837814,60.596842'
  
  all = r.hgetall('620:tram_stations')
  
  no_coords = []
  has_coords = []
  puts all.each_pair {|name, coords| (coords == ekb_coords ? no_coords : has_coords) << normalize(name)}
  
  together = no_coords & has_coords
  puts no_coords.size - together.size
  puts together
  puts has_coords.size
  
  keys = r.hkeys('620:tram_stations')
  
  keys = keys.collect {|key| normalize(key)}
  keys.sort!
  keys.uniq!
  puts keys.size
  
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
  
  puts [keys - has_coords]
  
  puts keys
end