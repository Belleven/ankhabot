class Dankie
    add_handler Handler::Mensaje.new(:registrar_alias,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::EventoDeChat.new(:registrar_alias,
                                          chats_permitidos: %i[group supergroup])

    def registrar_alias(msj)
        registrar_alias_usuario(msj.from)
        registrar_alias_usuario(msj.reply_to_message.from) if msj.reply_to_message

        # Si no hay ningun nuevo miembro es un array vacio, por eso no hace falta
        # validar contra nil
        msj.new_chat_members.each do |usuario|
            registrar_alias_usuario(usuario)
        end
    end

    # alias es un hash, donde cada campo es una id y el valor de cada campo
    # es un alias

    # id es un hash, donde cada campo es un alias y el valor de cada campo
    # es una id

    def registrar_alias_usuario(usuario)
        return if usuario.nil?

        alias_actual = usuario.username
        id_usuario = usuario.id.to_s

        alias_antiguo = obtener_alias_de_id(id_usuario)

        # Si tiene alias ahora
        if alias_actual

            # Si cambió el alias entonces borro la entrada vieja en id
            if alias_antiguo && alias_actual != alias_antiguo
                @redis.del("id:#{alias_antiguo}")
                @logger.info(
                    "\"#{alias_antiguo}\" cambió su alias a: \"#{alias_actual}\""
                )
            end

            # Guardo el alias actual en "alias" (sobreescribiendo el anterior)
            # Guardo la id actual en "id"
            @redis.set("alias:#{id_usuario}", alias_actual)
            @redis.set("id:#{alias_actual}", id_usuario)
        # Si no tiene alias ahora pero tenía antes, hay que borrar cosas
        elsif alias_antiguo
            @redis.del("id:#{alias_antiguo}")
            @redis.del("alias:#{id_usuario}")
        end
    end

    private

    def obtener_id_de_alias(alias_usuario)
        @redis.get("id:#{alias_usuario}")
    end

    def obtener_alias_de_id(id_usuario)
        @redis.get("alias:#{id_usuario}")
    end
end
