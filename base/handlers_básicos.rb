class Dankie
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')
    add_handler Handler::CallbackQuery.new(:acciones_inferiores_lista, 'opcioneslista')
    add_handler Handler::Mensaje.new(:actualizar_datos_usuarios)

    # Método recursivo que actualiza los nombres de usuarios en redis
    # Necesita ser público por los handlers
    def actualizar_datos_usuarios(msj)
        usuarios = [msj.from, msj.forward_from, msj.left_chat_member]
        (usuarios + msj.new_chat_members).compact.each do |usuario|
            informar_cambio_datos_usuario(usuario.id, msj.chat.id,
                                          redis_actualizar_datos_usuario(usuario))
        end

        actualizar_datos_usuarios(msj.reply_to_message) if msj.reply_to_message
    end

    # Necesita ser público por los handlers
    def chat_inválido(msj, válidos)
        return if msj.chat.type == 'channel'

        traducciones = { 'private' => 'privado', 'group' => 'grupos',
                         'supergroup' => 'supergrupos', 'channel' => 'canales' }

        texto = "Este comando es válido solo en #{traducciones[válidos.first]}"

        case válidos.length
        when 2
            texto << " y #{traducciones[válidos[1]]}"
        when 3
            texto << ", #{traducciones[válidos[1]]} y #{traducciones[válidos[2]]}"
        end

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    private

    def informar_cambio_datos_usuario(id_usuario, id_chat, cambios)
        return if cambios.empty?

        texto = obtener_enlace_usuario(id_usuario, id_chat)
        texto << " cambió su información de usuario:\n"

        texto << texto_cambio_nombre_usuario(id_usuario) if cambios.include? :nombre

        texto << texto_cambio_apellido_usuario(id_usuario) if cambios.include? :apellido

        texto << texto_cambio_username_usuario(id_usuario) if cambios.include? :username

        @tg.send_message(chat_id: id_chat,
                         parse_mode: :html,
                         text: texto,
                         disable_notification: true,
                         disable_web_page_preview: true)
    end

    def texto_cambio_nombre_usuario(id_usuario)
        texto = "\n<b>Nombre:</b>\n<code>"
        texto << nombres_usuario(id_usuario)
                 .to_a
                 .last(2)
                 .map(&:first)
                 .map { |s| html_parser s }
                 .join(' ➜ ')
        texto << '</code>'
    end

    def texto_cambio_apellido_usuario(id_usuario)
        texto = "\n<b>Apellido:</b>\n<code>"
        texto << apellidos_usuario(id_usuario)
                 .to_a
                 .last(2)
                 .map(&:first)
                 .map { |s| s.empty? ? 'Ø' : html_parser(s) }
                 .join(' ➜ ')
        texto << '</code>'
    end

    def texto_cambio_username_usuario(id_usuario)
        texto = "\n<b>Alias:</b>\n<code>"
        texto << usernames_usuario(id_usuario)
                 .to_a
                 .last(2)
                 .map(&:first)
                 .map { |s| s.empty? ? 'Ø' : html_parser(s) }
                 .join(' ➜ ')
        texto << '</code>'
    end
end
