# coding: utf-8
$: << "."

require 'sinatra'
require 'sinatra/r18n'
require 'haml'
require 'redis'

# Включить раздачу статического контента
set :static, true
set :server, 'thin'
set :bind, 'localhost' # Работать на http://127.0.0.1:4567
set :default_locale, 'en'
set :sessions, true

helpers do
  def mobile?
    @mobile = [/AppleWebKit.*Mobile/,/Android.*AppleWebKit/].any? {|r| request.env['HTTP_USER_AGENT'] =~ r} if @mobile.nil?
    @mobile
  end  
  
  def google_map_static_station(coords)
  	"http://maps.google.com/maps/api/staticmap?size=200x200&zoom=15&maptype=roadmap&markers=size:mid|color:red|#{coords}&sensor=false"
  end
  
  def crop_list(list, i, step)
		first = i - step < 0 ? 0 : i - step
		last = i + step >= list.size ? list.size : i + step
		list[first, last - first]
	end
  
  def google_map_static_route(route, route_type, center)
  	index = route.keys.index(center)
  	values = crop_list(route.values, index, 5)
   	
   	center = route[center]
  	basic_url = "http://maps.google.com/maps/api/staticmap?&size=400x400&zoom=13&directions=driving&center=#{center}"

  	values.each_index do |i|
 	  	basic_url << "&markers="
  		basic_url << "color:green|" if (value = values[i]) == center
  		basic_url << value
  	end
		
  	values.each_index do |i|
 	  	basic_url << "&path="
  		basic_url << [values[i], values[i + 1]].join("|") if i < route.size
  	end
  	
  	basic_url << "&sensor=false"
  end
  
  def google_map_js_route(route)
  	result = ""
		route.each_pair do |key, value|
			result << "markers['#{key}'] = new google.maps.Marker({ position: new google.maps.LatLng(#{value}), map: map,
      title:\"#{key}\", icon: 'http://maps.google.com/intl/en_us/mapfiles/ms/micons/red.png'});"
    end
		result
  end
  
	def google_map_get_center_for_route(route)
		top, left, bottom, right = nil
		
		route.values.each do |value|
			split = value.split(',')
			latitude = split[0].to_f
			longtitude = split[1].to_f
			
			left = latitude if left.nil? || latitude < left
			right = latitude if right.nil? || latitude > right
			
			top = longtitude if top.nil? || longtitude > top
			bottom = longtitude if bottom.nil? || longtitude < bottom
		end
		
		"#{(right + left)/2},#{(top + bottom)/2}"
	end
  
  def link_to_route(city, route_type, route_id, station)
  	haml "%a{:href => \"/city/#{city}/#{route_type}/#{route_id}?from=#{station}\"} #{route_id}"
  end
  
  @@redis = Redis.new(:port => 6790)
  def redis
  	@@redis
  end
  
  def get_postal_code(city)
  	620 if city == "Yekaterinburg"
  end
  
  def get_stations(city, type)
  	redis.hgetall("#{get_postal_code(city)}:#{type}_stations")
  end
  
  def get_local_stations(latitude, longitude)
		puts "#{latitude}, #{longitude}"
		city = 'Yekaterinburg'
		type = 'tram'
		
		stations = {}
		get_stations(city, type).each_pair do |name, coords|
			split = coords.split(',')
			station_latitude = split.first.to_f
			station_longitude = split.last.to_f
			
			distance = ((station_latitude - latitude) ** 2 + (station_longitude - longitude) ** 2) ** 1/2
			stations[name] = distance.to_f
		end
		
		stations = stations.sort {|a, b| a[1] <=> b[1]}
		puts stations
		stations.collect do |station|
			result = get_station(city, type, station.first)
			result[:distance] = station.last
			result
		end
  end
  
  def get_station(city, type, name)
  	name = name.force_encoding('utf-8').strip() if !name.frozen?
  	city = city.force_encoding('utf-8') if !city.frozen?
  	station = {}
  	station[:name] = name
  	station[:routes] = get_routes_from_station(city, type, name)
  	station[:city] = city
  	station[:coords] = redis.hget("#{get_postal_code(city)}:#{type}_stations", name)
  	station[:type] = type
  	
  	station
  end
  
  def get_routes_from_station(city, type, station)
  	redis.smembers("#{get_postal_code(city)}:#{type}_stations:#{station}:routes")
  end
  
  def get_route(city, type, name)
  	redis.hgetall("#{get_postal_code(city)}:#{type}:#{name.strip()}")
  end
end

before do
 	session[:locale] = params[:locale] if params[:locale]
end

get '/' do 
	t.index.description
end

get '/location' do
	locals = {}
	if !params[:latitude].nil? || !params[:longitude].nil?
		locals[:stations] = get_local_stations(params[:latitude].to_f, params[:longitude].to_f)
	end

	haml :location, :locals => locals
end

get '/city/:city/station/:station_id' do |city, station_id|
	station = get_station(city, 'tram', station_id)
	haml :station, :locals => {:station => station}
end

get '/city/:city/:route_type/:route_id' do |city, route_type, route_id|
	route = get_route(city, route_type, route_id)
	haml :route, :locals => {:city => city, :route_id => route_id, :route_type => route_type, :route => route}
end