class Dankie
    add_handler MessageHandler.new(:x2)
    def x2(msg, params=nil)
        return unless msg.text

        text = msg&.reply_to_message&.text || msg&.reply_to_message&.caption
        return unless text

        message = msg.text.split(' ').first
        return unless (r = /^[xX*](\d+)/) =~ message

        n = message.gsub(r, '\\1').to_i
        text << ' '

        n = (4096 / text.length) + 1 if (text.length * n - 1) > 4096

        if n.positive?
            text *= n
            cansado = '... ya fue, me cansé.'
            if text.length >= 4096 - cansado.length
                text = text[0..(4096 - cansado.length - 1)] + cansado
            end
        else
            text = '""'
        end

        @tg.send_message(chat_id: msg.chat.id, text: text)
    end
end
