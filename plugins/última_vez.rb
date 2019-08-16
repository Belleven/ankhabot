class Dankie
    add_handler Handler::EventoDeChat.new(:última_vez_supergrupo,
                                          tipos: [:migrate_from_chat_id])
    add_handler Handler::Mensaje.new(:registrar_tiempo)
    add_handler Handler::EventoDeChat.new(:registrar_tiempo)

    add_handler Handler::Comando.new(:ultimavista, :última_vista, permitir_params: true,
                                                                  descripción: 'Hace ping')

    def registrar_tiempo(msj)
        # Eso de is_bot es porque los eventos de
        # chat que son de bots SÍ los recibe
        if (msj.chat.type == 'supergroup' || msj.chat.type == 'group') &&
           !msj.from.is_bot

            # Primero reviso si se está yendo alguien
            if msj.left_chat_member
                @redis.hdel("último_mensaje:#{msj.chat.id}",
                            msj.left_chat_member.id.to_s)
                return if msj.from.id == msj.left_chat_member.id
            end

            # Después registro a los nuevos miembros (si hay)
            msj.new_chat_members.each do |usuario|
                next if usuario.is_bot

                @redis.hset("último_mensaje:#{msj.chat.id}",
                            usuario.id.to_s,
                            msj.date.to_s)
            end

            # Por último registro a quien mandó el mensaje
            # podría ser que alguien se una al grupete solo
            # y ahí ya se registra dos veces (una acá y otra en el
            # bucle anterior) pero no importa, no es demasiado.
            @redis.hset("último_mensaje:#{msj.chat.id}",
                        msj.from.id.to_s,
                        msj.date.to_s)
        end
    end

    # Cuando un grupo cambia a supergrupo
    def última_vez_supergrupo(msj)
        # Esta función está definida en dankie.rb
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'último_mensaje:')
    end

    def última_vista(msj, params)
        # Agarro el hash
        últimas_vistas = @redis.hgetall("último_mensaje:#{msj.chat.id}")

        # Si está vacío aviso
        if últimas_vistas.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             reply_to_message_id: msj.message_id,
                             text: 'No tengo el último mensaje de nadie :c')
            return
        end

        # Ordeno el hash por valor devolviendo un arreglo <clave, valor>
        últimas_vistas = últimas_vistas.sort_by { |_clave, valor| valor }

        # Si me pasan la cantidad por parámetro entonces la guardo, si no
        # la seteo en 10
        cant_a_mostrar = if params && (cantidad_parámetro = natural(params.split.first))
                             cantidad_parámetro
                         else
                             10
                         end

        # Veo si esa cantidad es mayor a la cantidad de usuarios
        cant_a_mostrar = últimas_vistas.length if últimas_vistas.length < cant_a_mostrar

        texto = "Estos no se pasan por acá hace rato:\n"
        # Itero sobre la cantidad de usuarios que me dijeron
        (0..(cant_a_mostrar - 1)).each do |índice|
            id_usuario = últimas_vistas[índice].first.to_i
            fecha = Time.at(últimas_vistas[índice][1].to_i, in: @tz.utc_offset)
            fecha = fecha.strftime('%d/%m/%Y %T')

            línea = "\n- #{obtener_enlace_usuario(msj.chat.id, id_usuario)} (#{fecha})"

            if texto.length + línea.length > 4096
                @tg.send_message(chat_id: chat_id,
                                 parse_mode: :html,
                                 text: texto,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
                texto = línea
            else
                texto << línea
            end
        end

        unless texto.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             disable_web_page_preview: true,
                             disable_notification: true)
        end
    end
end
