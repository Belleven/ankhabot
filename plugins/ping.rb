class Dankie
    add_handler Handler::Comando.new(:ping, :ping, descripción: 'Hace ping')

    def ping(msj)
        time1 = Time.new
        enviado = @tg.client.api.send_message(chat_id: msj.chat.id,
                                              text: 'pong')
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        time2 = Time.new
        @redis.ping
        time3 = Time.new

        text = "pong\n"
        text << format("%s: <code>%.3fs</code>\n", 'tg',
                       time2.to_r - time1.to_r)
        text << format("%s: <code>%.3fs</code>\n", 'bbdd',
                       time3.to_r - time2.to_r)
        @tg.edit_message_text(chat_id: enviado.chat.id, parse_mode: :html,
                              message_id: enviado.message_id, text: text)
        @logger.log(Logger::INFO, text.tr("\n", "\t"), al_canal: true)
    end
end
