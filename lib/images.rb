require 'net/http'
require 'json'
require_relative 'links'

class ImageSearcher
    def initialize(key, cx, gl, logger)
        @key = key
        @cx = cx
        @gl = gl
        @logger = logger
    end

    def buscar_imagen(búsqueda)
        params_uri = [['q', búsqueda], ['key', @key], ['cx', @cx],
                      ['gl', @gl], %w[searchType image]]
        uri_codificado = URI.encode_www_form(params_uri)

        # Armo la dirección
        dirección = "https://www.googleapis.com/customsearch/v1?#{uri_codificado}"
        # Busco la imagen
        respuesta = Net::HTTP.get_response URI.parse(dirección)
        resultado = JSON.parse(respuesta.body)

        if resultado['error']
            if %w[dailyLimitExceeded
                  rateLimitExceeded].include? resultado.dig('error', 'errors', 0,
                                                            'reason')
                @logger.info('Alcancé el límite diario de imágenes')

                incrementar_exceso_api
                :límite_diario
            else
                incrementar_uso_api
                @logger.error resultado['error']
                :error
            end
            return
        end

        incrementar_uso_api

        if resultado['searchInformation']['totalResults'] == '0'
            @logger.info('Sin resultados en la búsqueda')
            :sin_resultados
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

    private

    def incrementar_uso_api
        # Cuantas imágenes fueron enviadas por hora
        # ejemplo: googleapi:1598302800
        Estadísticas::Contador.incr('googleapi', hora: Time.now.to_i, intervalo: 600)
    end

    def incrementar_exceso_api
        Estadísticas::Contador.incr('googleapi:excedida', hora: Time.now.to_i,
                                                          intervalo: 600)
    end
end
