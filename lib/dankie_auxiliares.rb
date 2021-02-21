class Dankie
    private

    def html_parser(texto)
        CGI.escapeHTML(texto)
    end

    # Analiza un texto y lo separa en parámetros.
    # Formato: 'opción1: valor1 opción2: lista de valores opción3: 3'
    # Se puede escapar un : con un \ antes ('\:')
    # Devuelve un hash con opción => valor, donde cada opción es un Symbol y valor String
    def parse_params(texto)
        parámetros = {}

        # separo en pares nombre: valores
        texto.split(/\s+(?=\S+[^\\]:)/).each do |param|
            # separo el nombre del valor
            opción = param.split(/(?<!\\):/)
            return opción.first if opción.size == 1

            parámetros[opción[0].strip.to_sym] = opción[1].strip
        end

        parámetros
    end

    # Método que recibe un User o un id_usuario, un Chat o un id_chat y devuelve
    # un enlace al usuario pasado, un texto si hubo un error o nil si el usuario
    # borró su cuenta.
    def obtener_enlace_usuario(usuario, chat, con_apodo: true)
        id_chat = chat.is_a?(Telegram::Bot::Types::Chat) ? chat.id : chat

        if usuario.is_a?(Telegram::Bot::Types::User)
            id_usuario = usuario.id
            alias_usuario = usuario.username
            nombre_usuario = usuario.first_name
        else
            id_usuario = usuario
            alias_usuario = obtener_username_usuario(id_usuario)
            nombre_usuario = nil
        end

        mención = if alias_usuario
                  then "<a href='https://telegram.me/#{alias_usuario}'>"
                  else "<a href='tg://user?id=#{id_usuario}'>"
                  end

        devolver_mención(mención, nombre_usuario, id_chat, id_usuario, con_apodo)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        manejar_excepción_enlace(id_usuario, e)
    end

    def manejar_excepción_enlace(id_usuario, exc)
        mención = "ay no c (#{id_usuario})"
        if exc.to_s =~ /user not found|wrong user_id specified/
            @logger.error('Traté de obtener el nombre de una cuenta '\
                        "eliminada: #{id_usuario}")
            return nil
        else
            @logger.error exc
        end

        mención
    end

    def devolver_mención(mención, nombre_usuario, id_chat, id_usuario, con_apodo)
        if con_apodo && (apodo = @redis.hget("apodo:#{id_chat}", id_usuario))
            mención << "#{html_parser apodo}</a>"
            return mención
        end

        if (nombre = obtener_nombre_usuario(id_usuario) || nombre_usuario)
            mención << "#{html_parser nombre}</a>"
            return mención
        end

        usuario = @tg.get_chat_member(chat_id: id_chat, user_id: id_usuario)
        usuario = Telegram::Bot::Types::ChatMember.new(usuario['result']).user

        redis_actualizar_datos_usuario usuario
        return "ay no c (#{id_usuario})" if usuario.first_name.empty?

        mención << "#{html_parser usuario.first_name}</a>"
        mención
    end

    def natural(número)
        /\A\d*[1-9]\d*\z/.match?(número) ? número.to_i : false
    end

    # Los últimos 2 parámetros son para que esto sea polimórfico con
    # es_admin y chequeo_local (lista_negra.rb)
    def validar_desarrollador(usuario_id, chat_id, mensaje_id, _text = nil, _id = nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(usuario_id)
            @tg.send_message(
                chat_id: chat_id,
                reply_to_message_id: mensaje_id,
                text: 'Gomen ne, este comando es solo para los admins del bot. >///<'
            )
            return false
        end

        true
    end

    def dev_responde_callback(callback)
        unless DEVS.member? callback.from.id
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Solo devs pueden usar esto')
            return false
        end
        true
    end

    # Los últimos 2 parámetros son para que esto sea polimórfico con
    # validar_desarrollador y chequeo_local (lista_negra.rb)
    def es_admin(usuario_id, chat_id, mensaje_id, text = nil, _id = nil)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: usuario_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        # Si no lo es, manda mensaje de error
        if (status != 'administrator') && (status != 'creator')
            unless text.nil?
                @tg.send_message(
                    chat_id: chat_id,
                    reply_to_message_id: mensaje_id,
                    text: text
                )
            end
            return false
        end

        true
    end

    def grupo_del_msj(msj)
        if msj.chat.title.nil?
            msj.chat.id.to_s
        else
            "#{msj.chat.title} (#{msj.chat.id})"
        end
    end

    def cambiar_claves_supergrupo(vieja_id, nueva_id, texto_antes = '',
                                  texto_después = '')
        vieja_clave = texto_antes + vieja_id.to_s + texto_después
        nueva_clave = texto_antes + nueva_id.to_s + texto_después

        @redis.rename(vieja_clave, nueva_clave) if @redis.exists?(vieja_clave)
    end

    def primer_nombre(usuario)
        if usuario.first_name.nil?
            "ay no c (#{usuario.id})"
        else
            usuario.first_name
        end
    end

    # La gente se asustaría si viera lo mugriento que era este método antes
    # de la refactorización que le hice hoy 30/09/2020 d.C.
    def id_y_resto(msj)
        resultado = { id: nil, alias: nil, razón: nil, usuario: nil }

        if (args = obtener_params_comando(msj))
            valores = dame_entidades_texto(msj)
            chequeo_id_y_resto_entidades(args, valores, resultado) if valores
            chequeo_id_numerica_y_resto(args, resultado) unless resultado[:id]
        end

        if resultado[:id].nil? && msj.reply_to_message
            resultado[:id] = msj.reply_to_message.from.id
            resultado[:usuario] = msj.reply_to_message.from
        end

        resultado
    end

    def dame_entidades_texto(msj)
        if msj.entities.length.positive?
            { entidades: msj.entities, texto: msj.text }
        elsif msj.caption_entities.length.positive?
            { entidades: msj.caption_entities, texto: msj.caption }
        end
    end

    def chequeo_id_y_resto_entidades(args, valores, resultado)
        texto = valores[:texto]

        entidad = dame_entidad_afectada(valores[:entidades])
        fin = entidad.offset + entidad.length
        texto_entidad = texto[entidad.offset..(fin - 1)]

        return unless args.start_with? texto_entidad

        resultado[:razón] = texto.length == fin ? nil : texto[fin..]

        case entidad.type
        when 'mention'
            # La entidad arranca con un @, por eso el 1..
            resultado[:alias] = texto_entidad[1..].strip
            resultado[:id] = obtener_id_de_alias(resultado[:alias])&.to_i
        when 'text_mention'
            resultado[:id] = entidad.user.id
            resultado[:usuario] = entidad.user
        end
    end

    def dame_entidad_afectada(entidades)
        if entidades.length >= 2 && entidades.first.type == 'bot_command'
            entidades[1]
        else
            entidades.first
        end
    end

    def chequeo_id_numerica_y_resto(args, resultado)
        lista_palabras = args.split

        if (id_numérica = natural(lista_palabras.first))
            resultado[:id] = id_numérica

            if lista_palabras.length > 1
                resultado[:razón] = lista_palabras[1..].join(' ')
            end
        else
            resultado[:razón] = args
        end
    end

    # Trata de obtener un miembro de chat, y si no lo consigue
    # manda un mensaje de error.
    def obtener_miembro(msj, id_usuario)
        miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: id_usuario)
        miembro = miembro['result']
        Telegram::Bot::Types::ChatMember.new(miembro)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.message
        when /invalid user_id specified/
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "Esa ID (#{id_usuario}) es inválida",
                reply_to_message_id: msj.message_id
            )
        when /user not found/
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Quien tenga esa ID nunca estuvo en contacto con este chat',
                reply_to_message_id: msj.message_id
            )
        when /USER_ID_INVALID/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Disculpame pero no puedo reconocer esta id: #{id_usuario}. "\
                      'O es inválida, o es de alguien que nunca estuvo en este chat.'
            )
        else
            raise
        end
        nil
    end

    def obtener_chat(chat_id)
        chat = @tg.get_chat(chat_id: chat_id)
        Telegram::Bot::Types::Chat.new(chat['result'])
    end

    # Chequea que el miembro sea admin y tenga los permisos adecuados
    def tiene_permisos(msj, id_usuario, permiso, error_no_admin, error_no_permisos)
        miembro = obtener_miembro(msj, id_usuario)
        return false unless miembro
        return true if miembro.status == 'creator'

        if miembro.status != 'administrator'
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "#{error_no_admin} ser admin para hacer eso",
                reply_to_message_id: msj.message_id
            )
            return false
        end

        # Chequeo si tiene el permiso
        unless miembro.send permiso
            @tg.send_message(
                chat_id: msj.chat.id,
                text: error_no_permisos,
                reply_to_message_id: msj.message_id
            )
            return false
        end
        true
    end

    def enviar_lista(msj, conjunto_iterable, título_lista, crear_línea, error_vacío)
        # Si el conjunto está vacío aviso
        if conjunto_iterable.nil? || conjunto_iterable.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             text: error_vacío,
                             reply_to_message_id: msj.message_id)
            return
        end

        texto = título_lista
        conjunto_iterable.each do |elemento|
            # Armo la línea
            línea = crear_línea.call(elemento)

            # Mando blocazo de texto si corresponde
            if texto.length + línea.length > 4096
                @tg.send_message(chat_id: msj.chat.id,
                                 parse_mode: :html,
                                 text: texto,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
                # Nota: si la línea tiene más de 4096 caracteres, entonces en la próxima
                # iteración se va a mandar partida en dos mensajes (por tg.send_message)
                texto = línea
            else
                texto << línea
            end
        end

        # Si no queda nada por mandar, me voy
        return if texto.empty?

        # Y si quedaba algo, lo mando
        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         text: texto,
                         disable_web_page_preview: true,
                         disable_notification: true)
    end

    # Se guardan nombre, apellido y usuario cada uno en una lista por user_id
    # Hay dos listas por cada dato, una con el valor y otra con la fecha de cambio
    # ejemplo: "nombre:100000" y "nombre:100000:date"
    def redis_actualizar_datos_usuario(usuario)
        hora = Time.now.to_i
        cambios = []

        if (nombre = obtener_nombre_usuario(usuario.id)) && nombre != usuario.first_name
            cambios << redis_actualizar_dato_usuario(usuario.id, usuario.first_name,
                                                     :nombre, hora)
        end

        if obtener_apellido_usuario(usuario.id) != usuario.last_name
            cambios << redis_actualizar_dato_usuario(usuario.id, usuario.last_name,
                                                     :apellido, hora)
        end

        if obtener_username_usuario(usuario.id) != usuario.username
            cambios << redis_actualizar_dato_usuario(usuario.id, usuario.username,
                                                     :username, hora)
        end

        cambios.compact
    end

    def redis_eliminar_datos_usuario(id_usuario)
        %w[nombre: apellido: username:]
            .map { |w| w + id_usuario.to_s }
            .product(['', ':date'])
            .map(&:join)
            .each { |clave| @redis.del(clave) }
    end

    def redis_actualizar_dato_usuario(id, dato, tipo_de_dato, hora)
        clave = "#{tipo_de_dato}:#{id}"
        @redis.rpush(clave, dato)
        @redis.rpush("#{clave}:date", hora)
        @redis.llen(clave) > 1 ? tipo_de_dato : nil
    end

    # Las siguientes tres funciones devuelven dicho campo, o
    # un String vacío si el usuario no tiene dicho campo
    def obtener_nombre_usuario(id)
        nombre = @redis.lindex("nombre:#{id}", -1)
        return if nombre.nil? || nombre.empty?

        nombre
    end

    def obtener_apellido_usuario(id)
        apellido = @redis.lindex("apellido:#{id}", -1)
        return if apellido.nil? || apellido.empty?

        apellido
    end

    def obtener_username_usuario(id)
        username = @redis.lindex("username:#{id}", -1)
        return if username.nil? || username.empty?

        username
    end

    def nombres_usuario(id, &block)
        if block_given?
            iterar_datos_usuario('nombre:', id, &block)
        else
            to_enum :nombres_usuario, id
        end
    end

    def apellidos_usuario(id, &block)
        if block_given?
            iterar_datos_usuario('apellido:', id, &block)
        else
            to_enum :apellidos_usuario, id
        end
    end

    def usernames_usuario(id, &block)
        if block_given?
            iterar_datos_usuario('username:', id, &block)
        else
            to_enum :usernames_usuario, id
        end
    end

    def iterar_datos_usuario(campo, id)
        datos = @redis.lrange(campo + id.to_s, 0, -1)
        fechas = @redis.lrange("#{campo}#{id}:date", 0, -1)&.map(&:to_i)

        if block_given?
            datos.each.with_index { |dato, i| yield dato, fechas[i] }
        else
            to_enum :iterar_datos_usuario, campo, id
        end
    end

    # Método que envía un mensaje de texto y lo carga en la cola de spam
    def enviar_mensaje_y_a_spam(args)
        enviado = @tg.send_message(args)

        return unless enviado && enviado['ok']

        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        añadir_a_cola_spam(enviado.chat.id, enviado.message_id)
    end

    # Método que mete un id_mensaje en una cola de mensajes que
    # son borrados despues de cierto límite, para evitar el spam.
    def añadir_a_cola_spam(id_chat, id_mensaje)
        borrado = []
        @redis.rpush "spam:#{id_chat}", id_mensaje
        while @redis.llen("spam:#{id_chat}") > 24
            id_borrar = @redis.lpop("spam:#{id_chat}").to_i
            borrado << @tg.delete_message(chat_id: id_chat, message_id: id_borrar,
                                          ignorar_excepciones_telegram: true)
        end
        borrado
    end

    # Función que recibe un arreglo de Time o unix-time y verifica si se mandaron
    # muchos mensajes seguidos. Devuelve true o false
    def chequear_flood(arr, diferencia = 89)
        return true if arr.size.between? 0, 1

        promedio = arr.inject(0r) { |acc, i| acc + i.to_r }
        promedio /= arr.size
        diferencia_ahora = Time.now.to_r - promedio

        diferencia_ahora > diferencia
    end

    def incremetar_arr_flood(arr, tiempo)
        arr << tiempo
        arr.shift until arr.size <= 7
    end
end
