require 'net/http'
require 'json'


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
        resp = Net::HTTP.get_response(URI.parse(url))
        result = JSON.parse(resp.body)
        if result['items'].nil?
            return nil
        end
        arr = result['items'].map { |i| i['link'] }
        arr
#        else
#            result_size = result['items'].count
#            bot.api.send_chat_action(chat_id: message.chat.id, action: 'upload_photo')
#            bot.api.send_photo(chat_id: message.chat.id,
#                               photo: result['items'][rand(result_size)]['link'])
#        end
    end
end
