#coding: utf-8
$: << "."
require 'iconv'
require 'redis'
require 'locator.rb'

results = {}
routes = ((1..27).collect{|i| i} + (31..33).collect{|i| i})
#routes = [27]

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
#    puts line
    if not (index = line.index(')')).nil?
      path << line[index + 1, line.size].gsub(',', '').gsub('.', '').gsub('ул ', '').gsub('пл ', 'площадь').gsub("\"", "\\\"").strip()
    end
  end

  results[i] = path if !path.empty?
end

r = Redis.new(:port => 6790)

ekb_trams_key = "620:tram" # postal code, tram/bus
r.del ekb_trams_key

ekb_tram_stations_key = "620:tram_stations"
r.del ekb_tram_stations_key

unable_to_locate = []
results.each_pair do |key, value|
  r.sadd(ekb_trams_key, key)

  ekb_tram_custom_key = "#{ekb_trams_key}:#{key}"
  r.del ekb_tram_custom_key
  value.each_index do |i|
    station = value[i]
    ekb_tram_custom_key_routes = "#{ekb_tram_stations_key}:#{station}:routes"
    r.sadd(ekb_tram_custom_key_routes, station)

    if true #building routes
      puts station
      local = nil
      coords = r.hget(ekb_tram_stations_key, station) || extract_geocode(locate(station))
      if coords.nil? 
        unable_to_locate << station
        coords = ""
      end
      
      station += " " if !r.hget(ekb_tram_stations_key, station).nil?
      r.hset(ekb_tram_stations_key, station, coords)
      r.hset(ekb_tram_custom_key, station, coords)
    end
  end

  puts "#{key}/#{value.size}"
end

puts '*' * 10
puts "Could not parse: #{routes - results.keys}"
puts '*' * 10
puts r.smembers(ekb_trams_key)
puts '*' * 10
results.each_pair do |key, value|
  ekb_tram_custom_key = "#{ekb_trams_key}:#{key}"
  puts ekb_tram_custom_key
  puts r.hgetall(ekb_tram_custom_key)
end
puts '*' * 10
puts ekb_tram_stations_key
puts r.hkeys(ekb_tram_stations_key).size
puts r.hgetall(ekb_tram_stations_key)
puts unable_to_locate