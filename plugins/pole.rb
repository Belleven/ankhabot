require 'telegram/bot'

# Extension de dankie para manejar las poles
class Dankie
    command nisman: 'Muestra el ranking de nisman'

    def pole(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)

        unless @redis.exists("pole:#{msg.chat.id}:done")
            now = Time.now
            t = @tz.utc_to_local(
                Time.new(now.year, now.month, now.day + 1)).to_i
            msg_time = @tz.utc_to_local(Time.at(msg.date)).to_i
            @redis.setex(
                "pole:#{msg.chat.id}:done", t - msg_time, 'ok')
            @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)
            @logger.info(
                "#{msg.from.first_name} hizo la nisman en #{msg.chat.id}")
            send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{msg.from.first_name}</b> hizo la Nisman")
        end

        cmd = parse_command(msg)

        ranking(msg) if cmd && cmd[:command] == :nisman
    end

    private

    def ranking(msg)
        texto = '<b>Ranking de Nismans</b>'
        enviado = send_message(chat_id: msg.chat.id,
                               parse_mode: 'html',
                               text: texto + "\ncargando...")
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        # en vez de esto debería tener otra lista de plugins pesados que
        # trabajen en un hilo aparte
        fork do
            send_pole enviado, texto
        end
    end

    def text_body(user)
        if user.username
            "<a href='https://telegram.me/#{user.username}'>#{user.username}</a>"
        else
            "<pre>#{user.first_name}</pre>"
        end
    end

    def send_pole(enviado, texto)
        poles = @redis.zrange(
            "pole:#{enviado.chat.id}", 0, -1, with_scores: true
        ).sort_by! { |a| -a[1] }
        poles.each do |val|
            begin
                user = @api.get_chat_member(chat_id: enviado.chat.id, user_id: val[0])
                user = Telegram::Bot::Types::ChatMember.new(user['result']).user
                texto << "\n<pre>#{val[1].to_i}</pre> "
                texto << text_body(user)
            rescue StandardError, e
                @logger.error(e)
            end
            @api.edit_message_text(chat_id: enviado.chat.id, parse_mode: 'html',
                                   message_id: enviado.message_id,
                                   disable_web_page_preview: true,
                                   disable_notification: true, text: texto)
            puts texto
        end
    end
end
