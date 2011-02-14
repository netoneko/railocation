#coding: utf-8
$: << "."
require 'iconv'
require 'redis'
require 'locator.rb'
require 'normalize.rb'

def parse_input_files(routes, stations, results)
  routes.each do |i|
    text = ""
    
    File.open("tmp/tram_route_#{i}.html", "r") do |infile|
      while (line = infile.gets)
        line = Iconv.iconv('utf-8', 'cp1251', line)[0]
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
        station = normalize(line[index + 1, line.size])
        stations << station
        path << station
      end
    end
  
    results[i] = path if !path.empty?
  end
end

def r
  @r = Redis.new(:port => 6790) if @r.nil?
  @r
end

def cleanup_stations(stations)
  stations.sort!
  stations.uniq!
  
  replace = normalize_stations(stations)
  replace.keys.each do |station|
    stations.delete station
  end
  
  replace
end

def save_stations(stations, do_locate)    
  ekb_tram_stations_key = "620:tram_stations"
  r.del ekb_tram_stations_key
  
  ekb_coords = '56.837814,60.596842'
 
  unable_to_locate = []
  stations.each do |station|
    coords = do_locate ? extract_geocode(locate(station)) : ""
    if coords.nil? || coords == ekb_coords
      unable_to_locate << station
    else
      r.hset(ekb_tram_stations_key, station, coords)
    end  
  end
  
  stations.replace(r.hkeys(ekb_tram_stations_key))
  unable_to_locate
end

def save_trams(ekb_trams_key, keys)
  r.del ekb_trams_key
  keys.each do |key|
    r.sadd(ekb_trams_key, key)
  end
end

def build_routes(stations, results, replace, unable_to_locate)
  ekb_trams_key = "620:tram" # postal code, tram/bus
  ekb_tram_stations_key = "620:tram_stations"
  
  save_trams(ekb_trams_key, results.keys)
  
  results.each_pair do |key, value|
    ekb_tram_custom_key = "#{ekb_trams_key}:#{key}"
    r.del ekb_tram_custom_key
    
    value.each do |station|
      ekb_tram_custom_key_routes = "#{ekb_tram_stations_key}:#{station}:routes"
      r.del ekb_tram_custom_key_routes
    end
    
    value.each do |station|
      station = (replace.has_key? station) ? replace[station] : station
      if stations.include? station      
        ekb_tram_custom_key_routes = "#{ekb_tram_stations_key}:#{station}:routes"
        r.sadd(ekb_tram_custom_key_routes, key)
    
        coords = r.hget(ekb_tram_stations_key, station)
        r.hset(ekb_tram_stations_key, station, coords)
        station += " " if !r.hget(ekb_tram_custom_key, station).nil?
        r.hset(ekb_tram_custom_key, station, coords)
      end
    end
  end

  puts '*' * 10 + " list of trams"
  puts r.smembers(ekb_trams_key).sort
  
  puts '*' * 10
  results.each_pair do |key, value|
    ekb_tram_custom_key = "#{ekb_trams_key}:#{key}"
    puts ekb_tram_custom_key
    puts r.hgetall(ekb_tram_custom_key)
  end

  exit 0
  puts '*' * 10
  puts ekb_tram_stations_key
  puts r.hkeys(ekb_tram_stations_key).size
#  puts r.hgetall(ekb_tram_stations_key)
  puts unable_to_locate
end

def parse_all 
  routes = ((1..27).collect{|i| i} + (31..33).collect{|i| i})
#  routes = [27]
  stations = []
  results = {}
  
  parse_input_files(routes, stations, results)
  
  replace = cleanup_stations(stations)
  unable_to_locate = save_stations(stations, true)
  
  build_routes(stations, results, replace, unable_to_locate)   
  
end

parse_all