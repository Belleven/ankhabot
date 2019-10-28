class Dankie
    add_handler Handler::Comando.new(:kick, :rajar,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:rajar, :rajar,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Echo al usuario del grupo')
    add_handler Handler::Comando.new(:ban, :ban,
                                     chats_permitidos: %i[supergroup])
    add_handler Handler::Comando.new(:nisban, :ban,
                                     chats_permitidos: %i[supergroup],
                                     descripción: 'Baneo al usuario del grupo')
    add_handler Handler::Comando.new(:unban, :desban,
                                     chats_permitidos: %i[supergroup])
    add_handler Handler::Comando.new(:desbanificar, :desban,
                                     chats_permitidos: %i[supergroup],
                                     descripción: 'Desbaneo al usuario del grupo')

    # Comando /rajar /kick
    def rajar(msj)
        # Función que uso para chequear que se cumplan condiciones
        # específicas del comando
        chequeo_afectado = proc do |miembro|
            miembro.status == 'left' || miembro.status == 'kicked' ||
                (miembro.status == 'restricted' && !miembro.is_member)
        end
        # Función para moderar el grupete
        if msj.chat.type == 'supergroup'
            func_moderadora = proc do |chat_id, id_afectada|
                # Por alguna razón misteriosa la función unban_chat_member
                # kickea en supergrupos
                @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
            end
        elsif msj.chat.type == 'group'
            func_moderadora = proc do |chat_id, id_afectada|
                # Por alguna razón misteriosa esta función solo kickea
                # en grupos normales
                @tg.kick_chat_member(chat_id: chat_id, user_id: id_afectada)
            end
        end

        error_afectado = 'No voy a echar a alguien que no estaba en el grupo '\
                         'al momento de mandar este comando'
        msj_final = 'Ni nos vimos'

        para_aplicar_restricción = true

        aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restricción)
    end

    # Comando /ban /nisban
    def ban(msj)
        chequeo_afectado = proc do |miembro|
            miembro.status == 'kicked'
        end
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.kick_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No puedo a banear a alguien que ya lo estaba '\
                         'al momento de mandar este comando'
        msj_final = 'Pero mirá el ban que te comiste'

        para_aplicar_restricción = true

        aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restricción)
    end

    # Comando /unban /desbanificar
    def desban(msj)
        chequeo_afectado = proc do |miembro|
            miembro.status != 'kicked'
        end
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No puedo desbanear a alguien que no está baneado'
        msj_final = 'Ya podés meterte de nuevo, pero no vuelvas a mandarte cagadas'
        # Acá el afectado claramente no va a ser un admin
        para_aplicar_restricción = false

        aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restricción)
    end

    private

    # Función que chequea los requisitos y ejecuta finalmente el comando moderador
    def aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restricción)
        cumple, miembro, razón = cumple_requisitos(msj, para_aplicar_restricción)

        if cumple
            if chequeo_afectado.call(miembro)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_afectado,
                                 reply_to_message_id: msj.message_id)
            elsif moderar(msj, miembro.user.id, func_moderadora)
                razón = razón.nil? ? '' : ".\nRazón: " + razón + (razón[-1] == '.' ? '' : '.')
                nombre = obtener_enlace_usuario(miembro.user, msj.chat.id)

                texto = msj_final + ' ' + nombre + razón
                @tg.send_message(chat_id: msj.chat.id,
                                 text: texto,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    # Todos los requisitos que hay que cumplir para banear/kickear
    def cumple_requisitos(msj, para_aplicar_restricción)
        # Siempre que alguna de estas sea falsa, va a mandar un mensaje de error
        cumple = false
        miembro = nil

        # Chequeo que esté pasando una id para afectar
        id_afectada, razón, alias_id = dar_id_afectada(msj, para_aplicar_restricción)

        if id_afectada && razón && razón.length > 233
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No puedo ejecutar el comando\n"\
                                'Razón: la razón es muy larga.',
                             reply_to_message_id: msj.message_id)
        elsif !id_afectada.nil? &&
              # Chequeo que el bot sea admin en ese grupo y tenga los permisos
              # correspondientes 'Necesito' y 'No tengo' son para los mensajes de error
              tiene_permisos(msj, @user.id, :can_restrict_members, 'Necesito',
                             'No tengo permisos para restringir/suspender usuarios')

            # Chequeo que el usuario que llamó al comando sea admin y que quién se vea
            # afectado no. Además devuelve el chat_member del usuario afectado.
            cumple, miembro = chequear_usuarios(msj, id_afectada, alias_id,
                                                para_aplicar_restricción)
        end
        [cumple, miembro, razón]
    end

    # Chequea que se esté respondiendo un mensaje
    def dar_id_afectada(msj, para_aplicar_restricción)
        # Si el mensaje tiene argumentos, reviso si me sirven para identificar
        # al usuario y/o si tiene la razón del baneo/kickeo/etc
        id_afectada, alias_id, razón = id_y_resto(msj)

        # Si no se pudo obtener id, aviso
        if id_afectada.nil?
            if alias_id
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No reconozco este alias POR AHORA',
                                 reply_to_message_id: msj.message_id)
            else
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'Tenés que pasarme un id, alias, mención si no '\
                                       'tiene alias, o responder un mensaje. Podés '\
                                       'acompañar el comando con una razón con el '\
                                       "siguiente formato ''/comando usuario razón'', "\
                                       "o ''/comando razón'' si estás respondiendo a "\
                                       'un mensaje.',
                                 reply_to_message_id: msj.message_id)
            end
        # Al botazo no le pueden afectar los comandos
        elsif para_aplicar_restricción && id_afectada == @user.id
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Ni se te ocurra',
                             reply_to_message_id: msj.message_id)
            id_afectada = nil
        end

        [id_afectada, razón, alias_id]
    end

    def chequear_usuarios(msj, id_afectada, alias_id, para_aplicar_restricción)
        resultado = false
        miembro = nil

        # Chequeo que quien llame al comando sea admin y tenga permisos para restringir usuarios
        if tiene_permisos(msj, msj.from.id, :can_restrict_members, 'Tenés que',
                          'No tenés permisos para restringir/suspender usuarios')

            miembro = obtener_miembro(msj, id_afectada)

            if miembro
                # Chequeo si a quien le afecta el comando es admin
                if para_aplicar_restricción && (miembro.status == 'administrator' || miembro.status == 'creator')
                    @tg.send_message(chat_id: msj.chat.id,
                                     text: 'No podés usar este comando contra un admin',
                                     reply_to_message_id: msj.message_id)
                elsif alias_id && (!miembro.user.username ||
                        miembro.user.username != alias_id)
                    @tg.send_message(chat_id: msj.chat.id,
                                     text: 'No reconozco ese alias, lo más probable es que '\
                                            'haya sido cambiado recientemente',
                                     reply_to_message_id: msj.message_id)
                else
                    resultado = true
                end
            end
        end

        [resultado, miembro]
    end

    def moderar(msj, id_afectada, función)
        función.call(msj.chat.id, id_afectada)['result']
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
end
