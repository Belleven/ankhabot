class Dankie
    add_handler Handler::Comando.new(:di, :di,
                                     permitir_params: true,
                                     descripción: 'Repito lo que me digas')
    add_handler Handler::Comando.new(:grita, :grita,
                                     permitir_params: true,
                                     descripción: 'Grito lo que me digas')

    def di(msj, parámetros)
        texto = parámetros || msj.reply_to_message&.text ||
                msj.reply_to_message&.caption
        return if no_hay_texto(msj, texto, 'digo')

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def grita(msj, parámetros)
        con_todo = parámetros && parámetros =~ /\A-perocontodo(\s|\z)/i

        texto = obtener_texto_grita(con_todo, parámetros, msj)
        return if no_hay_texto(msj, texto, 'grito')

        # El primer split es para borrar saltos de línea y espacios al pedo
        texto.split.join(' ')
        return if texto_muy_largo(msj, texto.length)

        mayúsculas = texto.upcase
        palabras = mayúsculas.split

        mandar_palabras_gritos(msj, texto, mayúsculas, palabras)

        # Una palabra por mensaje, y en cada una, una letra en mayúscula
        # por línea, intercaladas entre guiones
        return unless con_todo && palabras.length <= 7

        gritar_infernalmente(palabras, msj)
    end

    private

    def mandar_palabras_gritos(msj, texto, mayúsculas, palabras)
        # Mensaje normal
        @tg.send_message(chat_id: msj.chat.id, text: texto)
        # Mensaje en mayúsculas
        @tg.send_message(chat_id: msj.chat.id, text: mayúsculas)
        # Mensaje en mayúsculas con guiones entre
        # palabras y con espacios entre letras
        # P A L A B R A 1 - P A L A B R A 2
        @tg.send_message(chat_id: msj.chat.id, text: palabras.join('-').chars * ' ')

        palabras_separadas = ''
        palabras.each do |palabra|
            palabras_separadas << "[ #{palabra.chars.join(' - ')} ] "
        end

        # Mensaje con palabras separadas por
        # corchetes, y dentro separadas por guiones
        # [ P - A - L - A - B - R - A - 1 ] [ P - A - L - A - B - R - A - 2 ]
        @tg.send_message(chat_id: msj.chat.id, text: palabras_separadas)
    end

    def gritar_infernalmente(palabras, msj)
        grito_infernal = []
        palabras.each do |palabra|
            grito_infernal << palabra.chars.join("\n-\n")
        end

        grito_infernal&.each do |grito|
            @tg.send_message(chat_id: msj.chat.id, text: grito)
        end
    end

    def obtener_texto_grita(con_todo, parámetros, msj)
        # Caso 1: al comando no lo acompaña un -perocontodo
        return texto_con_todo(msj, parámetros) unless con_todo

        # Caso 2: al comando solo lo acompaña un -perocontodo
        if parámetros.length <= 12
            texto_acompañado_perocontodo(msj, parámetros)
        # Caso 3: al comando lo acompaña un -perocontodo + más texto
        else
            texto_acompañado_más_texto(msj, parámetros)
        end
    end

    def texto_con_todo(msj, params)
        params || msj.reply_to_message&.text || msj.reply_to_message&.caption
    end

    def texto_acompañado_perocontodo(msj, params)
        msj.reply_to_message&.text || msj.reply_to_message&.caption || params
    end

    def texto_acompañado_más_texto(msj, params)
        params[12..] || msj.reply_to_message&.text || msj.reply_to_message&.caption
    end

    def no_hay_texto(msj, texto, acción)
        if (no_hay = texto.nil? || texto.empty?)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Dale #{TROESMAS.sample}, "\
                                   "¿Qué #{acción}?")
        end
        no_hay
    end

    def texto_muy_largo(msj, cant_caracteres)
        if (muy_largo = cant_caracteres > 89)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No puedo gritar tanto, me '\
                                    'duele la garganta')
        end
        muy_largo
    end
end
