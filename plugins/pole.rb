require 'telegram/bot'

class Dankie
    command nisman: 'Muestra el ranking de nisman'

    def pole(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)

        if not @redis.exists("pole:#{msg.chat.id}:done")
            t = Time.now
            t = Time.new(t.year, t.month, t.day + 1).localtime
            msg_time = Time.at(msg.date).localtime
            segundos = t.to_i - msg_time.to_i
            # TODO: hacer que funcione a las 00:00 de argentina, en vez de gmt
            @redis.setex("pole:#{msg.chat.id}:done", segundos, "ok")
            @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)
            @logger.info("#{msg.from.first_name} hizo la nisman en #{msg.chat.id}")
            send_message(chat_id: msg.chat.id,
                         parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{msg.from.first_name}</b> hizo la Nisman")
        end

        return unless msg.text
        cmd = parse_command(msg.text)
        return unless cmd && (cmd[:command] == :nisman)

        texto = '<b>Ranking de Nismans</b>'
        enviado = send_message(chat_id: msg.chat.id,
                               parse_mode: 'html',
                               text: texto + "\ncargando...")
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        # en vez de esto debería tener otra lista de plugins pesados que
        # trabajen en un hilo aparte
        fork do
            poles = redis.zrange("pole:#{msg.chat.id}", 0, -1, with_scores: true)
            poles.sort! do |a, b|
                b.last <=> a.last
            end
            poles.each do |val|
                begin
                    user = @api.get_chat_member(chat_id: msg.chat.id, user_id: val[0])
                    user = Telegram::Bot::Types::ChatMember.new(user['result']).user
                    texto << "\n<pre>#{val[1].to_i}</pre> "
                    texto << if user.username
                                 "<a href=\"https://telegram.me/#{user.username}\">#{user.username}</a>"
                             else
                                 '<pre>user.first_name</pre>'
                             end
                rescue Exception
                    # Despues me fijo que hacer con esto xd
                end
                @api.edit_message_text(chat_id: enviado.chat.id,
                                       message_id: enviado.message_id,
                                       parse_mode: 'html',
                                       disable_web_page_preview: true,
                                       disable_notification: true,
                                       text: texto)
            end
        end
    end
end
