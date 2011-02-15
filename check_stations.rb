# coding: utf-8

require 'redis'

@redis = Redis.new(:port => 6790)
def redis
	@redis
end

def get_stations(city, type)
	redis.hgetall("#{get_postal_code(city)}:#{type}_stations")
end

def get_route_list(city, type)
	redis.smembers("#{get_postal_code(city)}:#{type}")
end

def get_distance_in_meters(lat1, lon1, lat2, lon2)
	dLat = (lat2-lat1) / 180 * Math::PI # Javascript functions in radians
	dLon = (lon2-lon1) / 180 * Math::PI 
	a = Math.sin(dLat/2) * Math.sin(dLat/2) +
			Math.cos(lat1/ 180 * Math::PI) * Math.cos(lat2/ 180 * Math::PI) * 
			Math.sin(dLon/2) * Math.sin(dLon/2); 
	c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
	6371 * c * 1000; # Distance in km
end
  
def get_route(city, type, name)
 	redis.hgetall("#{get_postal_code(city)}:#{type}:#{name.strip()}")
end

def get_postal_code(city)
	620 if city == "Yekaterinburg"
end

city = 'Yekaterinburg'
type = 'tram'

stations = get_stations(city, type)
routes = get_route_list(city, type)

routes.each do |name|
	route = get_route(city, type, name)
	puts name
#	puts route
	keys = route.keys
#	puts keys.last
#	puts '((((('
	(0..route.size).each do |index|
		break if index + 1 == route.size
		
		station1 = keys[index]
		coords1 = route[station1].split(',')
		
		station2 = keys[index + 1]
		coords2 = route[station2].split(',')
		
		distance = get_distance_in_meters(coords1.first.to_f, coords1.last.to_f, coords2.first.to_f, coords2.last.to_f)
		if distance > 1000
			puts "#{station1} - #{station2}, #{distance}"
		end
	end
	puts '*' * 10
end