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
        # Armo la dirección
        dirección = 'https://www.googleapis.com/customsearch/v1?'\
                    "q=#{búsqueda}&key=#{@key}&cx=#{@cx}&gl=#{@gl}"\
                    '&searchType=image'

        agregar_params_búsqueda(consulta, params_búsqueda) if params_búsqueda

        # Obtengo el resultado
        dirección_codificada = URI.encode_www_form_component(dirección)
        respuesta = Net::HTTP.get_response URI.parse(dirección_codificada)
        resultado = JSON.parse(respuesta.body)

        if resultado['error']
            if resultado.dig('error', 'errors', 0, 'reason') == 'dailyLimitExceeded'
                @logger.info('Alcancé el límite diario de imágenes')
                return :límite_diario
            else
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

    private

    def agregar_params_búsqueda(consulta, params_búsqueda)
        # TODO
    end
end
