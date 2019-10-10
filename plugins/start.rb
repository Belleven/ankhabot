class Dankie
    add_handler Handler::Comando.new(:start, :inicio)
    add_handler Handler::Comando.new(:inicio, :inicio,
                                     descripción: 'Mando el mensaje de inicio/flood')

    def inicio(msj)
        texto = if msj.chat.type == 'supergroup' || msj.chat.type == 'group'
                    'Hola, vengo a floodear'
                else
                    "Hola #{TROESMAS.sample}, mandame /ayuda para saber qué hago"
                end

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end
end
