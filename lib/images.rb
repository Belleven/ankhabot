require 'net/http'
require 'json'
require_relative 'links.rb'

class ImageSearcher
    def initialize(key, cx, gl, logger)
        @key = key
        @cx = cx
        @gl = gl
        @logger = logger
    end

    def buscar_imagen(búsqueda, params_búsqueda: nil)
        params_uri = [['q', búsqueda], ['key', @key], ['cx', @cx],
                      ['gl', @gl], %w[searchType image]]
        uri_codificado = URI.encode_www_form(params_uri)

        # Armo la dirección
        dirección = "https://www.googleapis.com/customsearch/v1?#{uri_codificado}"
        # Busco la imagen
        respuesta = Net::HTTP.get_response URI.parse(dirección)
        resultado = JSON.parse(respuesta.body)

        # Cuantas imágenes fueron enviadas por día
        # ejemplo: googleapi-2020-12-25
        Stats.incr('googleapi-' + Time.now.strftime("%Y-%m-%d"))

        if resultado['error']
            if ['dailyLimitExceeded', 'rateLimitExceeded'].include? resultado.dig('error', 'errors', 0, 'reason')
                @logger.info('Alcancé el límite diario de imágenes')
                return :límite_diario
            else
                @logger.error resultado['error']
                return :error
            end
        elsif resultado['searchInformation']['totalResults'] == '0'
            @logger.info('Sin resultados en la búsqueda')
            return :sin_resultados
        else

            resultado['items'].map { |i| Link.new i['link'] }
        end

    # Error de conexión
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError,
           HTTPClient::ReceiveTimeoutError, Net::OpenTimeout => e
        @logger.error(e)
        retry
    # Error de parseo
    rescue JSON::ParserError => e
        @logger.error(e)
        :error
    end
end
