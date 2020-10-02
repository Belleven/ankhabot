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
        # Función para moderar el grupete
        case msj.chat.type
        when 'supergroup'
            func_moderadora = proc do |chat_id, id_afectada|
                # Por alguna razón misteriosa la función unban_chat_member
                # kickea en supergrupos
                @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
            end
        when 'group'
            func_moderadora = proc do |chat_id, id_afectada|
                # Por alguna razón misteriosa esta función solo kickea
                # en grupos normales
                @tg.kick_chat_member(chat_id: chat_id, user_id: id_afectada)
            end
        end
        msj_final = 'Ni nos vimos'

        aplicar_moderación(msj, func_moderadora, msj_final, true)
    end

    # Comando /ban /nisban
    def ban(msj)
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.kick_chat_member(chat_id: chat_id, user_id: id_afectada)
        end
        msj_final = 'Pero mirá el ban que te comiste'

        aplicar_moderación(msj, func_moderadora, msj_final, true)
    end

    # Comando /unban /desbanificar
    def desban(msj)
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
        end
        msj_final = 'Ya podés meterte de nuevo, pero no vuelvas a mandarte cagadas'

        aplicar_moderación(msj, func_moderadora, msj_final, false)
    end

    private

    # Función que chequea los requisitos y ejecuta finalmente el comando moderador
    def aplicar_moderación(msj, func_moderadora, msj_final, para_aplicar_restricción)
        return unless (miembro = cumple_requisitos(msj, para_aplicar_restricción))

        if aplicar_moderación(msj, miembro, func_moderadora)
            razón = if razón.nil?
                        ''
                    else
                        ".\nRazón: #{razón}#{(razón[-1] == '.' ? '' : '.')}"
                    end
            nombre = obtener_enlace_usuario(miembro.user, msj.chat.id)
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
    end

    def aplicar_moderación(msj, miembro, func_moderadora)
        func_moderadora.call(msj.chat.id, miembro.user.id)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        manejar_excepciones_moderación(msj, e)
    end

    # Todos los requisitos que hay que cumplir para banear/kickear
    def cumple_requisitos(msj, para_aplicar_restricción)
        # Chequeo que esté pasando una id para afectar
        return unless (valores = dar_id_afectada(msj, para_aplicar_restricción))

        id_afectada = valores[:id]
        razón = valores[:razón]

        return unless id_afectada

        if razón && razón.length > 233
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "No puedo ejecutar el comando\nRazón: la razón es muy larga.",
                reply_to_message_id: msj.message_id
            )
            nil
        else
            # Chequeo que el usuario que llamó al comando sea admin.
            # Además devuelve el chat_member del usuario afectado.
            chequear_usuario(msj, id_afectada, valores[:alias])
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

    def chequear_usuario(msj, id_afectada, alias_id)
        # Chequeo que quien llame al comando sea admin y
        # tenga permisos para restringir usuarios
        permisos = tiene_permisos(
            msj,
            msj.from.id,
            :can_restrict_members,
            'Tenés que',
            'No tenés permisos para restringir/suspender usuarios'
        )

        if permisos && (miembro = obtener_miembro(msj, id_afectada))
            if alias_id &&
               (!miembro.user.username || miembro.user.username != alias_id)

                @tg.send_message(
                    chat_id: msj.chat.id,
                    text: 'No reconozco ese alias, lo más probable '\
                          'es que haya sido cambiado recientemente',
                    reply_to_message_id: msj.message_id
                )
            else
                return miembro
            end
        end
        nil
    end

    def manejar_excepciones_moderación(msj, excepción)
        case excepción.message
        when /user is an administrator of the chat/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "No podés banear a un admin #{TROESMAS.sample}"
            )
            return
        when /can't remove chat owner/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Uff pero estás tratando de banear a quien "\
                      "maneja el grupete #{TROESMAS.sample}"
            )
            return
        end
        
        @logger.error excepción.to_s, al_canal: true
        @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Hubo un error re turbina, probablemente '\
                        'no pude terminar de ejecutar el comando.',
                reply_to_message_id: msj.message_id
        )
    end
end
