class Dankie
    add_handler Handler::Mensaje.new(:x2, tipos: [:text])

    def x2(msj)
        return unless validar_permiso_x2(msj.chat.id)

        texto = msj&.reply_to_message&.text || msj&.reply_to_message&.caption
        return unless texto

        mensaje = msj.text.split.first
        return unless validar_comando(mensaje)

        mensaje = generar_mensaje(mensaje, texto)

        resp = @tg.send_message(chat_id: msj.chat.id, text: mensaje)
        return unless resp && resp['ok']

        añadir_a_cola_spam(msj.chat.id, resp.dig('result', 'message_id').to_i)
    end

    private

    def validar_permiso_x2(chat_id)
        Configuración.redis ||= @redis
        puede = Configuración.config(chat_id, :admite_x2)
        puede.nil? ? true : puede.to_i.positive?
    end

    def validar_comando(mensaje)
        /\A[xX*](\d+)\z/.match? mensaje
    end

    def generar_mensaje(mensaje, texto)
        veces = mensaje[1..].to_i
        return '""' if veces.zero?

        texto << ' '
        veces = (4096 / texto.length) + 1 if (texto.length * veces - 1) > 4096

        texto *= veces
        cansado = '... ya fue, me cansé.'

        if texto.length >= 4096 - cansado.length
            texto = texto[0..(4096 - cansado.length - 1)] + cansado
        end
        texto
    end
end
