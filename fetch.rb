require 'net/http'
require 'yajl'
require 'json'

def parseSchedule
	url = URI.parse('http://www.stercinemas.gr/templates/home.aspx')
	req = Net::HTTP::Get.new(url.to_s)
	res = Net::HTTP.start(url.host, url.port) {|http|
	  http.request(req)
	}

	html = res.body

	# ------
	# 1. Extract javascript array from the html
	# 2. Convert to json string (strip all 'new Array()' from javascript)
	# 3. Convert from json string to ruby Hash
	# 4. Create new Ruby Hash with propert symbols
	# ------

	# 1.
	startString = "var AllDataArray = new Array([4]);"
	startIndex = html.index(startString)
	endIndex = html.index("function getMovies() {")

	javascriptArray = html[startIndex+startString.length..endIndex-1].strip

	# 2.
	possibleCinemasCount = 6

	0.upto(possibleCinemasCount) { |i| javascriptArray.gsub! "AllDataArray[#{i}] = new Array(", "[" }
	javascriptArray.gsub! ";", ","
	javascriptArray.gsub! "new Array(", "["
	javascriptArray.gsub! ")", "]"
	javascriptArray.gsub! "'", "\""

	javascriptArray = "["<<javascriptArray[0..-2]<<"]"

	# 3. 
	parser = Yajl::Parser.new
	hash = parser.parse(javascriptArray)

	# 4. 
	newHash = []

	hash.each do |cinema|
		tmpCinema = { :id => cinema[0][0], :name => cinema[0][1], :movies => [] }

		cinema.drop(1).each do |movie|
			tmpMovie = { 
				:id => movie[0][0], 
				:name => movie[0][1], 
				:poster => "http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_0.jpg",
				:images => [
					"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_1.jpg",
					"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_2.jpg",
					"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_3.jpg",
					"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_4.jpg",
					"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_5.jpg",
					"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movie[0][0]}/#{movie[0][0]}_6.jpg",
				],
				:screenings => [] 
			}

			movie[1].drop(1).each do |date|
				tmpDate = {:date => date[0][0], :times => []}

				date[1].each do |time|
					tmpDate[:times] << time[1]
				end
				tmpMovie[:screenings] << tmpDate
			end
			tmpCinema[:movies] << tmpMovie
		end

		newHash << tmpCinema
	end
	newHash
end
