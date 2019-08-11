class Dankie
    add_handler Handler::EventoDeChat.new(:última_vez_supergrupo,
                                          tipos: [:migrate_from_chat_id])
    add_handler Handler::Mensaje.new(:registrar_tiempo)
    add_handler Handler::EventoDeChat.new(:registrar_tiempo)

    def registrar_tiempo(msj)
        # Eso de is_bot es porque los eventos de
        # chat que son de bots SÍ los recibe
        if (msj.chat.type == 'supergroup' || msj.chat.type == 'group') &&
           !msj.from.is_bot

            # Primero reviso si se está yendo alguien
            if msj.left_chat_member
                @redis.hdel("último_mensaje:#{msj.chat.id}",
                            msj.left_chat_member.id.to_s)
                return if msj.from.id == msj.left_chat_member.id
            end

            # Después registro a los nuevos miembros (si hay)
            msj.new_chat_members.each do |usuario|
                next if usuario.is_bot

                @redis.hset("último_mensaje:#{msj.chat.id}",
                            usuario.id.to_s,
                            msj.date.to_s)
            end

            # Por último registro a quien mandó el mensaje
            # podría ser que alguien se una al grupete solo
            # y ahí ya se registra dos veces (una acá y otra en el
            # bucle anterior) pero no importa, no es demasiado.
            @redis.hset("último_mensaje:#{msj.chat.id}",
                        msj.from.id.to_s,
                        msj.date.to_s)
        end
    end

    # Cuando un grupo cambia a supergrupo
    def última_vez_supergrupo(msj)
        # Esta función está definida en dankie.rb
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'último_mensaje:')
    end
end
