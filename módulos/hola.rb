class Dankie
    add_handler Handler::Mensaje.new(:hola, tipos: [:text])

    def hola(msj)
        frases = ['hola', 'holis', 'aló', 'buenos dias', 'holi', 'holu',
                  'buenos días', 'buenas', 'wenas', 'ola']
        respuesta = ['Hola ', 'Hola a todos, menos a '].sample + primer_nombre(msj.from)
        responder(msj, frases, respuesta)
    end

    private

    def responder(msj, frases, respuesta)
        # Este if es para no convertir todo el texto a minúsculas al p2
        return unless msj.text.length <= 20 && !msj.reply_to_message

        texto = msj.text.downcase

        return unless frases.include? texto

        enviar_mensaje_y_a_spam(chat_id: msj.chat.id, text: respuesta)
    end
end
