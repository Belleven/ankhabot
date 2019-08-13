class Dankie
    add_handler Handler::Comando.new(:estatus, :estatus,
                                     descripción: 'Devuelve el estatus de un miembro del grupo')
    add_handler Handler::Comando.new(:permisos, :permisos,
                                     descripción: 'Devuelve los permisos de los miembros comunes del grupete')

    def estatus(msj)
        if (miembro = miembro_válido(msj))

            traducción = { 'member' => 'MIEMBRO COMÚN', 'kicked' => 'BANEADO',
                           'left' => 'FUERA DEL GRUPO (PUEDE VOLVER CUANDO QUEIRA)',
                           'creator ' => 'CREADOR DEL GRUPETE', 'administrator' => 'ADMINISTRADOR',
                           'restricted' => 'USUARIO RESTRINGIDO' }

            estado = miembro.user.first_name.empty? ? 'desaparecido' : traducción[miembro.status]

            texto = "Estatus de #{crear_enlace(miembro.user)}: #{estado}"

            agregar_cualidades(miembro, texto) unless miembro.user.first_name.empty?
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
                    "#{grupo_del_msj(msj)}"

            agregar_permisos(msj, texto)

            @tg.send_message(chat_id: msj.chat.id, text: texto)
        end
    end

    private

    def miembro_válido(msj)
        miembro = nil

        if validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)

            id_usuario, alias_usuario, otro_texto = id_y_resto(msj)
            miembro = obtener_miembro(msj, id_usuario)

            if alias_usuario && (!miembro.user.username || miembro.user.username != alias_usuario)
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
                         "\n- Puede editar sus privilegios de administrador"
                     else
                         "\n- No puede editar sus privilegios de administrador"
                        end

            texto << if miembro.can_delete_messages
                         "\n- Puede borrar los mensajes de otros usuarios"
                     else
                         "\n- No puede borrar los mensajes de otros usuarios"
                        end

            texto << if miembro.can_restrict_members
                         "\n- Puede banear, desbanear o restringir usuarios"
                     else
                         "\n- No puede banear, desbanear o restringir usuarios"
                        end

            texto << if miembro.can_promote_members
                         "\n- Puede agregar nuevos administradores "\
                                     '(con sus mismos privilegios)'
                     else
                         "\n- No puede agregar nuevos administradores"
                        end

        elsif miembro.status == 'restricted'
            texto << "\n\nCon las siguientes restricciones:"
            cualidades_ban_restr(miembro, texto, 'Restringido')
            cualidades_admin_restr(miembro, texto)

            texto << if miembro.is_member
                         "\n- Es miembro actual del grupete"
                     else
                         "\n- No miembro actual del grupete"
                        end

            texto << if miembro.can_send_messages
                         "\n- Puede mandar mensajes de texto, contactos, ubicaciones"
                     else
                         "\n- No puede mandar mensajes de texto, contactos, ubicaciones"
                        end

            texto << if miembro.can_send_media_messages
                         "\n- Puede mandar audios, documentos, imágenes, videos, "\
                                     'notas de video o notas de audio'
                     else
                         "\n- No puede mandar audios, documentos, imágenes, videos, "\
                                     'notas de video o notas de audio'
                        end

            texto << if miembro.can_send_polls
                         "\n- Puede mandar encuestas"
                     else
                         "\n- No puede mandar encuestas"
                        end

            texto << if miembro.can_send_other_messages
                         "\n- Puede mandar GIFS, juegos, stickers y usar bots inline"
                     else
                         "\n- No puede mandar GIFS, juegos, stickers y usar bots inline"
                        end

            texto << if miembro.can_add_web_page_previews
                         "\n- Puede agregar miniaturas de páginas de internet en sus mensajes"
                     else
                         "\n- No puede agregar miniaturas de páginas de internet en sus mensajes"
                         end

        elsif miembro.status == 'kicked'
            cualidades_ban_restr(miembro, texto, 'Baneado')
        end
    end

    def cualidades_admin_restr(miembro, texto)
        texto << if miembro.can_change_info
                     "\n- Puede cambiar el título, descripción y otras cosas"
                 else
                     "\n- No puede cambiar el título, descripción u otras cosas"
                 end

        texto << if miembro.can_invite_users
                     "\n- Puede invitar nuevos usuarios al chat"
                 else
                     "\n- No puede invitar nuevos usuarios al chat"
                 end

        texto << if miembro.can_pin_messages
                     "\n- Puede anclar mensajes en el grupete"
                 else
                     "\n- No puede anclar mensajes en el grupete"
                 end
    end

    def cualidades_ban_restr(miembro, texto, estatus)
        texto << "\n- #{estatus} hasta #{miembro.until_date}"
    end

    def agregar_permisos(chat, texto); end
end
