require 'json'
require 'httparty'

class Dankie
    add_handler Handler::Comando.new(
        :du,
        :diccionario_urbano,
        permitir_params: true,
        descripción: 'Busco una definición en Urban Dictionary (en vez de /du, '\
                     'también podés usar /ud o /urban)'
    )

    add_handler Handler::Comando.new(
        :ud,
        :diccionario_urbano,
        permitir_params: true
    )

    add_handler Handler::Comando.new(
        :urban,
        :diccionario_urbano,
        permitir_params: true
    )

    def diccionario_urbano(msj, params)
        # Caso input vacía.
        if params.nil?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "Tirame algo, #{TROESMAS.sample}."
            )
            return
        end

        # Tomo el mensaje de entrada y busco una definición.
        @dicc_urbano ||= DiccionarioUrbano.new
        búsqueda = @dicc_urbano.búsqueda(params)

        # Caso búsqueda sin resultados, ya sea porque no existe la definición, o porque
        # el UD está caído, hasta donde pude comprobar, si el UD está caído, búsqueda
        # debería ser un objeto nil.
        if búsqueda.nil?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "Mmmm, puede ser que esté caído el UD, #{TROESMAS.sample}."
            )
            return
        elsif búsqueda.empty?
            @tg.send_message(chat_id: msj.chat.id, text: "Ay no c, #{TROESMAS.sample}.")
            return
        end

        # La búsqueda viene como un array con varias definiciones,
        # esta función se encarga de agrupar todo de manera coherente.
        búsqueda = ordenar_resultados_urban_dict(búsqueda)
        mandar_botonera(msj, búsqueda)
    end

    private

    def ordenar_resultados_urban_dict(búsqueda)
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
end

class DiccionarioUrbano
    URL = 'http://api.urbandictionary.com/v0/define'.freeze

    def inicialize; end

    def búsqueda(palabra)
        params = { term: palabra }
        respuesta = JSON.parse(HTTParty.get("#{URL}?term=#{palabra}").body)
        procesar_respuesta(respuesta)
    end

    private

    def procesar_respuesta(respuesta)
        return [] unless (lista = respuesta['list'])

        lista.map { |entrada| Entrada.new(entrada) }
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
