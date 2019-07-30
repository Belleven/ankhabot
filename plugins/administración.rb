class Dankie
    add_handler Handler::Comando.new(:rajar, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:kick, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:ban, :ban,
                                     description: 'Baneo al usuario que me digas')
    add_handler Handler::Comando.new(:nisban, :ban,
                                     description: 'Baneo al usuario que me digas')

    # Comando /rajar /kick
    def rajar(msj)
        chequeo_afectado = proc do |miembro|
            miembro['status'] == 'left' || miembro['status'] == 'kicked' ||
                (miembro['status'] == 'restricted' && !miembro['is_member'])
        end
        error_afectado = 'No voy a echar a alguien que no estaba en el grupo '\
                         'al momento de mandar este comando'

        moderar = proc do |msj, id_afectada|
            usar_kick_member(msj, id_afectada) &&
                usar_unban_member(msj, id_afectada)
        end
        despedida = 'Ni nos vimos'

        aplicar_moderación(msj, chequeo_afectado, error_afectado, moderar, despedida)
    end

    # Comando /ban /nisban
    def ban(msj)
        chequeo_afectado = proc do |miembro|
            miembro['status'] == 'kicked'
        end
        error_afectado = 'No puedo a banear a alguien que ya lo estaba '\
                         'al momento de mandar este comando'

        moderar = proc do |msj, id_afectada|
            usar_kick_member(msj, id_afectada)
        end
        despedida = 'Pero mirá el ban que te comiste'

        aplicar_moderación(msj, chequeo_afectado, error_afectado, moderar, despedida)
    end

    # Función que chequea los requisitos y ejecuta el comando
    def aplicar_moderación(msj, chequeo_afectado, error_afectado, moderar, despedida)
        cumple, miembro = cumple_requisitos(msj)

        if cumple
            id_afectada = msj.reply_to_message.from.id

            if chequeo_afectado.call(miembro)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_afectado,
                                 reply_to_message_id: msj.message_id)
            elsif moderar.call(msj, id_afectada)
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
            tiene_permisos(msj, @user.id, 'Necesito', 'No tengo') &&
            # Chequeo que el usuario que llamó al comando sea admin y que quién se vea afectado no
            # Además devuelve el chat_member del usuario afectado (en caso de que pase las validaciones)
            # Devuelve una tupla (bool, chat_member), no se bien cómo funciona pero acá compara el bool con
            # los anteriores, y además devuelve el chat_member sin romperse.
            chequear_usuarios(msj)
    end

    def tiene_permisos(msj, id_usuario, error_no_admin, error_no_permisos)
        miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: id_usuario)['result']
        permisos = true

        if miembro['status'] != 'creator'
            if miembro['status'] != 'administrator'
                permisos = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_admin + ' ser admin para hacer eso',
                                 reply_to_message_id: msj.message_id)
            elsif !miembro['can_restrict_members']
                permisos = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_permisos + ' permisos para restringir/suspender usuarios',
                                 reply_to_message_id: msj.message_id)
            end
        end
        permisos
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
        elsif tiene_permisos(msj, msj.from.id, 'Tenés que', 'No tenés')

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

    # Parámetros y mensajes de error por si falla kick_chat_member
    def usar_kick_member(msj, id_afectada)
        args = { chat_id: msj.chat.id, user_id: id_afectada }
        error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
    					 'mientras se ejecutaba el comando, y por '\
    					 'ahora no puedo sacar a nadie del grupete'
        error_admin = 'El miembro al que tratás de restringir fue '\
        			  'convertido en admin mientras se ejecutaba este comando '\
        			  'y no puedo hacerle nada'
        funcion = proc do |args|
            @tg.kick_chat_member(args)
        end

        ban_desban_handleado(funcion, args, msj, error_permisos, error_admin)
    end

    # Parámetros y mensajes de error por si falla unban_chat_member
    def usar_unban_member(msj, id_afectada)
        args = { chat_id: msj.chat.id, user_id: id_afectada }
        funcion = proc do |args|
            @tg.unban_chat_member(args)
        end
        ban_desban_handleado(funcion, args, msj)
    end

    # Ejecución de kick/unban con manejo de excepciones
    def ban_desban_handleado(funcion, args, msj, error_permisos = 'error_permisos', error_admin = 'error_admin')
        funcion.call(args)
        true
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when %r{not enough rights to restrict/unrestrict chat member}
            @logger.log(Logger::ERROR, error_permisos + ' en ' + grupo_del_msj(msj))
            @tg.send_message(chat_id: msj.chat.id,
                             text: error_permisos,
                             reply_to_message_id: msj.message_id)
        when /user is an administrator of the chat/
            @logger.log(Logger::ERROR, error_admin + ' en ' + grupo_del_msj(msj))
            @tg.send_message(chat_id: msj.chat.id,
                             text: error_admin,
                             reply_to_message_id: msj.message_id)
        else
            raise
        end
        false
    end
end
