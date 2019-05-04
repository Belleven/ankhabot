require 'net/http'
require 'json'
require_relative 'links.rb'

class ImageSearcher
    def initialize(key, cx)
        @key = key
        @cx = cx
    end

    def search_images(text)
        query = "q=#{text}"
        query << "&key=#{@key}&cx=#{@cx}"
        query << '&searchType=image'
        url = 'https://www.googleapis.com/customsearch/v1?' + query
        resp = Net::HTTP.get_response(URI.parse(URI.escape(url)))
        result = JSON.parse(resp.body)
        if result['items'].nil?
            puts 'posta no encontré una chota'
            return nil
        end
        result['items'].map { |i| Link.new i['link'] }
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
        @client.logger.error(e)
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @client.logger.error(e)
        raise e
    rescue JSON::ParserError, e
        @logger.error(e)
        nil
    end
end
