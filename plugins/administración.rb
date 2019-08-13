class Dankie
    add_handler Handler::Comando.new(:kick, :rajar)
    add_handler Handler::Comando.new(:rajar, :rajar,
                                     descripción: 'Echa al usuario del grupo')
    add_handler Handler::Comando.new(:ban, :ban)
    add_handler Handler::Comando.new(:nisban, :ban,
                                     descripción: 'Banea al usuario del grupo')
    add_handler Handler::Comando.new(:unban, :desban)
    add_handler Handler::Comando.new(:desbanificar, :desban,
                                     descripción: 'Desbanea al usuario del grupo')
    add_handler Handler::Comando.new(:pin, :anclar, permitir_params: true)
    add_handler Handler::Comando.new(:anclar, :anclar, permitir_params: true,
                                                       descripción: 'Ancla el mensaje al que respondas '\
                                                   'en el grupete (agregar ''tranca'' para '\
                                                   'que no mande notificaciones al hacerlo)')

    # Comando /rajar /kick
    def rajar(msj)
        # Función que uso para chequear que se cumplan condiciones específicas del comando
        chequeo_afectado = proc do |miembro|
            miembro.status == 'left' || miembro.status == 'kicked' ||
                (miembro.status == 'restricted' && !miembro.is_member)
        end
        # Función para moderar el grupete
        func_moderadora = proc do |chat_id, id_afectada|
            # Por alguna razón misteriosa la función unban_chat_member kickea
            @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No voy a echar a alguien que no estaba en el grupo '\
                         'al momento de mandar este comando'
        msj_final = 'Ni nos vimos'

        para_aplicar_restriccion = true

        aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restriccion)
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

        para_aplicar_restriccion = true

        aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restriccion)
    end

    def desban(msj)
        chequeo_afectado = proc do |miembro|
            miembro.status != 'kicked'
        end
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No puedo desbanear a alguien que no está baneado'
        msj_final = 'Ya podés meterte de nuevo, pero no vuelvas a hacer cagadas'
        # Acá el afectado claramente no va a ser un admin
        para_aplicar_restriccion = false

        aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restriccion)
    end

    def anclar(msj, params)
        notificar = false

        if params
            if params.length == 6 && params.downcase == 'tranca'
                notificar = true
            else
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'Si querés que nadie sea notificado '\
                                 "entonces acompañá el comando con ''tranca'', "\
                                 'si no, no acompañes el comando con nada',
                                 reply_to_message_id: msj.message_id)
                return
            end
        end

        if cumple_requisitos_pin(msj)
            @tg.pin_chat_message(chat_id: msj.chat.id,
                                 message_id: msj.reply_to_message.message_id,
                                 disable_notification: notificar)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to pin a message/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo anclar/desanclar mensajes'
            log_y_aviso(msj, error_permisos)
        when /CHAT_NOT_MODIFIED/
            error_permisos = 'Estás tratando de hacer que ancle un mensaje que '\
                             "ya está anclado #{TROESMAS.sample}"
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /message to pin not found/
            error_permisos = "No puedo anclar eso #{TROESMAS.sample}, "\
                             'no encontré el mensaje'
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
     end
    end

    private

    # Función que chequea los requisitos y ejecuta finalmente el comando moderador
    def aplicar_moderación(msj, chequeo_afectado, func_moderadora,
                           error_afectado, msj_final, para_aplicar_restriccion)
        cumple, miembro, razón = cumple_requisitos(msj, para_aplicar_restriccion)

        if cumple
            if chequeo_afectado.call(miembro)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_afectado,
                                 reply_to_message_id: msj.message_id)
            elsif moderar(msj, miembro.user.id, func_moderadora)
                razón = razón.nil? ? '' : ".\nRazón: " + razón + (razón[-1] == '.' ? '' : '.')
                @tg.send_message(chat_id: msj.chat.id,
                                 text: msj_final + ' ' + crear_enlace(miembro.user) + razón,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    # Todos los requisitos que hay que cumplir para banear/kickear
    def cumple_requisitos(msj, para_aplicar_restriccion)
        # Siempre que alguna de estas sea falsa, va a mandar un mensaje de error
        cumple = false
        miembro = nil
        razón = nil

        # Chequeo que sea en un grupo (implementada en Dankie.rb)
        if validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)
            # Chequeo que esté pasando una id para afectar
            id_afectada, razón, alias_id = dar_id_afectada(msj, para_aplicar_restriccion)

            if id_afectada && razón && razón.length > 233
                @tg.send_message(chat_id: msj.chat.id,
                                 text: "No puedo ejecutar el comando\n"\
                                 'Razón: la razón es muy larga.',
                                 reply_to_message_id: msj.message_id)
            elsif !id_afectada.nil? &&
                  # Chequeo que el bot sea admin en ese grupo y tenga los permisos correspondientes
                  # 'Necesito' y 'No tengo' son para los mensajes de error
                  tiene_permisos(msj, @user.id, :can_restrict_members, 'Necesito',
                                 'No tengo permisos para restringir/suspender usuarios')

                # Chequeo que el usuario que llamó al comando sea admin y que quién se vea afectado no
                # Además devuelve el chat_member del usuario afectado.
                cumple, miembro = chequear_usuarios(msj, id_afectada, alias_id, para_aplicar_restriccion)
            end
        end
        [cumple, miembro, razón]
    end

    # Chequea que el miembro sea admin y tenga los permisos adecuados
    def tiene_permisos(msj, id_usuario, permiso, error_no_admin, error_no_permisos)
        miembro = obtener_miembro(msj, id_usuario)
        tiene_autorización = true

        if !miembro
            tiene_autorización = false
        elsif miembro.status != 'creator'
            if miembro.status != 'administrator'
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_admin + ' ser admin para hacer eso',
                                 reply_to_message_id: msj.message_id)
            # Chequeo si tiene el permiso
            elsif !(miembro.send permiso)
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_permisos,
                                 reply_to_message_id: msj.message_id)
            end
        end
        tiene_autorización
    end

    # Chequea que se esté respondiendo un mensaje
    def dar_id_afectada(msj, para_aplicar_restriccion)
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
                                 text: 'Si no me decís contra quién usar esto '\
                                    'no puedo hacer nada papurri. Tenés que pasarme '\
                                    'SOLO UN miembro al que quieras que afecte: dame '\
                                    'su id, alias (mención si no tiene alias) '\
                                    'o respondé un mensaje suyo. También podés acompañar '\
                                    'el comando con una razón (de hasta 233 caracteres) de '\
                                    'por qué estás usando esto, '\
                                    "con el siguiente formato ''/comando usuario razón'', "\
                                    "o ''/comando razón'' si estás respondiendo a un mensaje "\
                                    '(notar que si en este caso la razón empieza con un usuario, '\
                                    'entonces el comando lo va a afectar a él). Si ponés varios '\
                                    'usuarios, solo va a afectar al primero.',
                                 reply_to_message_id: msj.message_id)
            end
        # Al botazo no le pueden afectar los comandos
        elsif para_aplicar_restriccion && id_afectada == @user.id
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Ni se te ocurra',
                             reply_to_message_id: msj.message_id)
            id_afectada = nil
        end

        [id_afectada, razón, alias_id]
    end

    def chequear_usuarios(msj, id_afectada, alias_id, para_aplicar_restriccion)
        resultado = false
        miembro = nil

        # Chequeo que quien llame al comando sea admin y tenga permisos para restringir usuarios
        if tiene_permisos(msj, msj.from.id, :can_restrict_members, 'Tenés que',
                          'No tenés permisos para restringir/suspender usuarios')

            miembro = obtener_miembro(msj, id_afectada)

            if miembro
                # Chequeo si a quien le afecta el comando es admin
                if para_aplicar_restriccion && (miembro.status == 'administrator' || miembro.status == 'creator')
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

    def log_y_aviso(msj, error, al_canal: true)
        @logger.log(Logger::ERROR, error + ' en ' + grupo_del_msj(msj), al_canal: al_canal)
        @tg.send_message(chat_id: msj.chat.id,
                         text: error,
                         reply_to_message_id: msj.message_id)
    end

    def cumple_requisitos_pin(msj)
        validar_grupo(msj.chat.type, msj.chat.id, msj.message_id) &&
            resp_msj_válido(msj) &&
            tiene_permisos(msj, @user.id, :can_pin_messages,
                           'Necesito', 'No tengo permisos para pinear mensajes') &&
            tiene_permisos(msj, msj.from.id,
                           :can_pin_messages, 'Tenés que',
                           'No tenés permisos para pinear mensajes')
    end

    def resp_msj_válido(msj)
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que responderle al mensaje '\
                                     'que querés que ancle',
                             reply_to_message_id: msj.message_id)
            return false
        end

        chat = @tg.get_chat(chat_id: msj.chat.id)
        chat = Telegram::Bot::Types::Chat.new(chat)
        if chat.pinned_message &&
           chat.pinned_message.message_id == msj.reply_to_message.message_id

            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Estás tratando de hacer que ancle un mensaje que '\
                                     "ya está anclado #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
            return false
        else
            return true
       end
    end
end
