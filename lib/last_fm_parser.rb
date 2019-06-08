require 'net/http'
require 'json'
# @lastfm = "http://ws.audioscrobbler.com/2.0/?method=[METHOD]&format=json&limit=1&api_key=[API]&user=[USERNAME]"

class LastFMParser
    def initialize(api)
        @api = api
    end

    def now_playing(user, amount)
        query = query_builder('user.getrecenttracks', amount, user)
        url = 'http://ws.audioscrobbler.com/2.0/?' + query
        resp = Net::HTTP.get_response(URI.parse(url))
        result = JSON.parse(resp.body)
        return ['error', result['message']] unless result['error'].nil?

        arr = result['recenttracks']['track']
        arr
    end

    def query_builder(method, limit, user)
        q_method = "method=#{method}&format=json"
        # Posible upgrade. Limit permite mandar múltiples de una cosa y no rompe los parsers. (ejemplo las últimas 3 canciones)
        q_limit = "&limit=#{limit}"
        q_api = "&api_key=#{@api}"
        q_user = "&user=#{user}"
        query = q_method + q_limit + q_api + q_user
        query
    end
end
