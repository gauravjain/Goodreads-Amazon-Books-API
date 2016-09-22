require 'open-uri'
require 'nokogiri'
require 'cgi'
require 'hmac-sha2'
require 'base64'
require 'openssl'
require 'uri'

ACCESS_IDENTIFIER = 'ACCESS_KEY'
SECRET_IDENTIFIER = 'SECRET_IDENTIFIER'

@isbn = []
@title = []

def goodreads_books(author_id)
	response = open("https://www.goodreads.com/author/list/#{author_id}?format=xml&page=1&per_page=1000&key=ACCESS_KEY").read
	doc = Nokogiri::XML.parse(response)
	doc.xpath('//book').each do |author|
		if(author.at_xpath('isbn').text!='')
			@isbn << author.at_xpath('isbn').content
		end
		if(author.at_xpath('isbn').text=='')
			@title << author.at_xpath('title').text
		end
	end
end
	
puts "Enter the URL"
goodreads_url = gets.chomp
author_id = goodreads_url.split('/').last.split('.').first
goodreads_books(author_id)


def aws_escape(s)
  s.gsub(/[^A-Za-z0-9_.~-]/) { |c| '%' + c.ord.to_s(16).upcase }
end

def signing_logic(params)
	amazon_endpoint= "webservices.amazon.in"
	amazon_path = "/onca/xml"

	signing_params = {
	  :AWSAccessKeyId => ACCESS_IDENTIFIER,
	  :Timestamp => Time.now.gmtime.iso8601
	}
	params.merge!(signing_params)
	canonical_querystring = params.sort.collect do |key, value|
	  [aws_escape(key.to_s), aws_escape(value.to_s)].join('=')
	end.join('&')
	string_to_sign = "GET\n#{amazon_endpoint}\n#{amazon_path}\n#{canonical_querystring}"

	hmac = HMAC::SHA256.new(SECRET_IDENTIFIER)
	hmac.update(string_to_sign)
	signature = Base64.encode64(hmac.digest).chomp

	params[:Signature] = signature
	querystring = params.sort.collect do |key, value|
	  [aws_escape(key.to_s), aws_escape(value.to_s)].join('=')
	end.join('&')

	signed_url = URI("http://#{amazon_endpoint}#{amazon_path}?#{querystring}")
end

(0..@isbn.length - 1).step(10) do |index|
	if((@isbn.length - 1 - index)>=10)
		params1 = {
			:Service => "AWSECommerceService",
			:AssociateTag => "thrilllife-21",
			:Operation => "ItemLookup",
			:IdType => 'ISBN',
			:SearchIndex => 'Books',
			:ItemId => @isbn[index],
			:ResponseGroup => "AlternateVersions",
			:Version => "2015-10-01"
		}
		(1..9).each do |i|
			params1[:ItemId] << ', ' << @isbn[index+i] 
		end
	else
		params1 = {
			:Service => "AWSECommerceService",
			:AssociateTag => "thrilllife-21",
			:Operation => "ItemLookup",
			:IdType => 'ISBN',
			:SearchIndex => 'Books',
			:ItemId => @isbn[index],
			:ResponseGroup => "AlternateVersions",
			:Version => "2015-10-01"
		}
		(index+1..@isbn.length-1).each do |i|
			params1[:ItemId] << ', ' << @isbn[i]
		end

	end	
	params1[:ItemId] = params1[:ItemId].split(', ')

	puts params1
	signed_url_isbn = signing_logic(params1)
	puts signed_url_isbn
#	res1 = open(signed_url_isbn).read
#	doc1 = Nokogiri::XML.parse(res1)
#	$asins = []
#	$asins << t
#	doc1.xpath('//AlternateVersion').each do |a|
#		$asins << a.at_xpath('ASIN').text
#	end
#	$asins.each do |i|
#		puts i
#	end
end
