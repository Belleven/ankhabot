class Dankie
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')
    add_handler Handler::CallbackQuery.new(:acciones_inferiores_lista, 'opcioneslista')
    add_handler Handler::Mensaje.new(:actualizar_datos_usuarios)

    # Método recursivo que actualiza los nombres de usuarios en redis
    # Necesita ser público por los handlers
    def actualizar_datos_usuarios(msj)
        redis_actualizar_datos msj.from

        redis_actualizar_datos msj.forward_from if msj.forward_from

        msj.new_chat_members.each do |usuario|
            redis_actualizar_datos usuario
        end

        redis_actualizar_datos msj.left_chat_member if msj.left_chat_member

        actualizar_datos_usuarios(msj.reply_to_message) if msj.reply_to_message
    end

    # Necesita ser público por los handlers
    def chat_inválido(msj, válidos)
        return if msj.chat.type == 'channel'

        traducciones = { 'private' => 'privado', 'group' => 'grupos',
                         'supergroup' => 'supergrupos', 'channel' => 'canales' }

        texto = "Este comando es válido solo en #{traducciones[válidos.first]}"

        case válidos.length
        when 2
            texto << " y #{traducciones[válidos[1]]}"
        when 3
            texto << ", #{traducciones[válidos[1]]} y #{traducciones[válidos[2]]}"
        end

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    private

    def redis_actualizar_datos(usuario)
        clave = "nombre:#{usuario.id}"

        if @redis.get(clave) != usuario.first_name
            # 86400 = 60 * 60 * 24
            @redis.set clave, usuario.first_name, ex: 86_400
        end

        clave = "usuario:#{usuario.id}"

        return unless @redis.get(clave) != usuario.username

        # 86400 = 60 * 60 * 24
        @redis.set clave, usuario.username, ex: 86_400
    end
end
