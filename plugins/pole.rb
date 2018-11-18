require 'telegram/bot'

# Extension de dankie para manejar las poles
class Dankie
    command nisman: 'Muestra el ranking de nisman'

    def pole(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)

        unless @redis.exists("pole:#{msg.chat.id}:done")
            now = Time.now
            t = @tz.utc_to_local(
                Time.new(now.year, now.month, now.day + 1)
            ).to_i
            msg_time = @tz.utc_to_local(Time.at(msg.date)).to_i
            @redis.setex(
                "pole:#{msg.chat.id}:done", t - msg_time, 'ok'
            )
            @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)
            @logger.info(
                "#{msg.from.first_name} hizo la nisman en #{msg.chat.id}"
            )
            send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{msg.from.first_name}</b> hizo la Nisman")
        end

        cmd = parse_command(msg)

        send_pole_ranking(msg) if cmd && cmd[:command] == :nisman
    end

    private

    def send_pole_ranking(msg)
        texto = '<b>Ranking de Nismans</b>'
        enviado = send_message(chat_id: msg.chat.id,
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
        poles = @redis.zrange(
            "pole:#{enviado.chat.id}", 0, -1, with_scores: true
        ).sort_by! { |a| -a[1] }
        digits = poles.first[1].to_i.digits.count
        poles.each do |val|
            texto << "\n<code>#{format("%#{digits}d", val[1].to_i)} </code>"
            texto << get_username_link(enviado.chat.id, val[0])
            edit_message_text(chat_id: enviado.chat.id,  text: texto,
                              parse_mode: 'html',
                              message_id: enviado.message_id,
                              disable_web_page_preview: true,
                              disable_notification: true)
        end
    end
end
