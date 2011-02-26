# coding: utf-8
require 'json'
require 'net/http'

def locate(query, looking_for_station)
	 query = "#{query.gsub('-', '/')} station" if looking_for_station
	 address = URI.encode("Yekaterinburg, #{query}")
   url = "http://maps.googleapis.com/maps/api/geocode/json?address=#{address}&sensor=false"
   resp = Net::HTTP.get_response(URI.parse(url))
   data = resp.body

   # we convert the returned JSON data to native Ruby
   # data structure - a hash
   result = JSON.parse(data)

   # if the hash has 'Error' as a key, we raise an error
   sleep(0.1)
   if result['status'] != 'OK'
	   puts "web service error #{result['status']}" 
	   return nil
	 end

   result
end

def extract_geocode(location)
	return nil if location.nil?

	results = location['results']
	geolocation = {}
	
	results.each do |result|
		address = result['formatted_address']
		puts address
		zip_code = address[address.length - 6, address.length]
  	geolocation = result['geometry']['location'] if results.size == 1 || zip_code != '620000'
	end

	geolocation_printed = nil
	if geolocation.empty?
		puts 'HOLY FUCK! UNRESOLVED'
		if results.size > 1 
			geolocation = results[0]['geometry']['location']
		else
			return nil
		end
	end
	
	"#{geolocation['lat']},#{geolocation['lng']}"
end

def split_coords(coords)
	coords.split(',').collect {|c| c.to_f }
end