class Dankie
    add_handler Handler::EventoDeChat.new(:última_vez_supergrupo,
                                          tipos: [:migrate_from_chat_id])
    add_handler Handler::Mensaje.new(:registrar_tiempo,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::EventoDeChat.new(:registrar_tiempo,
                                          chats_permitidos: %i[group supergroup])

    add_handler Handler::Comando.new(:ultimavista, :última_vista, permitir_params: true,
                                                                  descripción: 'Devuelvo el momento en que participaron '\
                                         'por última vez en el chat la '\
                                         'cantidad de usuarios que me digas')

    def registrar_tiempo(msj)
        # Eso de is_bot es porque los eventos de
        # chat que son de bots SÍ los recibe
        unless msj.from.is_bot

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
        return unless validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)

        # Agarro el hash
        últimas_vistas = @redis.hgetall("último_mensaje:#{msj.chat.id}")
        # Ordeno el hash por valor devolviendo un arreglo <clave, valor>
        últimas_vistas = últimas_vistas.sort_by { |_clave, valor| valor }

        # Si me pasan la cantidad por parámetro entonces la guardo, si no
        # la seteo en 10
        cant_a_mostrar = if params && (cantidad_parámetro = natural(params.split.first))
                             cantidad_parámetro
                         else
                             10
                         end

        # Tomo los primeros cant_a_mostrar de últimas_vistas
        últimas_vistas = últimas_vistas.first(cant_a_mostrar)

        # Título
        título_lista = "Estos no se pasan por acá hace rato:\n"
        # Código para crear línea
        crear_línea = proc do |elemento|
            # Tomo la id del usuario
            id_usuario = elemento.first.to_i
            # Tomo la fecha del último msj
            fecha = Time.at(elemento[1].to_i, in: @tz.utc_offset)
            fecha = fecha.strftime('%d/%m/%Y %T')
            # Armo la línea
            "\n- #{obtener_enlace_usuario(msj.chat.id, id_usuario)} (#{fecha})"
        end

        # Error a mandar en caso de que sea un conjunto vacío
        error_vacío = 'No tengo el último mensaje de nadie :c'

        # Llamo a la funcionaza
        enviar_lista(msj, últimas_vistas, título_lista, crear_línea, error_vacío)
    end
end
