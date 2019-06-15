require 'concurrent-ruby'

# Extension de dankie para manejar las poles
class Dankie
    add_handler MessageHandler.new(:pole)
    add_handler CommandHandler.new(:nisman, :enviar_ranking_pole,
                                   description: 'Muestra el ranking de Nisman')

    # TODO: Ponerle algún flag de solo test a este comando
    # add_handler CommandHandler.new(:darnisman, :_test_dar_nisman)

    def _test_dar_nisman(msg)
        id = msg.reply_to_message ? msg.reply_to_message.from.id : msg.from.id
        mensaje = msg.reply_to_message || msg

        nombre = mensaje.from.first_name.empty? ? msg.from.id.to_s : html_parser(mensaje.from.first_name)

        @redis.zincrby("pole:#{msg.chat.id}", 1, id)
        @logger.info("#{nombre} hizo la nisman en #{msg.chat.id}")
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")
    end

    def pole(msg)
        return if @redis.exists("pole:#{msg.chat.id}:done")

        ahora = Time.now
        próx_pole = @tz.utc_to_local(Time.new(ahora.year, ahora.month, ahora.day + 1))
        próx_pole = próx_pole.to_i
        fecha_msg = @tz.utc_to_local(Time.at(msg.date)).to_i
        @redis.setex("pole:#{msg.chat.id}:done", próx_pole - fecha_msg, 'ok')
        @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)

        nombre = msg.from.first_name.empty? ? "ay no c (#{msg.from.id})" : html_parser(msg.from.first_name)

        @logger.info("#{nombre} hizo la nisman en #{msg.chat.id}")
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")
    end

    def enviar_ranking_pole(msg)
        texto = '<b>Ranking de Nisman</b>'
        enviado = @tg.send_message(chat_id: msg.chat.id,
                                   parse_mode: 'html',
                                   text: texto + "\n\n<i>cargando...</i>")
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        # en vez de esto debería tener otra lista de plugins pesados que
        # trabajen en un hilo aparte
        fork do
            editar_ranking_pole(enviado, texto)
        end
    end

    def editar_ranking_pole(enviado, texto)
        # Tomo las poles de las bases de datos y seteo los espacios para dígitos
        poles = @redis.zrevrange("pole:#{enviado.chat.id}", 0, -1, with_scores: true)
        dígitos = poles.first[1].to_i.digits.count

        # Tomo el total de poles y lo agrego al título
        texto << " (#{ calcular_total_poles(poles) })\n"

        # Tomo otras variables que luego usaré
        chat_id = enviado.chat.id
        índice = 0

        poles.each do |pole|
            # Armo la línea y el cargando... si es que no es la última línea
            línea = "\n<code>#{format("%#{dígitos}d", pole[1].to_i)}</code> "
            línea << get_username_link(enviado.chat.id, pole[0])

            cargando = índice == poles.length - 1 ? '' : "\n<i>cargando...</i>"

            # Si el mensaje se pasa de los 4096 caracteres, mando uno nuevo
            if texto.length + línea.length + cargando.length > 4096

                # Primero borro el "cargando" del mensaje anterior
                @tg.edit_message_text(chat_id: chat_id, text: texto,
                                      parse_mode: 'html',
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)

                # Después mando el nuevo mensaje
                texto = línea
                enviado = @tg.send_message(chat_id: chat_id, text: texto + cargando,
                                           parse_mode: 'html',
                                           disable_web_page_preview: true,
                                           disable_notification: true)
                enviado = Telegram::Bot::Types::Message.new(enviado['result'])

            # Si no, edito el actual
            else
                texto << línea
                @tg.edit_message_text(chat_id: chat_id, text: texto + cargando,
                                      parse_mode: 'html',
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)
            end

            índice += 1
        end
    end

    def calcular_total_poles(poles)
        acumulador = 0
        poles.each do |pole|
            acumulador += pole[1].to_i
        end
        acumulador
    end
end
