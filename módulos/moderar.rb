class Dankie
    add_handler Handler::Comando.new(
        :kick,
        :rajar,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :rajar,
        :rajar,
        chats_permitidos: %i[group supergroup],
        descripción: 'Echo al usuario del grupo'
    )

    add_handler Handler::Comando.new(
        :ban,
        :ban,
        chats_permitidos: %i[supergroup]
    )

    add_handler Handler::Comando.new(
        :nisban,
        :ban,
        chats_permitidos: %i[supergroup],
        descripción: 'Baneo al usuario del grupo'
    )

    add_handler Handler::Comando.new(
        :unban,
        :desban,
        chats_permitidos: %i[supergroup]
    )

    add_handler Handler::Comando.new(
        :desbanificar,
        :desban,
        chats_permitidos: %i[supergroup],
        descripción: 'Desbaneo al usuario del grupo'
    )

    # Comando /rajar /kick
    def rajar(msj)
        # https://core.telegram.org/bots/api#unbanchatmember
        if msj.chat.type == 'supergroup'
            aplicar_moderación(
                msj,
                :unban_chat_member,
                'Ni nos vimos',
                { para_aplicar_restricción: true, expulsando: true }
            )
            return
        end

        # Esto es en un grupo, no hay que volver a chequear nada
        # https://core.telegram.org/bots/api#kickchatmember
        aplicar_moderación(
            msj,
            :kick_chat_member,
            'Ni nos vimos',
            { para_aplicar_restricción: true }
        )
    end

    # Comando /ban /nisban
    def ban(msj)
        aplicar_moderación(
            msj,
            :kick_chat_member,
            'Pero mirá el ban que te comiste',
            { para_aplicar_restricción: true }
        )
    end

    # Comando /unban /desbanificar
    def desban(msj)
        aplicar_moderación(
            msj,
            :unban_chat_member,
            'Ya podés meterte de nuevo (o seguir si estabas), pero no te mandes cagadas',
            { para_aplicar_restricción: false, args_api: { only_if_banned: true } }
        )
    end

    private

    # Función que chequea los requisitos y ejecuta finalmente el comando moderador
    def aplicar_moderación(msj, método, msj_final, extra_args)
        resultados = cumple_requisitos(
            msj,
            extra_args[:para_aplicar_restricción],
            extra_args[:expulsando]
        )
        return unless (miembro = resultados[:miembro])

        # miembro puede ser un objeto usuario o un entero que representa una id
        args_moderación = {
            chat_id: msj.chat.id,
            user_id: (miembro.id if miembro.respond_to?(:id)) || miembro
        }
        args_moderación.merge!(extra_args[:args_api] || {})
        return unless llamar_método_api(msj, método, args_moderación)

        razón = resultados[:razón]
        razón = if razón.nil?
                    ''
                else
                    ".\nRazón: #{razón}#{razón[-1] == '.' ? '' : '.'}"
                end

        nombre = obtener_enlace_usuario(miembro, msj.chat.id)
        nombre ||= 'Usuario eliminado'

        texto = "#{msj_final} #{nombre}#{razón}"
        @tg.send_message(
            chat_id: msj.chat.id,
            text: texto,
            parse_mode: :html,
            disable_web_page_preview: true,
            disable_notification: true
        )
    end

    def llamar_método_api(msj, método_moderación, args_moderación)
        @tg.send método_moderación, args_moderación
    rescue Telegram::Bot::Exceptions::ResponseError => e
        manejar_excepciones_moderación(msj, e)
        false
    end

    # Todos los requisitos que hay que cumplir para banear/kickear
    def cumple_requisitos(msj, para_aplicar_restricción, expulsando)
        # Chequeo que esté pasando una id para afectar
        return false unless (valores = dar_id_afectada(msj, para_aplicar_restricción))

        id_afectada = valores[:id]
        return false unless id_afectada

        razón = valores[:razón]
        if razón && razón.length > 233
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "No puedo ejecutar el comando\nRazón: la razón es muy larga.",
                reply_to_message_id: msj.message_id
            )
            false
        else
            # Chequeo que el usuario que llamó al comando sea admin.
            # Además devuelve el chat_member del usuario afectado.
            {
                miembro: chequear_usuarios(msj, id_afectada, valores[:alias],
                                           valores[:usuario], expulsando),
                razón: razón
            }
        end
    end

    # Chequea que se esté respondiendo un mensaje
    def dar_id_afectada(msj, para_aplicar_restricción)
        # Si el mensaje tiene argumentos, reviso si me sirven para identificar
        # al usuario y/o si tiene la razón del baneo/kickeo/etc
        valores = id_y_resto(msj)

        # Si no se pudo obtener id, aviso
        if valores[:id].nil?
            if valores[:alias]
                @tg.send_message(
                    chat_id: msj.chat.id,
                    text: 'No reconozco este alias POR AHORA',
                    reply_to_message_id: msj.message_id
                )
            else
                @tg.send_message(
                    chat_id: msj.chat.id,
                    text: 'Tenés que pasarme un id, alias, mención '\
                          'o responder un mensaje. Podés '\
                          'acompañar el comando con una razón con el '\
                          "siguiente formato ''/comando usuario razón'', "\
                          "o ''/comando razón'' si estás respondiendo a "\
                          'un mensaje.',
                    reply_to_message_id: msj.message_id
                )
            end
            return
        # Al botazo no le pueden afectar los comandos
        elsif para_aplicar_restricción && valores[:id] == @user.id
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Ni se te ocurra',
                reply_to_message_id: msj.message_id
            )
            return
        end

        valores
    end

    def chequear_usuarios(msj, id_afectada, alias_id, usuario, expulsando)
        # Chequeo que quien llame al comando sea admin y
        # tenga permisos para restringir usuarios
        permisos = tiene_permisos(
            msj,
            msj.from.id,
            :can_restrict_members,
            'Tenés que',
            'No tenés permisos para restringir/suspender usuarios'
        )

        return false unless permisos

        # Si estoy expulsando a alguien de un supergrupo, tengo que chequear que sea
        # miembro porque si está baneado, al aplicarle "unban_chat_member", se desbanea
        # Es un hack para ese caso este if de acá abajo, además de eso está "optimizado"
        # para que reuse el resultado de obtener_miembro en caso de que tenga que
        # validar el alias más abajo, así nos ahorramos un pedido a la api
        if expulsando
            return false unless (miembro = obtener_miembro(msj, id_afectada))

            if miembro.status == 'kicked'
                @tg.send_message(
                    chat_id: msj.chat.id,
                    reply_to_message_id: msj.message_id,
                    text: 'No puedo expulsar a alguien que ya banearon uwu'
                )
                return false
            end
        end

        return miembro&.user || usuario || id_afectada unless alias_id

        validar_alias(msj, id_afectada, alias_id, miembro)
    end

    def validar_alias(msj, id_afectada, alias_id, miembro)
        # Acá se pide el chat_member para chequear que el id obtenido por el alias que
        # enviaron (id que se consigue de la base de datos porque telegram no permite
        # conseguir id dado un alias) sea el correcto, ya que puede pasar que alguien
        # cambie su alias y que el bot no se de cuenta porque no le llega ninguna
        # update donde se refleje, y no queremos banear a la persona incorrecta.
        miembro ||= obtener_miembro(msj, id_afectada)
        return miembro.user if miembro&.user&.username == alias_id

        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: msj.message_id,
            text: 'No reconozco ese alias, lo más probable '\
                  'es que haya sido cambiado recientemente'
        )
        false
    end

    def manejar_excepciones_moderación(msj, excepción)
        case (mensaje_error = excepción.message)
        when /user is an administrator of the chat/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "No podés banear admines, #{TROESMAS.sample}"
            )
        when /can't remove chat owner/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Uff pero estás tratando de banear a quien '\
                      "maneja el grupete, #{TROESMAS.sample}"
            )
        when %r{not enough rights to restrict/unrestrict chat member}
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Necesito más permisos para hacer eso'
            )
        when /invalid user_id specified/, /USER_ID_INVALID/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Esa ID es inválida o de alguien que no está en el grupo'
            )
        when /user not found/, /USER_NOT_PARTICIPANT/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No puedo expulsar a alguien que no está en el chat'
            )
        when /can't restrict self/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Ni se te ocurra 2'
            )
        else
            manejar_excepciones_grupo_y_extras(msj, mensaje_error)
        end
    end

    def manejar_excepciones_grupo_y_extras(msj, mensaje_error)
        case mensaje_error
        when /CHAT_ADMIN_REQUIRED/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'O estoy tratando de banear admines o no tengo los '\
                      'permisos suficientes, en cualquier caso no puedo hacer nada'
            )
        else
            @logger.error mensaje_error, al_canal: true
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Hubo un error re turbina, probablemente '\
                        'no pude terminar de ejecutar el comando.',
                reply_to_message_id: msj.message_id
            )
        end
    end
end
