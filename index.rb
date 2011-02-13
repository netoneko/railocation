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
  
  def search_nearby_stations
  	[@@Pionerskaya_bus, @@Pionerskaya_tram]
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
  	
  	puts basic_url
  	
  	basic_url
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
  
  def link_to_check_in
  	
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
  
  def get_station(city, type, name)
  	name = name.force_encoding('utf-8').strip()
  	city = city.force_encoding('utf-8')
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

@@Pionerskaya_bus = {:name => 'Пионерская', :city => 'Yekaterinburg', :routes => ['05а', '034', '046', '048', '052', '056', '082', 'тб 12', 'тб 18'], :coords => '56.859654,60.619517', :type => 'bus'}

@@Pionerskaya_tram = {:name => 'Пионерская', :city => 'Yekaterinburg', :routes => ['2', '5', '7', '8', '14', '16', '20', '22', '23', '25', '26', '32', 'А'], :coords => '56.85915,60.621282', :type => 'tram'}

@@route_23 = {'Каменные палатки' => '56.8414849,60.6789118', 'Профессорская' => '56.8403083,60.6530178', 'Гагарина' => '56.8401616,60.646956', 'Первомайская' => '56.841793,60.6328194', 'Блюхера' => '56.8514331,60.6410712', 'Советская' => '56.8541522,60.6367475', 'Учителей' => '56.857716,60.630965', 
'Кондукторская' => '56.8598156,60.6276441', 'Пионерская' => '56.8596543,60.619517', 'Железнодорожный вокзал' => '56.8562259,60.6055588', 'Управление дороги' => '56.8512102,60.5944759', '9 Января' => '56.8453929,60.5868369', 'Папанина' => '56.8427201,60.5832267', 'Шейнкмана' => '56.8405577,60.5806839', 'Дворец Молодёжи' => '56.8371363,60.5819768', 'ВИЗ-бульвар' => '56.8377701,60.576902', 'Крылова' => '56.8394603,60.5708563', 'Кирова' => '56.840232,60.560208', 'Колмогорова' => '56.8460559,60.5589098', 'Верх-исетский рынок' => '56.8504035,60.5552995', 'ЦХП' => '56.8529496,60.5530143', 'Ротор' => '56.8554457,60.5507666', 'Уральских коммунаров' => '56.8610884,60.549109', 'Бебеля' => '56.8653286,60.5501175' , 'Пехотинцев' => '56.8710343,60.5496508', 'Автомагистральная' => '56.8754699,60.554055', 'Сварщиков' => '56.8793451,60.5580193', 'Лукиных' => '56.8834865,60.5625415', 'Диагностический центр' => '56.8841401,60.5708134', '40 лет Октября' => '56.8846852,60.5773419', 'Машиностроителей' => '56.8771258,60.6130519'}

before do
 	session[:locale] = params[:locale] if params[:locale]
end

get '/' do 
	t.index.description
end

get '/location' do
	haml :location, :locals => {:stations => search_nearby_stations}
end

get '/city/:city/station/:station_id' do |city, station_id|
	station = get_station(city, 'tram', station_id)
	haml :station, :locals => {:station => station}
end

get '/city/:city/:route_type/:route_id' do |city, route_type, route_id|
#	haml :route, :locals => {:city => city, :route_id => route_id, :route_type => route_type, :route => @@route_23}
	route = get_route(city, route_type, route_id)
	
	puts route
	puts @@route_23
	
	haml :route, :locals => {:city => city, :route_id => route_id, :route_type => route_type, :route => route}
end

get '/map' do
	haml :map, :locals => {:city => 'Yekaterinburg', :route => @@route_23}
end