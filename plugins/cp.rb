# Extensión de Dankie para generar mensajes cp
class Dankie
    add_handler Handler::EventoDeChat.new(:cp_supergrupo,
                                          tipos: [:migrate_from_chat_id],
                                          chats_permitidos: %i[supergroup])
    add_handler Handler::Mensaje.new(:añadir_palabras_cp, tipos: [:text])
    add_handler Handler::Comando.new(:cp, :cp,
                                     descripción: 'Genero una posible '\
                                                  'definición de la sigla cp, '\
                                                  'usando texto del chat')

    def añadir_palabras_cp(msj)
        crear_variables(msj)

        msj.text.split.each do |pal|
            next if pal.size > 30

            @palabras_c[msj.chat.id] << pal if pal[0].downcase == 'c'
            @palabras_p[msj.chat.id] << pal if pal[0].downcase == 'p'
        end

        [@palabras_c[msj.chat.id], @palabras_p[msj.chat.id]].each do |arr|
            arr.shift while arr.size > 40
        end
    end

    def cp(msj)
        if @palabras_c[msj.chat.id].empty? || @palabras_p[msj.chat.id].empty?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Hacen falta más mensajes')
        end

        cp = [@palabras_c[msj.chat.id].sample, @palabras_p[msj.chat.id].sample]
        texto = cp.join ' '

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def cp_supergrupo(msj)
        crear_variables(msj)

        @palabras_c[msj.chat.id] = @palabras_c[msj.migrate_from_chat_id]
        @palabras_c.delete(msj.migrate_from_chat_id)

        @palabras_p[msj.chat.id] = @palabras_p[msj.migrate_from_chat_id]
        @palabras_p.delete(msj.migrate_from_chat_id)
    end

    private

    def crear_variables(msj)
        @palabras_c ||= {}
        @palabras_c[msj.chat.id] ||= []
        @palabras_p ||= {}
        @palabras_p[msj.chat.id] ||= []
    end
end
