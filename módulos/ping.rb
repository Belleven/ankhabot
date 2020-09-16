class Dankie
    add_handler Handler::Comando.new(:ping, :ping, descripción: 'Hago ping')

    def ping(msj)
        # Lo que se tarda en mandar un mensaje
        tiempo1 = Time.new
        enviado = @tg.client.api.send_message(chat_id: msj.chat.id,
                                              text: 'pong')
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])
        tiempo2 = Time.new

        # Lo que se tarda en conectar con la base de datos
        @redis.ping
        tiempo3 = Time.new

        # Calculo tiempos
        tiempo_tg = format('%<tiempo>.3f', tiempo: tiempo2.to_r - tiempo1.to_r)
        tiempo_bbdd = format('%<tiempo>.3f', tiempo: tiempo3.to_r - tiempo2.to_r)

        responder_ping(msj, enviado, tiempo_tg, tiempo_bbdd)
    end

    private

    def responder_ping(msj, enviado, tiempo_tg, tiempo_bbdd)
        # Atraso por flooding
        respuesta = (enviado.date - msj.date).to_i

        # Creo texto
        texto = "pong\n"\
                "tg: <code>#{tiempo_tg}s</code>\n"\
                "bbdd: <code>#{tiempo_bbdd}s</code>"

        # Loggeo
        texto_log = "Ping: tg: #{tiempo_tg}s, bbdd: #{tiempo_bbdd}s"

        if respuesta > 10
            texto << "\nresp: <code>#{respuesta}s</code>"
            texto_log << ", resp: #{respuesta}s"
        end

        # Edito mensaje
        @tg.edit_message_text(chat_id: enviado.chat.id, parse_mode: :html,
                              message_id: enviado.message_id, text: texto)

        @logger.info(texto_log, al_canal: false)
    end
end
