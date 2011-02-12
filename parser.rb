#coding: utf-8
require 'iconv'

results = {}
routes = ((1..27).collect{|i| i} + (31..33).collect{|i| i})

routes.each do |i|
  text = ""
  
  File.open("tmp/tram_route_#{i}.html", "r") do |infile|
    counter = 0
    while (line = infile.gets)
      line = Iconv.iconv('utf-8', 'cp1251', line)[0]
      counter +=1
      break if !line.index("<li>Обратный маршрут").nil?
      if !line.index("Остановки:").nil?
        text << line 
      end
    end
  end
  
  path = []
  text.split('<br>').each do |line|
    line = line.strip()
    if not (index = line.index(')')).nil?
      path << line[index + 2, line.size].gsub(',', '').gsub('ул.', '').gsub('.', '').strip()
    end
  end

  results[i] = path if !path.empty?
end

results.each_pair do |key, value|
  puts "#{key}/#{value.size}"
end

puts '*' * 10
puts routes - results.keys
