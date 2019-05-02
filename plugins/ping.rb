class Dankie
    add_handler CommandHandler.new(:ping, :ping, 'Hace ping')

    def ping(msg, params=nil)
        time1 = Time.new
        enviado = @tg.send_message(chat_id: msg.chat.id, text: 'pong')
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        time2 = Time.new
        @redis.ping
        time3 = Time.new

        text = "pong\n"
        text << "telegram: `#{format('%.3f', time2.to_r - time1.to_r)}s`\n"
        text << "base de datos: `#{format('%.3f', time3.to_r - time2.to_r)}s`"
        @tg.edit_message_text(chat_id: enviado.chat.id, parse_mode: 'markdown',
                              message_id: enviado.message_id, text: text)
        @logger.info text.tr("\n", "\t")
    end
end
