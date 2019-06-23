class Dankie
    add_handler CommandHandler.new(:apodar, :dar_apodo,
                                   description: 'Te cambio el apodo al que me digas (si sos admin, podés cambiárselo a otros)')
    add_handler CommandHandler.new(:borrarapodo, :borrar_apodo,
                                   description: 'Te borra el apodo (si sos admin, podés borrar el de cualquiera)')
    add_handler CommandHandler.new(:vos, :obtener_info,
                                   description: 'Devuelve tu información (o la del usuario al que le respondas)')
    add_handler CommandHandler.new(:apodos, :apodos,
                                   description: 'Te doy los apodos de un grupete')

    def dar_apodo(msj)
        chat_id = msj.chat.id

        return unless validar_grupo(msj.chat.type, chat_id, msj.message_id)

        nuevo_apodo = get_command_params(msj)

        if nuevo_apodo.nil? || nuevo_apodo.empty?
            texto_error = "Si no me pasás un apodo, está jodida la cosa #{TROESMAS.sample}"
            @tg.send_message(chat_id: chat_id, reply_to_message: msj.message_id, text: texto_error)
            return
        elsif nuevo_apodo.length > 100
            texto_error = "Un poquito largo el apodo, no te parece #{TROESMAS.sample}?"
            @tg.send_message(chat_id: chat_id, reply_to_message: msj.message_id, text: texto_error)
            return
        elsif nuevo_apodo.include? "\n"
            texto_error = "Nada de saltos de línea #{TROESMAS.sample}"
            @tg.send_message(chat_id: chat_id, reply_to_message: msj.message_id, text: texto_error)
            return
        elsif nuevo_apodo.include? '‌'
            texto_error = "Nada de caracteres vacíos #{TROESMAS.sample}"
            @tg.send_message(chat_id: chat_id, reply_to_message: msj.message_id, text: texto_error)
            return
        end

        if es_administrador(msj.from.id, chat_id) && msj.reply_to_message
            id_usuario = msj.reply_to_message.from.id
            nombre = msj.reply_to_message.from.first_name
            apellido = msj.reply_to_message.from.last_name
            responde_a = msj.reply_to_message.message_id
        else
            id_usuario = msj.from.id
            nombre = msj.from.first_name
            apellido = msj.from.last_name
            responde_a = msj.message_id
        end

        # La estructura es un hash de clave "info_usuario:apodo:chat_id",los atributos son las ids de los usuarios
        # y el valor de cada atributo es el apodo correspondiente
        @redis.hset("info_usuario:apodo:#{chat_id}", id_usuario.to_s, nuevo_apodo)
        @redis.bgsave

        texto = "De hoy en adelante, el #{TROESMAS.sample} '#{dame_nombre_completo(nombre, apellido, 'Cuenta eliminada')}' será conocido como '#{html_parser(nuevo_apodo)}'."
        @tg.send_message(chat_id: msj.chat.id, reply_to_message: responde_a, text: texto, parse_mode: 'html')
    end

    def borrar_apodo(msj)
        chat_id = msj.chat.id

        # Si no es un grupo entonces chau
        return unless validar_grupo(msj.chat.type, chat_id, msj.message_id)

        # Veo los datazos de quien sea al que le quieren borrar el apodo
        if es_administrador(msj.from.id, chat_id) && msj.reply_to_message
            id_usuario = msj.reply_to_message.from.id
            texto_error = "No podés borrar un apodo que no existe"
        else
            id_usuario = msj.from.id
            texto_error = "No puedo borrarte el apodo si no tenés ninguno #{TROESMAS.sample}"
        end

        # Si no tenía ningún apodo, entonces aviso
        if @redis.hget("info_usuario:apodo:#{chat_id}", id_usuario.to_s).nil?
            @tg.send_message(chat_id: chat_id, reply_to_message: msj.message_id, text: texto_error)
        else
            # Si sí tenía, entonces lo borro
            @redis.hdel("info_usuario:apodo:#{chat_id}", id_usuario.to_s)
            # Hacer algo con los bgsave en un futuro
            @redis.bgsave
            @tg.send_message(chat_id: chat_id, reply_to_message: msj.message_id, text: 'Apodo recontra borradísimo')
        end
    end

    def obtener_info(msj)
        chat_id = msj.chat.id

        if msj.reply_to_message
            id_usuario = msj.reply_to_message.from.id
            nombre = msj.reply_to_message.from.first_name
            apellido = msj.reply_to_message.from.last_name
            alias_usuario = msj.reply_to_message.from.username
        else
            id_usuario = msj.from.id
            nombre = msj.from.first_name
            apellido = msj.from.last_name
            alias_usuario = msj.from.username
        end

        lastfm = @redis.get("lastfm:#{id_usuario}")
        apodo = @redis.hget("info_usuario:apodo:#{chat_id}", id_usuario.to_s)

        respuesta = "Nombre de usuario: <b>#{dame_nombre_completo(nombre, apellido, 'ay no c')}</b>\n"
        respuesta << (alias_usuario.nil? ? '' : "Alias: <b>#{alias_usuario}</b>\n")
        respuesta << "Id de usuario: <b>#{id_usuario}</b>\n"
        respuesta << (apodo.nil? ? '' : "Apodo en el grupete: <b>#{html_parser(apodo)}</b>\n")
        respuesta << (lastfm.nil? ? '' : "Cuenta de LastFM: <b>#{html_parser(lastfm)}</b>")

        @tg.send_message(chat_id: msj.chat.id, reply_to_message: msj.message_id, parse_mode: 'html', text: respuesta)
    end

    def apodos(msj)
        # Chequeo que sea en un grupo
        chat_id = msj.chat.id
        return unless validar_grupo(msj.chat.type, chat_id, msj.message_id)

        # Chequeo que haya apodos
        apodos = @redis.hgetall("info_usuario:apodo:#{chat_id}")

        if apodos.nil? || apodos.empty?
            @tg.send_message(chat_id: chat_id, text: 'No hay nadie apodado en el grupete')
            return
        end

        texto = "Apodos del grupete #{html_parser(msj.chat.title)}\n\n"
        apodos.each do |apodo|
            # Armo la línea
            línea = "- <a href='tg://user?id=#{apodo[0]}'> #{html_parser(apodo[1])}</a>\n"
            if texto.length + línea.length > 4096
                @tg.send_message(chat_id: chat_id, parse_mode: 'html', text: texto, disable_notification: true)
                texto = línea
            else
                texto << línea
            end
        end

        # Si me quedó algo por mandar lo hago
        unless texto.empty?
            @tg.send_message(chat_id: chat_id, parse_mode: 'html', text: texto, disable_notification: true)
        end
    end
end

def dame_nombre_completo(nombre, apellido, nombre_suplente)
    if nombre.empty?
        nombre_suplente
    else
        html_parser(nombre + (apellido ? " #{apellido}" : ''))
    end
end

def es_administrador(id_usuario, chat_id)
    # Robada de Blacklist. En algún momento las sacaré a un utils
    member = @tg.get_chat_member(chat_id: chat_id, user_id: id_usuario)
    member = Telegram::Bot::Types::ChatMember.new(member['result'])
    status = member.status

    # Chequeo que quien llama al comando sea admin del grupete
    (status == 'administrator') || (status == 'creator')
end
