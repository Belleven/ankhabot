class Dankie
    add_handler Handler::Mensaje.new(:x2, tipos: [:text])

    def x2(msj)
        texto = msj&.reply_to_message&.text || msj&.reply_to_message&.caption
        return unless texto

        mensaje = msj.text.split.first
        return unless /\A[xX*](\d+)\z/.match? mensaje

        n = mensaje[1..].to_i

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

        resp = @tg.send_message(chat_id: msj.chat.id, text: texto)
        return unless resp['ok']

        añadir_a_cola_spam(msj.chat.id, resp.dig('result', 'message_id').to_i)
    end
end
