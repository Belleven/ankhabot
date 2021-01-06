class Dankie
    add_handler Handler::Mensaje.new(:actualizar_datos_usuarios)
    add_handler Handler::Mensaje.new(
        :informar_cambio_datos_en_grupo,
        chats_permitidos: %w[group supergroup]
    )
    add_handler Handler::EventoDeChat.new(
        :datos_usuario_supergrupo,
        tipos: [:migrate_from_chat_id],
        chats_permitidos: %i[supergroup]
    )

    # Método recursivo que actualiza los nombres de usuarios en redis
    # Necesita ser público por los handlers
    def actualizar_datos_usuarios(msj)
        usuarios = [msj.from, msj.forward_from, msj.left_chat_member]
        (usuarios + msj.new_chat_members).compact.each do |usuario|
            informar_cambio_datos_usuario(
                usuario.id,
                msj.chat,
                redis_actualizar_datos_usuario(usuario)
            )
        end

        actualizar_datos_usuarios(msj.reply_to_message) if msj.reply_to_message
    end

    def informar_cambio_datos_en_grupo(msj)
        # TODO: return if hay una configuración de grupo para que no envíe esto
        # TODO return if hay una configuración de usuario para que no envíe esto
        # TODO considerar el caso donde el usuario recién ingresa al grupo

        id_usuario = msj.from.id
        id_chat = msj.chat.id

        cambios = []

        { 'nombre' => :texto_cambio_nombre_usuario,
          'apellido' => :texto_cambio_apellido_usuario,
          'username' => :texto_cambio_username_usuario }.each do |clave, método|
            unless @redis.sismember("informar_cambio:#{clave}:#{id_usuario}", id_chat)
                cambios << send(método, id_usuario)
                @redis.sadd("informar_cambio:#{clave}:#{id_usuario}", id_chat)
            end
        end

        return if cambios.empty?

        # me fijo los grupos normales y guardo sus ID en caso de migración a supergrupo
        if msj.chat.type == 'group'
            @redis.sadd("migración_supergrupo_informar_cambio:#{id_chat}", id_usuario)
        end

        # Si es la primera vez que se ve en este grupete entonces marco como que se
        # informó el cambio pero sin enviar ningun mensaje, la próxima ya se manda
        unless @redis.sismember("contacto_grupo:#{id_usuario}", id_chat)
            @redis.sadd("contacto_grupo:#{id_usuario}", id_chat)
            return
        end

        texto = obtener_enlace_usuario(id_usuario, id_chat)
        texto << " cambió su información de usuario:\n"

        @tg.send_message(chat_id: id_chat,
                         parse_mode: :html,
                         text: texto + cambios.join,
                         disable_notification: true,
                         disable_web_page_preview: true)
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

    def datos_usuario_supergrupo(msj)
        id_vieja = msj.migrate_from_chat_id
        id_nueva = msj.chat.id
        clave = "migración_supergrupo_informar_cambio:#{id_vieja}"

        @redis.smembers(clave).each do |id_usuario|
            %w[nombre apellido username].each do |nombre|
                next unless @redis.sismember("informar_cambio:#{nombre}:#{id_usuario}",
                                             id_vieja)

                @redis.sadd("informar_cambio:#{clave}:#{id_usuario}", id_nueva)
                @redis.srem("informar_cambio:#{clave}:#{id_usuario}", id_vieja)
            end

            if @redis.sismember("contacto_grupo:#{id_usuario}", id_vieja)
                @redis.sadd("contacto_grupo:#{id_usuario}", id_nueva)
                @redis.srem("contacto_grupo:#{id_usuario}", id_vieja)
            end
        end

        @redis.del clave
    end

    private

    def informar_cambio_datos_usuario(id_usuario, chat, cambios)
        return if cambios.empty?
        return if %w[private channel].include? chat.type

        @redis.sadd("contacto_grupo:#{id_usuario}", chat.id)

        # TODO: return if hay una configuración de grupo para que no envíe esto
        # TODO return if hay una configuración de usuario para que no envíe esto

        texto = obtener_enlace_usuario(id_usuario, chat.id)
        texto << " cambió su información de usuario:\n"

        if cambios.include? :nombre
            texto << texto_cambio_nombre_usuario(id_usuario)
            @redis.del("informar_cambio:nombre:#{id_usuario}")
            @redis.sadd("informar_cambio:nombre:#{id_usuario}", chat.id)
        end

        if cambios.include? :apellido
            texto << texto_cambio_apellido_usuario(id_usuario)
            @redis.del("informar_cambio:apellido:#{id_usuario}")
            @redis.sadd("informar_cambio:apellido:#{id_usuario}", chat.id)
        end

        if cambios.include? :username
            texto << texto_cambio_username_usuario(id_usuario)
            @redis.del("informar_cambio:username:#{id_usuario}")
            @redis.sadd("informar_cambio:username:#{id_usuario}", chat.id)
        end

        @tg.send_message(chat_id: chat.id,
                         parse_mode: :html,
                         text: texto,
                         disable_notification: true,
                         disable_web_page_preview: true)
    end

    def texto_cambio_nombre_usuario(id_usuario)
        texto = "\n<b>Nombre:</b>\n<code>"
        texto << nombres_usuario(id_usuario)
                 .to_a
                 .last(2)
                 .map(&:first)
                 .map { |s| html_parser s }
                 .join(' ➜ ')
        texto << '</code>'
    end

    def texto_cambio_apellido_usuario(id_usuario)
        texto = "\n<b>Apellido:</b>\n<code>"
        texto << apellidos_usuario(id_usuario)
                 .to_a
                 .last(2)
                 .map(&:first)
                 .map { |s| s.empty? ? 'Ø' : html_parser(s) }
                 .join(' ➜ ')
        texto << '</code>'
    end

    def texto_cambio_username_usuario(id_usuario)
        texto = "\n<b>Alias:</b>\n<code>"
        texto << usernames_usuario(id_usuario)
                 .to_a
                 .last(2)
                 .map(&:first)
                 .map { |s| s.empty? ? 'Ø' : html_parser(s) }
                 .join(' ➜ ')
        texto << '</code>'
    end
end
