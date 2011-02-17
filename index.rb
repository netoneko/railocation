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
set :default_locale, 'ru'
set :sessions, true

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
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
		color = 'red'
		route.each_pair do |key, value|
			if !key.end_with? ' '
				result << "markers['#{h key}'] = new google.maps.Marker({ position: new google.maps.LatLng(#{value}), map: map,
				title:\"#{h key}\", icon: 'http://maps.google.com/intl/en_us/mapfiles/ms/micons/#{color}.png'});"
			end
    end
		result
  end
  
  def _compute(keys, source, destination, source_id, destination_id)
		close_destination = keys.index destination.strip
		far_destination = keys.index("#{destination.strip} ") || close_destination

		puts "#{close_destination} #{far_destination}"

		close_source = keys.index source
		far_source = keys.index("#{source} ") || close_source

		puts "#{close_source} #{far_source}"

		puts(path_close = (close_destination - close_source).abs)
		puts(path_far = (far_destination - far_source).abs)
		
		if path_close <= path_far
			source_id = close_source
			destination_id = close_destination
		else
			source_id = far_source
			destination_id = far_destination
		end
		
		if source_id > destination_id
			old_source_id = source_id
			source_id = destination_id
			destination_id = old_source_id
		end
		
		[source_id, destination_id]
  end  
  
  def compute(keys, source, destination, source_id, destination_id)
		close_destination = keys.index destination.strip
		far_destination = keys.index("#{destination.strip} ") || close_destination

		puts "#{close_destination} #{far_destination}"

		close_source = keys.index source
		far_source = keys.index("#{source} ") || close_source

		puts "#{close_source} #{far_source}"

		puts(path_close = (close_destination - close_source).abs)
		puts(path_far = (far_destination - far_source).abs)
		puts((close_destination - close_source).abs)
		puts(path_far = (far_destination - far_source).abs)
		
		return [close_source, far_destination] if close_source == far_source || close_destination == far_destination
		
		condition = path_close >= path_far
		if condition
			source_id = close_source
			destination_id = close_destination
		else
			source_id = far_source
			destination_id = far_destination
		end
		
		if source_id > destination_id
			old_source_id = source_id
			source_id = destination_id
			destination_id = old_source_id
		end
		
		[source_id, destination_id]
  end
  
  def google_map_js_route_color(route, source_id, destination_id)
  	result = ""  	
  	keys = route.collect {|pair| pair.first}
  	
  	source_id = -9000 if source_id == 0 || source_id.nil?
  	destination_id = -9000 if destination_id == 0 || destination_id.nil?
  	
   	source = keys[source_id -= 1]
		destination = keys[destination_id -= 1]
  	
  	if !source.nil? && !destination.nil?
			indexes = []

			if keys.first.strip == keys.last.strip
				source_id, destination_id = compute(keys, source, destination, source_id, destination_id)
				puts "HURR #{source_id}, #{destination_id}"
				
				if source_id < destination_id 
					indexes = (source_id..destination_id).collect {|i| i}
				else 
					indexes = (0..destination_id).collect {|i| i} + (source_id..(keys.size - 1)).collect {|i| i}
				end
			else
				source_id, destination_id = _compute(keys, source, destination, source_id, destination_id)
			end
			
			indexes.each do |index|
				result << "setMarkerColor(markers[\"#{h keys[index].strip}\"], 'orange')\n"
			end
	  end
  	
#  	puts "#{source} #{destination}"
		result << "setMarkerColor(markers[\"#{h source.strip}\"], 'blue')\n" if !source.nil?
    result << "setMarkerColor(markers[\"#{h destination.strip}\"], 'green')\n" if !destination.nil?
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
  	haml "%a{:href => \"/city/#{city}/#{route_type}/#{route_id}?source=#{h station}\"} #{route_id}"
  end
  
  def link_to_station(city, route_type, name)
  	haml "%a{:href => \"/city/#{city}/#{route_type}/station/#{h name}\"} #{h name}"
  end
  
	def print_time(str)
		split = str.split(':')
		"#{split[0]}#{t.time.hours} #{split[1]}#{t.time.minutes} #{split[2]}#{t.time.seconds}"
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
		city = 'Yekaterinburg'
		type = 'tram'
		
		stations = {}
		get_stations(city, type).each_pair do |name, coords|
			split = coords.split(',')
			station_latitude = split.first.to_f
			station_longitude = split.last.to_f
			
			distance = get_distance_in_meters(station_latitude, station_longitude, latitude, longitude)
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
  
  def get_route_list(city, type)
  	redis.smembers("#{get_postal_code(city)}:#{type}")
  end

	def extract_int_from_params(key)
		begin
			return params[key].to_i if !params[key].nil?
		rescue
		
		end
		return nil
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

get '/city/:city/:route_type/stations' do |city, route_type|
	haml :stations, :locals => {:city => city, :route_type => route_type, :stations => get_stations(city, route_type).keys.sort}
end

get '/city/:city/:route_type/station/:station_id' do |city, route_type, station_id|
	station = get_station(city, route_type, station_id)
	haml :station, :locals => {:station => station}
end

get '/city/:city/:route_type/routes' do |city, route_type|
	haml :routes, :locals => {:city => city, :route_type => route_type, :routes => get_route_list(city, route_type).sort { |a, b| a.to_i <=> b.to_i }}
end

get '/city/:city/:route_type/:route_id' do |city, route_type, route_id|
	route = get_route(city, route_type, route_id)
	
	haml :route, :locals => {:city => city, :route_id => route_id.force_encoding('utf-8'), :route_type => route_type, :route => route, :source_id => extract_int_from_params(:source_id), :destination_id => extract_int_from_params(:destination_id)}
end

get '/user/:username/checkin/:id' do |username, checkin_id|
	check_in = {:route => '23', :route_type => 'tram', :city => 'Yekaterinburg',
		:source => {:name => 'учителей', :index => '12', :time => '2011-02-17 03:34:48 +0500'}, 
		:destination => {:name => 'управление дороги', :index => '16', :time => '2011-02-17 03:42:54 +0500'},
		:distance => {:stations => '2', :meters => '802', :time => '00:8:06'}}
		
	route = get_route(check_in[:city], check_in[:route_type], check_in[:route])
	user = {:name => username}
	haml :checkin, :locals => {:check_in => check_in, :user => user, :route => route}
end