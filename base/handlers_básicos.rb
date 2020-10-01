class Dankie
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')
    add_handler Handler::CallbackQuery.new(:acciones_inferiores_lista, 'opcioneslista')
    add_handler Handler::Mensaje.new(:actualizar_datos_usuarios)

    # Método recursivo que actualiza los nombres de usuarios en redis
    # Necesita ser público por los handlers
    def actualizar_datos_usuarios(msj)
        redis_actualizar_datos_usuario msj.from

        redis_actualizar_datos_usuario msj.forward_from if msj.forward_from

        msj.new_chat_members.each do |usuario|
            redis_actualizar_datos_usuario usuario
        end

        redis_actualizar_datos_usuario msj.left_chat_member if msj.left_chat_member

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

    # Se guardan nombre, apellido y usuario cada uno en una lista por user_id
    # Hay dos listas por cada dato, una con el valor y otra con la fecha de cambio
    # ejemplo: "nombre:100000" y "nombre:100000:date"
    def redis_actualizar_datos_usuario(usuario)
        clave = "nombre:#{usuario.id}"
        hora = Time.now.to_i

        unless obtener_nombre_usuario(usuario.id) == usuario.first_name
            @redis.rpush(clave, usuario.first_name)
            @redis.rpush("#{clave}:date", hora)
        end

        clave = "apellido:#{usuario.id}"

        unless obtener_apellido_usuario(usuario.id) == usuario.last_name
            @redis.rpush(clave, usuario.last_name)
            @redis.rpush("#{clave}:date", hora)
        end

        clave = "username:#{usuario.id}"

        return if obtener_username_usuario(usuario.id) == usuario.username

        @redis.rpush(clave, usuario.username)
        @redis.rpush("#{clave}:date", hora)
    end

    def redis_eliminar_datos_usuario(id_usuario)
        %w[nombre: apellido: username:]
            .map { |w| w + id_usuario.to_s }
            .product(['', ':date'])
            .map(&:join)
            .each { |clave| @redis.del(clave) }
    end

    # Las siguientes tres funciones devuelven dicho campo, o
    # un String vacío si el usuario no tiene dicho campo
    def obtener_nombre_usuario(id)
        @redis.lindex("nombre:#{id}", -1)
    end

    def obtener_apellido_usuario(id)
        @redis.lindex("apellido:#{id}", -1)
    end

    def obtener_username_usuario(id)
        @redis.lindex("username:#{id}", -1)
    end

    def nombres_usuario(id, &block)
        iterar_datos_usuario('nombre:', id, &block)
    end

    def apellidos_usuario(id, &block)
        iterar_datos_usuario('apellido:', id, &block)
    end

    def usernames_usuario(id, &block)
        iterar_datos_usuario('username:', id, &block)
    end

    def iterar_datos_usuario(campo, id)
        datos = @redis.lrange(campo + id.to_s, 0, -1)
        fechas = @redis.lrange("#{campo}#{id}:date", 0, -1)&.map(&:to_i)

        datos.each.with_index { |dato, i| yield dato, fechas[i] }
    end
end
