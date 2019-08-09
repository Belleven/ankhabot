class Dankie
    add_handler Handler::Comando.new(:di, :di,
                                     descripción: 'Te repito lo que me digas')
    add_handler Handler::Comando.new(:grita, :grita,
                                     descripción: 'Te grito lo que me digas')

    def di(msj)
        texto = get_command_params(msj) || msj.reply_to_message&.text || msj.reply_to_message&.caption

        if texto.nil? || texto == ''
            texto = "Dale #{TROESMAS.sample}, ¿Qué digo?"
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: msj.message_id)

            return
        end
        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def grita(msj)
        args = get_command_params(msj) || msj.reply_to_message&.text || msj.reply_to_message&.caption
        if args.nil?
            texto = "Dale #{TROESMAS.sample}, ¿Qué grito?"
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        texto_largo = nil
        if args.split.first == '-perocontodo'
            args.gsub!(/^-perocontodo /, '')
            texto_largo = []
            args.upcase.split.each do |palabra|
                texto_largo << palabra.chars.zip(Array.new(palabra.size - 1, '-'))
                                      .flatten.compact.join("\n")
            end
        end

        @tg.send_message(chat_id: msj.chat.id, text: args)
        @tg.send_message(chat_id: msj.chat.id, text: args.upcase)

        @tg.send_message(chat_id: msj.chat.id,
                         text: args.upcase.tr(' ', '-').chars * ' ')

        texto = ''
        args.upcase.split do |palabra|
            texto << '[ '
            texto << palabra.chars.zip(Array.new(palabra.size - 1, '-')).flatten
                     .compact.join(' ')
            texto << ' ] '
        end

        @tg.send_message(chat_id: msj.chat.id, text: texto)

        texto_largo&.each do |t|
            @tg.send_message(chat_id: msj.chat.id, text: t)
        end
    end
end
