class Dankie
    add_handler CommandHandler.new(:di, :di,
                                   'Te repito lo que me digas')
    add_handler CommandHandler.new(:grita, :grita,
                                   'Te grito lo que me digas')

    def di(msg)
        cmd = parse_command(msg)
        text = cmd[:params]
        if text.nil? || text == ''
            text = "Dale #{TROESMAS.sample}, ¿Qué digo?"
            @tg.send_message(chat_id: msg.chat.id, text: text,
                             reply_to_message: msg.message_id)

            return
        end
        @tg.send_message(chat_id: msg.chat.id, text: text)
    end

    def grita(msg)
        cmd = parse_command(msg)
        args = cmd[:params] || msg.reply_to_message&.text || msg.reply_to_message&.caption
        if args.nil?
            text = "Dale #{TROESMAS.sample}, ¿Qué grito?"
            @tg.send_message(chat_id: msg.chat.id, text: text,
                             reply_to_message: msg.message_id)
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

        @tg.send_message(chat_id: msg.chat.id, text: args)
        @tg.send_message(chat_id: msg.chat.id, text: args.upcase)

        @tg.send_message(chat_id: msg.chat.id,
                         text: args.upcase.tr(' ', '-').chars * ' ')

        text = ''
        args.upcase.split do |word|
            text << '[ '
            text << word.chars.zip(Array.new(word.size - 1, '-')).flatten
                    .compact.join(' ')
            text << ' ] '
        end

        @tg.send_message(chat_id: msg.chat.id, text: text)

        large_text&.each do |t|
            @tg.send_message(chat_id: msg.chat.id, text: t)
        end
    end
end
