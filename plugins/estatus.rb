class Dankie
    add_handler Handler::Comando.new(:estatus, :estatus,
                                     descripción: 'Devuelvo el estatus de un '\
                                                   'miembro del grupo')
    add_handler Handler::Comando.new(:permisos, :permisos,
                                     descripción: 'Devuelvo los permisos de los '\
                                                   'miembros comunes del grupete')

    def estatus(msj)
        if (miembro = miembro_válido(msj))

            traducción = { 'member' => 'MIEMBRO COMÚN', 'kicked' => 'BANEADO',
                           'left' => 'FUERA DEL GRUPO (PUEDE VOLVER CUANDO QUIERA)',
                           'creator' => 'CREADOR DEL GRUPETE',
                           'administrator' => 'ADMINISTRADOR',
                           'restricted' => 'USUARIO RESTRINGIDO' }

            estado = miembro.user.first_name.empty? ? 'DESAPARECIDO' : traducción[miembro.status]

            texto = "Estatus de #{crear_enlace(miembro.user)}: #{estado}"
            agregar_cualidades(miembro, texto) unless miembro.user.first_name.empty?

            texto << "\n\nPermisos de los miembros comunes en este chat:"
            agregar_permisos_chat(msj, texto)

            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             disable_web_page_preview: true,
                             disable_notification: true,
                             text: texto)

        end
    end

    def permisos(msj)
        if validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)
            texto = 'Permisos de los miembros comunes del grupete '\
                    "#{grupo_del_msj(msj)}:\n"

            agregar_permisos_chat(msj, texto)

            @tg.send_message(chat_id: msj.chat.id, text: texto)
        end
    end

    private

    def miembro_válido(msj)
        miembro = nil

        if validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)

            id_usuario, alias_usuario, otro_texto = id_y_resto(msj)

            if id_usuario.nil?
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'Tenés que responder un mensaje o pasarme '\
                                        'un usuario para que pueda revisar '\
                                        "su estatus, #{TROESMAS.sample}",
                                 reply_to_message_id: msj.message_id)
                return nil
            end

            miembro = obtener_miembro(msj, id_usuario)

            if alias_usuario &&
               (!miembro.user.username || miembro.user.username != alias_usuario)

                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No reconozco ese alias, lo más probable es que '\
                                            'haya sido cambiado recientemente',
                                 reply_to_message_id: msj.message_id)
                return nil
            end
        end
        miembro
    end

    def agregar_cualidades(miembro, texto)
        if miembro.status == 'administrator'
            texto << "\n\nCon las siguientes características:"

            texto << if miembro.can_be_edited
                         "\n✅ Puedo editar sus privilegios de administrador."
                     else
                         "\n❌ No puedo editar sus privilegios de administrador."
                        end

            texto << if miembro.can_delete_messages
                         "\n✅ Puede eliminar mensajes."
                     else
                         "\n❌ No puede eliminar mensajes."
                        end

            texto << if miembro.can_restrict_members
                         "\n✅ Puede suspender usuarios."
                     else
                         "\n❌ No puede suspender usuarios."
                        end

            texto << if miembro.can_promote_members
                         "\n✅ Puede agregar nuevos admins."
                     else
                         "\n❌ No puede agregar nuevos admins."
                        end

        elsif miembro.status == 'restricted'
            texto << "\n\nCon las siguientes restricciones:"
            agr_cualidades_ban_restr(miembro, texto, 'Restringido')
            agr_cualidades_admin_restr(miembro, texto)

            texto << if miembro.is_member
                         "\n✅ Es miembro actual del grupete."
                     else
                         "\n❌ No es miembro actual del grupete."
                        end

            agr_cualidades_generales(miembro, texto)

        elsif miembro.status == 'kicked'
            agr_cualidades_ban_restr(miembro, texto, 'Baneado')
        end
    end

    def agr_cualidades_generales(entidad, texto, miembro_específico: true)
        if miembro_específico
            inicio_pos = 'Puede'
            inicio_neg = 'No puede'
        else
            inicio_pos = 'Pueden'
            inicio_neg = 'No pueden'
        end

        texto << if entidad.can_send_messages
                     "\n✅ #{inicio_pos} mandar mensajes."
                 else
                     "\n❌ #{inicio_neg} mandar mensajes."
                    end

        texto << if entidad.can_send_media_messages
                     "\n✅ #{inicio_pos} mandar multimedia."
                 else
                     "\n❌ #{inicio_neg} mandar multimedia."
                    end

        texto << if entidad.can_send_polls
                     "\n✅ #{inicio_pos} mandar encuestas."
                 else
                     "\n❌ #{inicio_neg} mandar encuestas."
                    end

        texto << if entidad.can_send_other_messages
                     "\n✅ #{inicio_pos} mandar stickers y GIFS."
                 else
                     "\n❌ #{inicio_neg} mandar stickers y GIFS."
                    end

        texto << if entidad.can_add_web_page_previews
                     "\n✅ #{inicio_pos} incrustar enlaces."
                 else
                     "\n❌ #{inicio_neg} incrustar enlaces."
                     end
    end

    def agr_cualidades_admin_restr(entidad, texto, miembro_específico: true)
        if miembro_específico
            inicio_pos = 'Puede'
            inicio_neg = 'No puede'
        else
            inicio_pos = 'Pueden'
            inicio_neg = 'No pueden'
        end

        texto << if entidad.can_change_info
                     "\n✅ #{inicio_pos} cambiar info. del grupo."
                 else
                     "\n❌ #{inicio_neg} cambiar info. del grupo."
                 end

        texto << if entidad.can_invite_users
                     "\n✅ #{inicio_pos} añadir miembros."
                 else
                     "\n❌ #{inicio_neg} iañadir miembros."
                 end

        texto << if entidad.can_pin_messages
                     "\n✅ #{inicio_pos} anclar mensajes."
                 else
                     "\n❌ #{inicio_neg} anclar mensajes."
                 end
    end

    def agr_cualidades_ban_restr(miembro, texto, estatus)
        texto << if miembro.until_date.zero?
                     "\n- #{estatus} para siempre."
                 else
                     "\n- #{estatus} hasta "\
                          "#{miembro.until_date.strftime('%d/%m/%Y %T')}."
                 end
    end

    def agregar_permisos_chat(msj, texto)
        permisos = obtener_chat(msj.chat.id).permissions
        agr_cualidades_generales(permisos, texto, miembro_específico: false)
        agr_cualidades_admin_restr(permisos, texto, miembro_específico: false)
    end
end
