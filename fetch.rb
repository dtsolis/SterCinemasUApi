require 'net/http'
require 'yajl'
require 'json'

require 'nokogiri'

def parseSchedule
	url = URI.parse('http://www.stercinemas.gr/templates/TLC_Showings.aspx')
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
	startString = "var AllDataArray = new Array(["
	startIndex = html.index(startString)+4
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
	cinemaIds = []

	hash.each_with_index do |cinema, cinemaIndex|
		tmpCinema = { :id => cinema[0][0], :name => cinema[0][1], :movies => [] }

		cinema.drop(1).each do |movie|
			tmpMovie = { 
				:id => movie[0][0], 
				:name => movie[0][1],
				:screenings => [] 
			}
			tmpMovie.merge! imagesHashForMovieId(tmpMovie[:id])

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
		cinemaIds << {
			:id => tmpCinema[:id],
			:index => cinemaIndex
		}
	end

	#
	# Extract cinemas' thumbnails
	# 
	
	page = Nokogiri::HTML(html)
	cinemasTable = page.css('table')[11]
	cinemasTable.css('tr').each do |row|
		row.css('td').each do |column|
			currentId = column.css('a').first['href'].gsub "TLC_Showings.aspx?LMID=", ""

			c = cinemaIds.select { |item| item[:id] == currentId.to_s }.first
			if c != nil
				column.css('img').each do |tmpImg|
					if tmpImg['src'].start_with? "/SterCinemas/SterImagesLive/Cinemas"
						index = c[:index]
						newHash[index][:photo] = "http://www.stercinemas.gr/"<<tmpImg['src']
					end
				end
			end
		end
	end

	#
	# Add cinemas with no schedule but are presented in cinemas.json
	# 
	
	begin
		cFile = File.read("cinemas.json")
		cHash = JSON.parse(cFile)
		cHash.each do |c|
			existedCinema = newHash.select { |item| item[:id] == c["id"] }.first
			if existedCinema.nil?
				newHash << {
					:id => c["id"],
					:name => c["title"],
					:movies => []
				}
			end
		end
	rescue Exception => e
		{ :error => e }.to_json
	end

	newHash
end


def parseComingSoon
	movies = []

	url = URI.parse('http://www.stercinemas.gr/templates/TLC_ComingSoon.aspx')
	req = Net::HTTP::Get.new(url.to_s)
	res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
	html = res.body

	page = Nokogiri::HTML(html)
	if page.css('table').length > 9
		comingSoonTable = page.css('table')[9]
		comingSoonTable.css('tr').drop(1).each do |movie|
			href = movie.css('td')[1].css('a')[0]['href']
			movieId = href.gsub "TLC_MovieDetail.aspx?REFTYPE=2&SHOWMOVID=", ""

			name = movie.css('td')[1].css('a')[0].text
			info = movie.css('td')[1].css('span').text.strip
			director = info.lines[1].gsub "Σκηνοθεσία:", ""
			director.strip!

			actors = info.lines[2].gsub "Παίζουν:", ""
			actors.strip!

			movies << {
				:id => movieId,
				:name => name,
				:director => director,
				:actors => actors,
				:short_description => info.lines[3].strip,
			}.merge(imagesHashForMovieId(movieId))
		end
	end

	movies
end


def parseMovie(movieId)
	url = URI.parse('http://www.stercinemas.gr/templates/TLC_MovieDetail.aspx?REFTYPE=2&SHOWMOVID='<<movieId.to_s)
	req = Net::HTTP::Get.new(url.to_s)
	res = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
	html = res.body

	page = Nokogiri::HTML(html)

	# See if the movie is not found...
	page.css('td').each do |column|
		if column.text.include? "NO MOVIES FOUND"
			return nil
		end
	end

	# Okay, so, no "NO MOVIES FOUND" text, the movie is probably here...
	movie = page.css('table')[11]
	name = movie.css('tr')[0].css('td').text
	name.gsub! "\u00A0", " " # replace &nbsp; with space
	name.strip!
	details = movie.css('tr')[1].css('td')[0].css('p')[1].text.strip
	story = movie.css('tr')[1].css('td')[0].css('p')[2].text

	# Sample 'details'
	# Σκηνοθεσία: Τιμ Μίλερ     Πρωταγωνιστούν: Ράιαν Ρέινολντς, Μορένα Μπακάριν, Εντ Σκριν, Τζίνα Καράνο, Τ.Τζ. Μίλερ, Μπριάνα Χίλντεμπραντ     Κατηγορία: Περιπέτεια Φαντασίας     Διάρκεια: 106'     Επίσημος Τίτλος: DEADPOOL     Βαθμολογία:
	detailValues = details.split(':')

	director = detailValues[1].gsub("Πρωταγωνιστούν", "").strip
	actors = detailValues[2].gsub("Κατηγορία", "").strip
	category = detailValues[3].gsub("Διάρκεια", "").strip
	duration = detailValues[4].gsub("Επίσημος Τίτλος", "").gsub("'", "").strip
	officialTitle = detailValues[5].gsub("Βαθμολογία", "").strip

	# Sample 'story'
	# Υπόθεση: Βασισμένο στον πιο αντισ...
	story = story[8..-1].strip

	# TODO: maybe look for screenings?!...

	movie = {
		:id => movieId,
		:name => name,
		:director => director,
		:actors => actors,
		:category => category,
		:duration => duration,
		:official_title => officialTitle,
		:story => story,
		:screenings => [] 
	}.merge(imagesHashForMovieId(movieId))
end


# helpers
def imagesHashForMovieId(movieId)
	{
		:poster => "http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_0.jpg",
		:images => [
			"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_1.jpg",
			"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_2.jpg",
			"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_3.jpg",
			"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_4.jpg",
			"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_5.jpg",
			"http://www.stercinemas.gr/SterCinemas/SterImagesLive/Movies/#{movieId}/#{movieId}_6.jpg",
		]
	}
end