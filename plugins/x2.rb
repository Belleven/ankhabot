class Dankie
    add_handler Handler::Mensaje.new(:x2)

    def x2(msj)
        return unless msj.text

        texto = msj&.reply_to_message&.text || msj&.reply_to_message&.caption
        return unless texto

        mensaje = msj.text.split(' ').first
        return unless (r = /^[xX*](\d+)/) =~ mensaje

        n = mensaje.gsub(r, '\\1').to_i
        texto << ' '

        n = (4096 / texto.length) + 1 if (texto.length * n - 1) > 4096

        if n.positive?
            texto *= n
            cansado = '... ya fue, me cansé.'
            if texto.length >= 4096 - cansado.length
                texto = texto[0..(4096 - cansado.length - 1)] + cansado
            end
        else
            texto = '""'
        end

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end
end
