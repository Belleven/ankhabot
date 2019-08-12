class Dankie
    add_handler Handler::Comando.new(:estatus, :estatus,
                                     descripción: 'Devuelve el estatus de un miembro del grupo')

    def estatus(msj)
        if validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)

            id_usuario, alias_usuario, otro_texto = id_y_resto(msj)
            miembro = obtener_miembro(msj, id_usuario)

            if alias_usuario && (!miembro.user.username || miembro.user.username != alias_usuario)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No reconozco ese alias, lo más probable es que '\
                		     	   		'haya sido cambiado recientemente',
                                 reply_to_message_id: msj.message_id)
            else

                traducción = { 'member' => 'MIEMBRO COMÚN', 'kicked' => 'BANEADO',
                               'left' => 'FUERA DEL GRUPO (PUEDE VOLVER CUANDO QUEIRA)',
                               'creator ' => 'CREADOR DEL GRUPETE', 'administrator' => 'ADMINISTRADOR',
                               'restricted' => 'USUARIO RESTRINGIDO' }

                estado = miembro.user.first_name.empty? ? 'desaparecido' : traducción[miembro.status]

                texto = "Estatus de #{crear_enlace(miembro.user)}: #{estado}"

                if miembro.status == 'administrator' && !miembro.user.first_name.empty?
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

                elsif miembro.status == 'restricted' && !miembro.user.first_name.empty?
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

                    # Por alguna razón dice que can_send_polls no existe
                    # texto << if miembro.can_send_polls
                    #             "\n- Puede mandar encuestas"
                    #         else
                    #             "\n- No puede mandar encuestas"
                    #            end

                    texto << if miembro.can_send_other_messages
                                 "\n- Puede mandar GIFS, juegos, stickers y usar bots inline"
                             else
                                 "\n- No puede mandar GIFS, juegos, stickers y usar bots inline"
                                end

                    if miembro.can_add_web_page_previews
                        texto << "\n- Puede agregar miniaturas de páginas de internet en sus mensajes"
                    else
                        texto << "\n- No puede agregar miniaturas de páginas de internet en sus mensajes"
                       end

                elsif miembro.status == 'kicked' && !miembro.user.first_name.empty?
                    cualidades_ban_restr(miembro, texto, 'Baneado')
                end

                @tg.send_message(chat_id: msj.chat.id,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true,
                                 text: texto)

            end
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
    end

    def cualidades_ban_restr(miembro, texto, estatus)
        texto << "\n- #{estatus} hasta #{miembro.until_date}"
    end
end
