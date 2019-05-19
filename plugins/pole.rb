# Extension de dankie para manejar las poles
class Dankie
    add_handler MessageHandler.new(:pole)
    add_handler CommandHandler.new(:nisman, :send_pole_ranking, 'Muestra el ranking de Nisman')

    # TODO: Ponerle algún flag de solo test a este comando
    add_handler CommandHandler.new(:givenisman, :_test_give_nisman)

    def _test_give_nisman(msg)
        id = msg.reply_to_message ? msg.reply_to_message.from.id : msg.from.id
        mensaje = msg.reply_to_message || msg

        name = if mensaje.from.first_name.empty?
                   msg.from.id.to_s
               else
                   mensaje.from.first_name
               end

        @redis.zincrby("pole:#{msg.chat.id}", 1, id)
        @logger.info("#{name} hizo la nisman en #{msg.chat.id}")
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{name}</b> hizo la Nisman")
    end

    def pole(msg)
        return if @redis.exists("pole:#{msg.chat.id}:done")

        now = Time.now
        next_pole = @tz.utc_to_local(Time.new(now.year, now.month, now.day + 1))
        next_pole = next_pole.to_i
        msg_time = @tz.utc_to_local(Time.at(msg.date)).to_i
        @redis.setex("pole:#{msg.chat.id}:done", next_pole - msg_time, 'ok')
        @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)

        name = if msg.from.first_name.empty?
                   "ay no c (#{msg.from.id.to_s})"
               else
                   msg.from.first_name
               end

        @logger.info("#{name} hizo la nisman en #{msg.chat.id}")
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{name}</b> hizo la Nisman")
    end

    def send_pole_ranking(msg)
        texto = '<b>Ranking de Nismans</b>'
        enviado = @tg.send_message(chat_id: msg.chat.id,
                                   parse_mode: 'html',
                                   text: texto + "\ncargando...")
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        # en vez de esto debería tener otra lista de plugins pesados que
        # trabajen en un hilo aparte
        fork do
            edit_pole_ranking(enviado, texto)
        end
    end

    def edit_pole_ranking(enviado, texto)
        poles = @redis.zrevrange("pole:#{enviado.chat.id}",
                                 0, -1, with_scores: true)
        digits = poles.first[1].to_i.digits.count
        poles.each do |val|
            texto << "\n<code>#{format("%#{digits}d", val[1].to_i)} </code>"
            texto << get_username_link(enviado.chat.id, val[0])
            @tg.edit_message_text(chat_id: enviado.chat.id, text: texto,
                                  parse_mode: 'html',
                                  message_id: enviado.message_id,
                                  disable_web_page_preview: true,
                                  disable_notification: true)
        end
    end
end
