require 'sinatra'

# coding: utf-8
$: << "."

require 'sinatra'
require 'sinatra/r18n'
require 'haml'

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
  
  def google_map_static(coords)
  	"http://maps.google.com/maps/api/staticmap?size=200x200&zoom=15&maptype=roadmap&markers=size:mid|color:red|#{coords}&sensor=false"
  end
end

@@Pionerskaya_bus = {:name => 'Пионерская', :location => 'Yekaterinburg, Province of Sverdlovsk, Russia', :routes => ['05а', '034', '046', '048', '052', '056', '082', 'тб 12', 'тб 18'], :coords => '56.859654,60.619517', :type => 'bus', :long_id => 1}

@@Pionerskaya_tram = {:name => 'Пионерская', :location => 'Yekaterinburg, Province of Sverdlovsk, Russia', :routes => ['2', '5', '7', '8', '14', '16', '20', '22', '23', '25', '26', '32', 'А'], :coords => '56.85915,60.621282', :type => 'tram', :long_id => 2}

before do
 	session[:locale] = params[:locale] if params[:locale]
end

get '/' do 
	t.index.description
end

get '/location' do
	haml :location, :locals => {:stations => search_nearby_stations}
end

get '/station/:station_id' do |station_id|
	haml :station, :locals => {:station => {1 => @@Pionerskaya_bus, 2 => @@Pionerskaya_tram}[station_id.to_i]}
end