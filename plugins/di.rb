class Dankie
    add_handler Handler::Comando.new(:di, :di,
                                     descripción: 'Te repito lo que me digas')
    add_handler Handler::Comando.new(:grita, :grita,
                                     descripción: 'Te grito lo que me digas')

    def di(msj)
        text = get_command_params(msj) || msj.reply_to_message&.text || msj.reply_to_message&.caption

        if text.nil? || text == ''
            text = "Dale #{TROESMAS.sample}, ¿Qué digo?"
            @tg.send_message(chat_id: msj.chat.id, text: text,
                             reply_to_message_id: msj.message_id)

            return
        end
        @tg.send_message(chat_id: msj.chat.id, text: text)
    end

    def grita(msj)
        args = get_command_params(msj) || msj.reply_to_message&.text || msj.reply_to_message&.caption
        if args.nil?
            text = "Dale #{TROESMAS.sample}, ¿Qué grito?"
            @tg.send_message(chat_id: msj.chat.id, text: text,
                             reply_to_message_id: msj.message_id)
            return
        end

        large_text = nil
        if args.split.first == '-perocontodo'
            args.gsub!(/^-perocontodo /, '')
            large_text = []
            args.upcase.split.each do |word|
                large_text << word.chars.zip(Array.new(word.size - 1, '-'))
                                  .flatten.compact.join("\n")
            end
        end

        @tg.send_message(chat_id: msj.chat.id, text: args)
        @tg.send_message(chat_id: msj.chat.id, text: args.upcase)

        @tg.send_message(chat_id: msj.chat.id,
                         text: args.upcase.tr(' ', '-').chars * ' ')

        text = ''
        args.upcase.split do |word|
            text << '[ '
            text << word.chars.zip(Array.new(word.size - 1, '-')).flatten
                    .compact.join(' ')
            text << ' ] '
        end

        @tg.send_message(chat_id: msj.chat.id, text: text)

        large_text&.each do |t|
            @tg.send_message(chat_id: msj.chat.id, text: t)
        end
    end
end
