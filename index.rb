require 'sinatra'
load 'fetch.rb' 

get '/' do
   { :endpoints => [
	   		'/schedule',
	   		'/schedule/cinema/:cinemaId',
	   		'/schedule/movie/:movieId',
	   		'/soon'
	   	]
   	}.to_json
end

get '/schedule' do
	content_type :json
	schedule = parseSchedule # implementation in 'fetch.rb' 
	schedule.to_json
end

get '/schedule/cinema/:cinemaId' do
	content_type :json

	cinemaHash = nil
	schedule = parseSchedule # implementation in 'fetch.rb' 
	schedule.each do |cinema| 
		if cinema[:id].to_s == params['cinemaId'].to_s
			cinemaHash = cinema
		end
	end

	if cinemaHash.nil?
		{ :status => 404, :message => "Didn't find cinema with id: #{params['cinemaId']}" }.to_json
	else
		cinemaHash.to_json
	end
end

get '/schedule/movie/:movieId' do
	content_type :json

	movieHash = {
		:movie => nil,
		:schedule => []
	}
	schedule = parseSchedule # implementation in 'fetch.rb' 
	schedule.each do |cinema| 
		cinema[:movies].each do |movie|
			if movie[:id].to_s == params['movieId'].to_s
				movieHash[:movie] = { :id => movie[:id], :name => movie[:name] } unless movieHash[:movie] != nil

				movieHash[:schedule] << { 
					:cinema => {
						:id => cinema[:id],
						:name => cinema[:name]
					}, 
					:screenings => movie[:screenings]
				}
			end			
		end
	end

	if movieHash[:movie].nil?
		{ :status => 404, :message => "Didn't find the movie you requested" }.to_json
	else
		movieHash.to_json
	end
end

get '/soon' do
	content_type :json
	parseComingSoon.to_json
end

not_found do
	status 404
	content_type :json
	{ :status => 404, :message => "Didn't find the page you requested" }.to_json
end