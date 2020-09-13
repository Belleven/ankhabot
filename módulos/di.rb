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

        if con_todo
            # Caso 1: al comando solo lo acompaña un -perocontodo
            if parámetros.length <= 12
                texto = msj.reply_to_message&.text ||
                        msj.reply_to_message&.caption || parámetros
            # Caso 2: al comando lo acompaña un -perocontodo + más texto
            else
                texto = parámetros[12..] ||
                        msj.reply_to_message&.text || msj.reply_to_message&.caption
            end
        # Caso 3: al comando no lo acompaña un -perocontodo
        else
            texto = parámetros ||
                    msj.reply_to_message&.text || msj.reply_to_message&.caption
        end

        return if no_hay_texto(msj, texto, 'grito')

        # El primer split es para borrar saltos de línea y espacios al pedo
        texto.split.join(' ')
        return if texto_muy_largo(msj, texto.length)

        mayúsculas = texto.upcase
        palabras = mayúsculas.split

        # Mensaje normal
        @tg.send_message(chat_id: msj.chat.id, text: texto)
        # Mensaje en mayúsculas
        @tg.send_message(chat_id: msj.chat.id, text: mayúsculas)
        # Mensaje en mayúsculas con guiones entre
        # palabras y con espacios entre letras
        # P A L A B R A 1 - P A L A B R A 2
        @tg.send_message(chat_id: msj.chat.id,
                         text: palabras.join('-').chars * ' ')

        palabras_separadas = ''
        palabras.each do |palabra|
            palabras_separadas << "[ #{palabra.chars.join(' - ')} ] "
        end

        # Mensaje con palabras separadas por
        # corchetes, y dentro separadas por guiones
        # [ P - A - L - A - B - R - A - 1 ] [ P - A - L - A - B - R - A - 2 ]
        @tg.send_message(chat_id: msj.chat.id, text: palabras_separadas)

        # Una palabra por mensaje, y en cada una, una letra en mayúscula
        # por línea, intercaladas entre guiones
        return unless con_todo && palabras.length <= 7

        grito_infernal = []
        palabras.each do |palabra|
            grito_infernal << palabra.chars.join("\n-\n")
        end

        grito_infernal&.each do |grito|
            @tg.send_message(chat_id: msj.chat.id, text: grito)
        end
    end

    private

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
