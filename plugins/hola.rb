class Dankie
    add_handler Handler::Mensaje.new(:hola, tipos: [:text])

    def hola(msj)
        frases = ['hola', 'holis', 'aló', 'buenos dias', 'holi', 'holu',
                  'buenos días', 'buenas', 'wenas', 'ola']
        respuesta = 'Hola ' + primer_nombre(msj.from)
        responder(msj, frases, respuesta)
    end

    private

    def responder(msj, frases, respuesta)
        # Este if es para no convertir todo el texto a minúsculas al p2
        if msj.text.length <= 20
            texto = msj.text.downcase

            if frases.include? texto
                @tg.send_message(chat_id: msj.chat.id,
                                 text: respuesta)
               end
        end
    end
end
