class Dankie
    add_handler Handler::Comando.new(:rajar, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:kick, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:ban, :ban,
                                     description: 'Baneo al usuario que me digas')
    add_handler Handler::Comando.new(:nisban, :ban,
                                     description: 'Baneo al usuario que me digas')
    add_handler Handler::Comando.new(:desban, :desban,
                                     description: 'Baneo al usuario que me digas')

    def desban(msj)
        unless msj.reply_to_message.nil?
            resultado = @tg.get_chat_member(chat_id: msj.chat.id, user_id: msj.reply_to_message.from.id)['result']
            puts "\n\n\n" + resultado.to_s + "\n\n\n"
            resultado = @tg.unban_chat_member(chat_id: msj.chat.id, user_id: msj.reply_to_message.from.id)
            puts "\n\n\n" + resultado.to_s + "\n\n\n"
            resultado = @tg.get_chat_member(chat_id: msj.chat.id, user_id: msj.reply_to_message.from.id)['result']
            puts "\n\n\n" + resultado.to_s + "\n\n\n"
        end
    end

    # Comando /rajar /kick
    def rajar(msj)
        # Función que uso para chequear que se cumplan condiciones específicas del comando
        chequeo_afectado = proc do |miembro|
            miembro['status'] == 'left' || miembro['status'] == 'kicked' ||
                (miembro['status'] == 'restricted' && !miembro['is_member'])
        end
        # Función para moderar el grupete
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No voy a echar a alguien que no estaba en el grupo '\
                         'al momento de mandar este comando'
        despedida = 'Ni nos vimos'

        aplicar_moderación(msj, chequeo_afectado, func_moderadora, error_afectado, despedida)
    end

    # Comando /ban /nisban
    def ban(msj)
        chequeo_afectado = proc do |miembro|
            miembro['status'] == 'kicked'
        end
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.kick_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No puedo a banear a alguien que ya lo estaba '\
                         'al momento de mandar este comando'
        despedida = 'Pero mirá el ban que te comiste'

        aplicar_moderación(msj, chequeo_afectado, func_moderadora, error_afectado, despedida)
    end

    # Función que chequea los requisitos y ejecuta finalmente el comando moderador
    def aplicar_moderación(msj, chequeo_afectado, func_moderadora, error_afectado, despedida)
        cumple, miembro = cumple_requisitos(msj)

        if cumple
            id_afectada = msj.reply_to_message.from.id

            if chequeo_afectado.call(miembro)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_afectado,
                                 reply_to_message_id: msj.message_id)
            elsif moderar(msj, id_afectada, func_moderadora)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: despedida + ' ' + get_username_link(msj.chat.id, id_afectada),
                                 reply_to_message_id: msj.reply_to_message.message_id,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end

        end
    end

    # Todos los requisitos que hay que cumplir para banear/kickear
    def cumple_requisitos(msj)
        # Siempre que alguna de estas sea falsa, va a mandar un mensaje de error

        # Chequeo que sea en un grupo (implementada en Dankie.rb)
        validar_grupo(msj.chat.type, msj.chat.id, msj.message_id) &&
            # Chequeo que esté respondiendo a un mensaje
            esta_respondiendo(msj) &&
            # Chequeo que el bot sea admin en ese grupo y tenga los permisos correspondientes
            # 'Necesito' y 'No tengo' son para los mensajes de error
            tiene_permisos(msj, @user.id, 'can_restrict_members', 'Necesito', 'No tengo') &&
            # Chequeo que el usuario que llamó al comando sea admin y que quién se vea afectado no
            # Además devuelve el chat_member del usuario afectado (en caso de que pase las validaciones)
            # Devuelve una tupla (bool, chat_member), no se bien cómo funciona pero acá compara el bool con
            # los anteriores, y además devuelve el chat_member sin romperse.
            chequear_usuarios(msj)
    end

    # Chequea que el miembro sea admin y tenga los permisos adecuados
    def tiene_permisos(msj, id_usuario, permiso, error_no_admin, error_no_permisos)
        miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: id_usuario)['result']
        tiene_autorización = true

        if miembro['status'] != 'creator'
            if miembro['status'] != 'administrator'
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_admin + ' ser admin para hacer eso',
                                 reply_to_message_id: msj.message_id)
            elsif !miembro[permiso]
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_permisos + ' permisos para restringir/suspender usuarios',
                                 reply_to_message_id: msj.message_id)
            end
        end
        tiene_autorización
    end

    # Chequea que se esté respondiendo un mensaje
    def esta_respondiendo(msj)
        responde = msj.reply_to_message.nil?
        if responde
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que responderle un mensaje a alguien para que este comando funcione',
                             reply_to_message_id: msj.message_id)
        end
        !responde
    end

    def chequear_usuarios(msj)
        resultado = false
        miembro = nil

        # Al botazo no le pueden afectar los comandos
        if msj.reply_to_message.from.id == @user.id
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Ni se te ocurra',
                             reply_to_message_id: msj.message_id)

        # Chequeo que quien llame al comando sea admin y tenga permisos para restringir usuarios
        elsif tiene_permisos(msj, msj.from.id, 'can_restrict_members', 'Tenés que', 'No tenés')

            # Chequeo si a quien le afecta el comando es admin, y de ser necesario, devuelvo el estatus
            miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: msj.reply_to_message.from.id)['result']

            if miembro['status'] == 'administrator' || miembro['status'] == 'creator'
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No podés usar este comando contra un admin',
                                 reply_to_message_id: msj.message_id)
            else
                resultado = true
            end

        end

        [resultado, miembro]
    end

    def moderar(msj, id_afectada, funcion)
        funcion.call(msj.chat.id, id_afectada)['result']
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when %r{not enough rights to restrict/unrestrict chat member}
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                             'mientras se ejecutaba el comando, y por '\
                             'ahora no puedo sacar a nadie del grupete'
            log_y_aviso(msj, error_permisos)
        when /user is an administrator of the chat/
            error_admin = 'El miembro al que tratás de restringir fue '\
                          'convertido en admin mientras se ejecutaba este comando '\
                          'y no puedo hacerle nada'
            log_y_aviso(msj, error_admin)
        else
            raise
        end

        false
    end

    def log_y_aviso(msj, error)
        @logger.log(Logger::ERROR, error + ' en ' + grupo_del_msj(msj))
        @tg.send_message(chat_id: msj.chat.id,
                         text: error,
                         reply_to_message_id: msj.message_id)
    end
end
