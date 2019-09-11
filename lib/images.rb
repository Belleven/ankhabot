require 'net/http'
require 'json'
require_relative 'links.rb'

class ImageSearcher
    def initialize(key, cx, logger)
        @key = key
        @cx = cx
        @logger = logger
    end

    def buscar_imagen(búsqueda, params_búsqueda: nil)
        # Armo la consulta
        consulta = "q=#{búsqueda}&key=#{@key}&cx=#{@cx}"
        agregar_params_búsqueda(consulta, params_búsqueda) if params_búsqueda
        consulta << '&searchType=image'

        # Armo la dirección
        dirección = "https://www.googleapis.com/customsearch/v1?#{consulta}"

        # Obtengo el resultado
        respuesta = Net::HTTP.get_response(URI.parse(URI.escape(dirección)))
        resultado = JSON.parse(respuesta.body)

        if resultado['error'] &&
           resultado['error']['errors'].first['reason'] == 'dailyLimitExceeded'
            @logger.info('Alcancé el límite diario de imágenes')
            return :límite_diario
        elsif resultado['searchInformation']['totalResults'] == '0'
            @logger.info('Sin resultados en la búsqueda')
            return :sin_resultados
        else
            resultado['items'].map { |i| Link.new i['link'] }
        end

    # Error de conexión
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
        @logger.error(e)
        retry
    # Error de parseo
    rescue JSON::ParserError => e
        @logger.error(e)
        :error_parser
    end

    private

    def agregar_params_búsqueda(consulta, params_búsqueda)
        # TODO
    end
end
