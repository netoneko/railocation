# coding: utf-8
require 'json'
require 'net/http'

def locate(station)
	 address = URI.encode("Yekaterinburg, #{station} station")
   url = "http://maps.googleapis.com/maps/api/geocode/json?address=#{address}&sensor=false"
   resp = Net::HTTP.get_response(URI.parse(url))
   data = resp.body

   # we convert the returned JSON data to native Ruby
   # data structure - a hash
   result = JSON.parse(data)

   # if the hash has 'Error' as a key, we raise an error
   raise "web service error" if result['status'] != 'OK'
      
   result
end

locations = ['Каменные палатки', 'Профессорская', 'Гагарина', 
'Первомайская', 
'Блюхера', 
'Советская', 
'Пионеров', 
'Кондукторская', 
'Пионерская', 
'Железнодорожный вокзал', 
'Управление дороги', 
'9 Января', 
'Папанина', 
'Шейнкмана', 
'Дворец Молодёжи', 
'ВИЗ-бульвар', 
'Крылова', 
'Кирова', 
'Колмогорова', 
'Верх-исетский рынок', 
'ЦХП', 
'Ротор', 
'Уральских коммунаров', 
'Бебеля', 
'Пехотинцев', 
'Автомагистральная', 
'Сварщиков', 
'Лукиных',
'Диагностический центр', 
'40 лет Октября', 
'Машиностроителей']

final = ""

locations.each do |location|
	results = locate(location)['results']
	
	geolocation = {}
	
	results.each do |result|
		address = result['formatted_address']
		puts address
		zip_code = address[address.length - 6, address.length]
  	geolocation = result['geometry']['location'] if results.size == 1 || zip_code != '620000'
	end

	puts location
	geolocation_printed = nil
	if geolocation.empty?
		puts 'HOLY FUCK! UNRESOLVED' 
	else
		puts geolocation_printed = "#{geolocation['lat']},#{geolocation['lng']}"
	end
	final << "'#{location}' => '#{geolocation_printed}', "
	
	puts '*' * 40
end

puts final