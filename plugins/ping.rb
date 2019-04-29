class Dankie
    add_handler CommandHandler.new(:ping, :ping, 'Hace ping', allow_edited: false)

    def ping(msg)
        time1 = Time.at(msg.date)
        enviado = @tg.send_message(chat_id: msg.chat.id,
                               text: 'pong')
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        time2 = Time.new
        @tg.edit_message_text(chat_id: enviado.chat.id,
                          message_id: enviado.message_id,
                          parse_mode: 'markdown',
                          text: "pong\n`#{format('%.3f', (time2.to_r - time1.to_r))}`s")
        @logger.info("pong: #{format('%.3f', (time2.to_r - time1.to_r))}")
    end
end
