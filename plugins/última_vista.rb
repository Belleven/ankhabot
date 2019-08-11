class Dankie
    add_handler Handler::EventoDeChat.new(:última_vista_supergrupo,
                                          tipos: [:migrate_from_chat_id])
    add_handler Handler::Mensaje.new(:registrar_tiempo)
    add_handler Handler::EventoDeChat.new(:registrar_tiempo)

    def registrar_tiempo(msj)
        # Eso de is_bot es porque los eventos de
        # chat que son de bots SÍ los recibe
        if (msj.chat.type == 'supergroup' || msj.chat.type == 'group') &&
           !msj.from.is_bot

            @redis.hmset("último_mensaje:#{msj.chat.id}",
                         msj.from.id.to_s,
                         msj.date.to_s)
        end
    end

    # Cuando un grupo cambia a supergrupo
    def última_vista_supergrupo(msj)
        # Esta función está definida en dankie.rb
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'último_mensaje:')
    end
end
