class Dankie
    add_handler Handler::EventoDeChat.new(:última_vez_supergrupo,
                                          tipos: [:migrate_from_chat_id],
                                          chats_permitidos: %i[supergroup])
    add_handler Handler::Mensaje.new(:registrar_tiempo,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::EventoDeChat.new(:registrar_tiempo,
                                          chats_permitidos: %i[group supergroup])

    add_handler Handler::Comando.new(:ultimavista, :última_vista,
                                     permitir_params: true,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Devuelvo el momento en que '\
                                                  'participaron por última vez '\
                                                  'en el chat la cantidad de '\
                                                  'usuarios que me digas')

    def registrar_tiempo(msj)
        # Eso de is_bot es porque los eventos de
        # chat que son de bots SÍ los recibe
        return if msj.from.is_bot

        # Primero reviso si se está yendo alguien
        if msj.left_chat_member
            @redis.hdel("último_mensaje:#{msj.chat.id}",
                        msj.left_chat_member.id.to_s)
            return if msj.from.id == msj.left_chat_member.id
        end

        # Después registro a los nuevos miembros (si hay)
        registrar_nuevos_miembros(msj)

        # Por último registro a quien mandó el mensaje
        # podría ser que alguien se una al grupete solo
        # y ahí ya se registra dos veces (una acá y otra en el
        # bucle anterior) pero no importa, no es demasiado.
        @redis.hset("último_mensaje:#{msj.chat.id}",
                    msj.from.id.to_s,
                    msj.date.to_s)
    end

    # Cuando un grupo cambia a supergrupo
    def última_vez_supergrupo(msj)
        # Esta función está definida en dankie.rb
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'último_mensaje:')
    end

    def última_vista(msj, params)
        últimas_vistas = conseguir_últimas_vistas(msj, params)

        # Título
        título_lista = "Estos no se pasan por acá hace rato:\n"

        if últimas_vistas.nil? || últimas_vistas.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No tengo el último mensaje de nadie :c')
            return
        end
        # Llamo a la funcionaza
        arr = []
        arreglo_tablero(
            conjunto_iterable: últimas_vistas,
            arr: arr,
            título: título_lista,
            subtítulo: nil,
            contador: 0,
            max_cant: 30,
            max_tam: 4096,
            agr_elemento: crear_línea_última_vista(msj)
        )
        # Armo botonera y envío
        opciones = armar_botonera 0, arr.size, msj.from.id
        respuesta = @tg.send_message(chat_id: msj.chat.id,
                                     parse_mode: :html,
                                     reply_markup: opciones,
                                     text: arr.first,
                                     disable_web_page_preview: true,
                                     disable_notification: true)
        return unless respuesta

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']
        armar_lista(msj.chat.id, respuesta.message_id, arr)
    end

    private

    def registrar_nuevos_miembros(msj)
        msj.new_chat_members.each do |usuario|
            next if usuario.is_bot

            @redis.hset(
                "último_mensaje:#{msj.chat.id}",
                usuario.id.to_s,
                msj.date.to_s
            )
        end
    end

    def conseguir_últimas_vistas(msj, params)
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
        últimas_vistas.first(cant_a_mostrar)
    end

    def crear_línea_última_vista(msj)
        # Código para crear línea
        proc do |elemento|
            # Tomo la id del usuario
            id_usuario = elemento.first.to_i
            # Tomo la fecha del último msj
            fecha = Time.at(elemento[1].to_i, in: @tz.utc_offset)
            fecha = fecha.strftime('%d/%m/%Y %T')
            # Armo la línea
            enlace_usuario = obtener_enlace_usuario(id_usuario, msj.chat.id)
            unless enlace_usuario
                @redis.hdel("último_mensaje:#{msj.chat.id}", id_usuario)
            end
            "\n- #{enlace_usuario || 'Usuario eliminado'} (#{fecha})"
        end
    end
end
