class Dankie
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')
    add_handler Handler::CallbackQuery.new(:acciones_inferiores_lista, 'opcioneslista')
    add_handler Handler::Mensaje.new(:actualizar_datos_usuarios)

    # Método recursivo que actualiza los nombres de usuarios en redis
    def actualizar_datos_usuarios(msj)
        redis_actualizar_datos msj.from

        redis_actualizar_datos msj.forward_from if msj.forward_from

        msj.new_chat_members.each do |usuario|
            redis_actualizar_datos usuario
        end

        redis_actualizar_datos msj.left_chat_member if msj.left_chat_member

        actualizar_datos_usuarios(msj.reply_to_message) if msj.reply_to_message
    end
end
