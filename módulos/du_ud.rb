require 'urbandict'
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
        return respuesta(msj.chat.id, 'Tirame algo') if params.nil?

        # Filtro en caso que haya caracteres no alfanumericos
        params.gsub!(/\W+/, '')

        if params.empty?
            return respuesta(msj.chat.id, 'Tu busqueda no es válida,'\
                    ' tiene que tener al menos un caracter o un número')
        end

        # Tomo el mensaje de entrada y busco una definición.
        búsqueda = UrbanDictionary.define(params)
        # Caso búsqueda sin resultados, ya sea porque no existe la
        # definición, o porque el UD está caído, hasta donde pude
        # comprobar, si el UD está caído, búsqueda debería
        # ser un objeto nil.
        if búsqueda.nil?
            return respuesta(msj.chat.id,
                             'Mmmm, puede ser que esté caído el UD ')
        end
        return respuesta(msj.chat.id, 'Ay no c') if búsqueda.empty?

        # La búsqueda viene como un array con varias definiciones,
        # esta función se encarga de agrupar todo de manera coherente.
        búsqueda = ordenar_resultados(búsqueda)
        mandar_botonera(msj, búsqueda)
    end

    def respuesta(id, text = '')
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
end
