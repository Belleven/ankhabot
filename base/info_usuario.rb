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
    add_handler Handler::Comando.new(:historial_nombres, :historial_datos_usuario,
                                     chats_permitidos: %i[group supergroup private],
                                     descripción: 'Envío el historial de nombres '\
                                                  'y usernames del usuario')
    add_handler Handler::Comando.new(:purgar_historial_nombres,
                                     :purgar_historial_datos_usuario,
                                     chats_permitidos: %i[group supergroup private],
                                     descripción: 'Elimino tu historial de nombres '\
                                                  'y usernames')

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

        resolver_nuevo_apodo(msj, chat_id, nuevo_apodo)
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
        unless @redis.hget("apodo:#{chat_id}", id_usuario.to_s)
            @tg.send_message(chat_id: chat_id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
            return
        end

        # Si sí tenía, entonces lo borro
        @redis.hdel("apodo:#{chat_id}", id_usuario.to_s)
        # Hacer algo con los bgsave en un futuro
        @tg.send_message(
            chat_id: chat_id,
            reply_to_message_id: msj.message_id,
            text: 'Apodo recontra borradísimo'
        )
    end

    def obtener_info(msj)
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

        responder_info(alias_usuario, id_usuario, msj, nombre, apellido)
    end

    def apodos(msj)
        apodos = @redis.hgetall("apodo:#{msj.chat.id}")

        if apodos.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No hay nadie apodado en el grupete. :c')
            return
        end

        arr = calcular_arreglo_apodos(msj, apodos)

        # Armo botonera y envío
        respuesta = @tg.send_message(
            chat_id: msj.chat.id,
            text: arr.first,
            reply_markup: armar_botonera(0, arr.size, msj.from.id, editable: true),
            parse_mode: :html,
            disable_web_page_preview: true,
            disable_notification: true
        )
        return unless respuesta

        armar_lista(
            msj.chat.id,
            Telegram::Bot::Types::Message.new(respuesta['result']).message_id,
            arr,
            'texto',
            'todos'
        )
    end

    def info_usuario_supergrupo(msj)
        # Esta función está definida en dankie.rb
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'apodo:')
    end

    def historial_datos_usuario(msj)
        id_usuario = msj&.reply_to_message.from.id || msj.from.id

        datos_usuario = crear_arreglo_datos_usuario(id_usuario)

        # TODO: SEGUIR ACÁ: hay que convertir ese arreglo en una tabla bonita
        # y enviarla
    end

    def purgar_historial_datos_usuario(msj)
        redis_eliminar_datos_usuario(msj.from.id)

        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         text: 'Ya eliminé tus nombres y eso nwn')
    end

    private

    def calcular_arreglo_apodos(msj, apodos)
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
        arr
    end

    def responder_info(alias_usuario, id_usuario, msj, nombre, apellido)
        alias_usuario = alias_usuario ? "Alias: <b>#{alias_usuario}</b>\n" : ''

        apodo = @redis.hget("apodo:#{msj.chat.id}", id_usuario.to_s)
        apodo = apodo ? "Apodo en el grupete: <b>#{html_parser(apodo)}</b>\n" : ''

        lastfm = @redis.get("lastfm:#{id_usuario}")
        lastfm = lastfm ? "Cuenta de LastFM: <b>#{lastfm}</b>" : ''

        respuesta = 'Nombre de usuario: '\
                    "<b>#{dame_nombre_completo(nombre, apellido, 'ay no c')}</b>\n"\
                    "Id de usuario: <b>#{id_usuario}</b>\n"\
                    "#{alias_usuario}#{apodo}#{lastfm}"

        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: msj.message_id,
            parse_mode: :html,
            text: respuesta
        )
    end

    def dame_nombre_completo(nombre, apellido, nombre_suplente)
        if nombre.empty?
            nombre_suplente
        else
            html_parser(nombre + (apellido ? " #{apellido}" : ''))
        end
    end

    def resolver_nuevo_apodo(msj, chat_id, nuevo_apodo)
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

        enviar_nuevo_apodo(nombre, apellido, nuevo_apodo, msj, responde_a)
    end

    def enviar_nuevo_apodo(nombre, apellido, nuevo_apodo, msj, responde_a)
        nombre = dame_nombre_completo(nombre, apellido, 'Cuenta eliminada')
        texto = "De hoy en adelante, el #{TROESMAS.sample} "\
                "'#{nombre}' será conocido como '#{html_parser(nuevo_apodo)}'."

        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: responde_a,
            text: texto,
            parse_mode: :html
        )
    end

    def crear_arreglo_datos_usuario(id_usuario)
        # Arreglo de {fecha, nombre, apellido, user}, ordenado por fecha
        datos = []

        nombres_usuario(id_usuario) do |nombre, fecha|
            datos << { fecha: fecha, nombre: nombre, apellido: nil, username: nil }
        end

        apellidos_usuario(id_usuario) do |apellido, fecha|
            if (dato = datos.find { |d| d[:fecha] == fecha })
                dato[:apellido] = apellido
                next
            end

            # Busco el índice de la primer fecha mayor al dato a ingresar
            # e inserto ahí el nuevo dato
            i = datos.index { |d| d[:fecha] > fecha } || datos.size
            datos.insert(i, { fecha: fecha, nombre: nil,
                              apellido: apellido, username: nil })
        end

        usernames_usuario(id_usuario) do |username, fecha|
            if (dato = datos.find { |d| d[:fecha] == fecha })
                dato[:username] = username
                next
            end

            i = datos.index { |d| d[:fecha] > fecha } || datos.size
            datos.insert(i, { fecha: fecha, nombre: nil,
                              apellido: nil, username: username })
        end

        datos
    end
end
