require 'json'
require 'httpclient'

class Dankie
    add_handler Handler::Comando.new(:du, :diccionario_urbano,
                                     descripción:
                                    'Busco una definición en Urban Dictionary '\
                                    '(en vez de /du, también podés usar /ud ' \
                                     'o /urban)',
                                     permitir_params: true,
                                     disable_notification: true)
    add_handler Handler::Comando.new(:ud, :diccionario_urbano,
                                     permitir_params: true,
                                     disable_notification: true)
    add_handler Handler::Comando.new(:urban, :diccionario_urbano,
                                     permitir_params: true,
                                     disable_notification: true)

    def diccionario_urbano(msj, params)
        # Caso input vacía.
        return respuesta_error_ud(msj.chat.id, 'Tirame algo') if params.nil?

        # Tomo el mensaje de entrada y busco una definición.
        diccionario = DiccionarioUrbano.new
        búsqueda = diccionario.búsqueda(params)
        # Caso búsqueda sin resultados, ya sea porque no existe la
        # definición, o porque el UD está caído, hasta donde pude
        # comprobar, si el UD está caído, búsqueda debería
        # ser un objeto nil.
        if búsqueda.nil?
            return respuesta_error_ud(msj.chat.id,
                                      'Mmmm, puede ser que esté caído el UD ')
        end
        return respuesta_error_ud(msj.chat.id, 'Ay no c') if búsqueda.empty?

        # La búsqueda viene como un array con varias definiciones,
        # esta función se encarga de agrupar todo de manera coherente.
        búsqueda = ordenar_resultados(búsqueda)
        mandar_botonera(msj, búsqueda)
    end

    def respuesta_error_ud(id, text)
        @tg.send_message(chat_id: id,
                         text: "#{text}, #{TROESMAS.sample}.")
    end

    def ordenar_resultados(búsqueda)
        # Ordeno según upvotes.
        búsqueda.sort_by! do |resultado|
            -resultado.upvotes
        end
        # Cada elemento individual del array pasa a ser
        # el texto que queremos devolver.
        búsqueda.map! do |resultados|
            palabra = html_parser(resultados.word)
            definición = resultados.definition.gsub(/\[(.+?)\]./,
                                                    '<i>\\1</i> ')
            dirección = html_parser(resultados.permalink)
            ejemplo = html_parser(resultados.example)
            arrivotos = "\u{1F53C}" << resultados.upvotes.to_s
            bajivotos = "\u{1F53D}" << resultados.downvotes.to_s

            "<i><b>#{palabra}</b></i>\n\n#{definición}\n\n<i>"\
            "#{ejemplo}</i>\n\n#{arrivotos}|" \
            "#{bajivotos}|<a href=\"#{dirección}\">link</a>"
        end
    end

    class DiccionarioUrbano
        URL = 'http://api.urbandictionary.com/v0/define'.freeze
        def inicialize; end

        def búsqueda(palabra)
            params = { term: palabra }

            @cliente = comprobar_estado_cliente
            respuesta = JSON.parse(@cliente.get(URI.parse(URL), params).body)
            procesar_respuesta(respuesta)
        end

        private

        def procesar_respuesta(respuesta)
            res = []
            lista = respuesta['list']
            return res if lista.nil?

            lista.each do |entrada|
                res << Entrada.new(entrada)
            end
            res
        end

        def comprobar_estado_cliente
            @cliente = HTTPClient.new if @cliente.nil?
            @cliente
        end
    end

    class Entrada
        attr_reader :id, :word, :author, :permalink, :definition, :example, :upvotes,
                    :downvotes

        def initialize(opts = {})
            @id = opts['defid'] || opts[:defid]
            @word = opts['word'] || opts[:word]
            @author = opts['author'] || opts[:author]
            @permalink = opts['permalink'] || opts[:permalink]
            @definition = opts['definition'] || opts[:definition]
            @example = opts['example'] || opts[:example]
            @upvotes = opts['thumbs_up'] || opts[:thumbs_up]
            @downvotes = opts['thumbs_down'] || opts[:thumbs_down]
        end

        def to_h
            {
                id: @id,
                word: @word,
                author: @author,
                permalink: @permalink,
                definition: @definition,
                example: @example,
                upvotes: @upvotes,
                downvotes: @downvotes
            }
        end
    end
end
