class Dankie
    add_handler Handler::EventoDeChat.new(:info_usuario_supergrupo,
                                          tipos: [:migrate_from_chat_id],
                                          chats_permitidos: %i[supergroup])
    add_handler Handler::Comando.new(:apodar, :dar_apodo,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Te cambio el apodo (si sos admin, '\
                                                  'podés cambiárselo a otros)')
    add_handler Handler::Comando.new(:borrarapodo, :borrar_apodo,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Te borro el apodo (si sos admin, '\
                                                  'podés borrar el de cualquiera)')
    add_handler Handler::Comando.new(:vos, :obtener_info,
                                     descripción: 'Devuelvo tu información (o la '\
                                                  'del usuario al que le respondas)')
    add_handler Handler::Comando.new(:apodos, :apodos,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Te doy los apodos del grupete')

    def dar_apodo(msj)
        chat_id = msj.chat.id
        nuevo_apodo = get_command_params(msj)

        if nuevo_apodo.nil? || nuevo_apodo.empty?
            texto_error = 'Si no me pasás un apodo, está jodida la '\
                          "cosa #{TROESMAS.sample}"
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
            return
        elsif nuevo_apodo.length > 100
            texto_error = 'Un poquito largo el apodo, '\
                          "no te parece #{TROESMAS.sample}?"
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
            return
        elsif nuevo_apodo.include? "\n"
            texto_error = "Nada de saltos de línea #{TROESMAS.sample}"
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
            return
        elsif nuevo_apodo.include? '‌'
            texto_error = "Nada de caracteres vacíos #{TROESMAS.sample}"
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
            return
        end

        if es_admin(msj.from.id, chat_id, msj.message_id) && msj.reply_to_message
            id_usuario = msj.reply_to_message.from.id
            nombre = msj.reply_to_message.from.first_name
            apellido = msj.reply_to_message.from.last_name
            responde_a = msj.reply_to_message.message_id
        else
            id_usuario = msj.from.id
            nombre = msj.from.first_name
            apellido = msj.from.last_name
            responde_a = msj.message_id
        end

        # La estructura es un hash de clave "info_usuario:apodo:chat_id",los atributos
        # son las ids de los usuarios y el valor de cada atributo es el apodo
        # correspondiente
        @redis.hset("apodo:#{chat_id}", id_usuario.to_s, nuevo_apodo)

        nombre = dame_nombre_completo(nombre, apellido, 'Cuenta eliminada')
        texto = "De hoy en adelante, el #{TROESMAS.sample} "\
                "'#{nombre}' será conocido como '#{html_parser(nuevo_apodo)}'."

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: responde_a,
                         text: texto,
                         parse_mode: :html)
        @logger.info("Se cambió el apodo de #{nombre} (#{id_usuario}) a "\
                     "#{nuevo_apodo} en #{grupo_del_msj(msj)} (#{chat_id})")
    end

    def borrar_apodo(msj)
        chat_id = msj.chat.id

        # Veo los datazos de quien sea al que le quieren borrar el apodo
        if es_admin(msj.from.id, chat_id, msj.message_id) && msj.reply_to_message
            id_usuario = msj.reply_to_message.from.id
            texto_error = 'No podés borrar un apodo que no existe.'
        else
            id_usuario = msj.from.id
            texto_error = 'No puedo borrarte el apodo si no tenés '\
                          "ninguno, #{TROESMAS.sample}."
        end

        # Si no tenía ningún apodo, entonces aviso
        if @redis.hget("apodo:#{chat_id}", id_usuario.to_s).nil?
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
        else
            # Si sí tenía, entonces lo borro
            @redis.hdel("apodo:#{chat_id}", id_usuario.to_s)
            # Hacer algo con los bgsave en un futuro
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: 'Apodo recontra borradísimo')

            nombre = dame_nombre_completo(msj.from.first_name,
                                          msj.from.last_name,
                                          'Cuenta eliminada')
            @logger.info("Se borró el apodo de #{nombre} (#{id_usuario}) "\
                                  "en #{grupo_del_msj(msj)} (#{chat_id})")
        end
    end

    def obtener_info(msj)
        chat_id = msj.chat.id

        if msj.reply_to_message
            id_usuario = msj.reply_to_message.from.id
            nombre = msj.reply_to_message.from.first_name
            apellido = msj.reply_to_message.from.last_name
            alias_usuario = msj.reply_to_message.from.username
        else
            id_usuario = msj.from.id
            nombre = msj.from.first_name
            apellido = msj.from.last_name
            alias_usuario = msj.from.username
        end

        lastfm = @redis.get("lastfm:#{id_usuario}")
        apodo = @redis.hget("apodo:#{chat_id}", id_usuario.to_s)

        respuesta = 'Nombre de usuario: '\
                    "<b>#{dame_nombre_completo(nombre, apellido, 'ay no c')}</b>\n"

        respuesta << (alias_usuario.nil? ? '' : "Alias: <b>#{alias_usuario}</b>\n")
        respuesta << "Id de usuario: <b>#{id_usuario}</b>\n"
        respuesta << (if apodo.nil?
                          ''
                      else
                          'Apodo en el grupete: '\
                         "<b>#{html_parser(apodo)}</b>\n"
                      end)
        respuesta << (lastfm.nil? ? '' : "Cuenta de LastFM: <b>#{lastfm}</b>")

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         parse_mode: :html,
                         text: respuesta)
    end

    def apodos(msj)
        apodos = @redis.hgetall("apodo:#{msj.chat.id}")

        if apodos.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No hay nadie apodado en el grupete. :c')
            return
        end

        título = "Apodos del grupete #{html_parser(msj.chat.title)}\n"

        arr = [título.dup]
        contador = 0

        apodos.each do |apodo|
            if contador == 13 || arr.last.size >= 500
                arr << título.dup
                contador = 0
            end

            unless (enlace_usuario = obtener_enlace_usuario(apodo.first, msj.chat.id))
                @redis.hdel("apodo:#{msj.chat.id}", apodo.first.to_s)
            end

            arr.last << "\n- #{enlace_usuario || '<i>Usuario eliminado</i>'}"
            contador += 1
        end

        # Armo botonera y envío
        opciones = armar_botonera 0, arr.size, msj.from.id, editable: true

        respuesta = @tg.send_message(chat_id: msj.chat.id, text: arr.first,
                                     reply_markup: opciones, parse_mode: :html,
                                     disable_web_page_preview: true,
                                     disable_notification: true)
        return unless respuesta

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']
        armar_lista(msj.chat.id, respuesta.message_id, arr, 'texto', 'todos')
    end

    def info_usuario_supergrupo(msj)
        # Esta función está definida en dankie.rb
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'apodo:')
    end

    private

    def dame_nombre_completo(nombre, apellido, nombre_suplente)
        if nombre.empty?
            nombre_suplente
        else
            html_parser(nombre + (apellido ? " #{apellido}" : ''))
        end
    end
end
