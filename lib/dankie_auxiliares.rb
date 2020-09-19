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
        else
            id_usuario = usuario

            alias_usuario = @redis.get "usuario:#{id_usuario}"
            unless alias_usuario
                usuario = @tg.get_chat_member(chat_id: id_chat, user_id: usuario)
                usuario = Telegram::Bot::Types::ChatMember.new(usuario['result']).user
                alias_usuario = usuario.username
                redis_actualizar_datos usuario
            end
        end

        mención = if alias_usuario && !alias_usuario.empty?
                  then "<a href='https://telegram.me/#{alias_usuario}'>"
                  else "<a href='tg://user?id=#{id_usuario}'>"
                  end

        if con_apodo && (apodo = @redis.hget("apodo:#{id_chat}", id_usuario))
            mención << "#{html_parser apodo}</a>"
        elsif (nombre = @redis.get("nombre:#{id_usuario}")) && !nombre.empty?
            mención << "#{html_parser nombre}</a>"
        else
            usuario = @tg.get_chat_member(chat_id: id_chat, user_id: usuario)
            usuario = Telegram::Bot::Types::ChatMember.new(usuario['result']).user
            # Lo comente porque no se usa
            # alias_usuario = usuario.username

            redis_actualizar_datos usuario
            if usuario.first_name.empty?
                mención = "ay no c (#{id_usuario})"
            else
                mención << "#{html_parser usuario.first_name}</a>"
            end
        end

        mención
    rescue Telegram::Bot::Exceptions::ResponseError => e
        mención = "ay no c (#{id_usuario})"
        if e.to_s =~ /user not found|wrong user_id specified/
            @logger.error('Traté de obtener el nombre de una cuenta '\
                        "eliminada: #{id_usuario}")
            return nil
        else
            @logger.error e
        end

        mención
    end

    def natural(numero)
        if numero.length < 25
            begin
                num = Integer(numero)
            rescue StandardError
                return false
            end

            return num if num.positive?
        end

        false
    end

    def validar_desarrollador(usuario_id, chat_id, mensaje_id,
                              texto: 'Vos no podés usar esto pa')
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(usuario_id)
            @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id,
                             text: texto)
            return false
        end

        true
    end

    def es_admin(usuario_id, chat_id, mensaje_id, text = nil, _id = nil)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: usuario_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        # Si no lo es, manda mensaje de error
        if (status != 'administrator') && (status != 'creator')
            unless text.nil?
                @tg.send_message(chat_id: chat_id,
                                 reply_to_message_id: mensaje_id,
                                 text: text)
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

    # Devuelve la id del usuario al que se quiere afectar con el comando +
    # el resto del texto (si es que hay alguno) en el mensaje
    # También devuelve un alias_usuario que es un string con el alias pasado
    # en el mensaje (si es que hubo alguno, ej: /kick @alias) para chequear
    # después que el id sea válido y corresponda con ese alias.
    def id_y_resto(msj)
        id_afectada = nil
        otro_texto = nil
        alias_usuario = false

        lista_entidades = nil
        args_mensaje = get_command_params(msj)

        if args_mensaje
            args_mensaje = args_mensaje.strip

            # Obtengo texto y entidades del mensaje del comando
            if msj.entities && !msj.entities.empty?
                texto = msj.text
                lista_entidades = msj.entities
            elsif msj.caption_entities && !msj.caption_entities.empty?
                texto = msj.caption
                lista_entidades = msj.caption_entities
            end

            # Me fijo si hay entidades
            if lista_entidades && !lista_entidades.empty?
                entidad = nil

                # Si se llama al comando así -> "/comando" entonces eso ya
                # cuenta como una entidad
                if lista_entidades.length >= 2 &&
                   lista_entidades[0].type == 'bot_command' &&
                   lista_entidades[0].offset.zero?

                    entidad = lista_entidades[1]
                # msj.entities.length == 1, por ejemplo si se llama
                # así -> "!comando"
                elsif lista_entidades.length == 1
                    entidad = lista_entidades[0]
                end

                fin = entidad.offset + entidad.length
                # Veo si efectivamente había una entidad que ocupaba el principio del
                # argumento del comando (me parece mal chequear que ocupe todo el texto
                # acá, porque podría ser un hashtag por ejemplo y estaría chequeando
                # cosas al pedo, pero bueno las posibilidades de eso son muy bajas y
                # prefiero eso a estar repitiendo código)
                if entidad &&
                   args_mensaje.start_with?(texto[entidad.offset..(fin - 1)])

                    otro_texto = texto[fin..].strip
                    otro_texto = nil if otro_texto.empty?

                    # Me fijo si esa entidad efectivamente era un alias
                    case entidad.type
                    when 'mention'
                        # La entidad arranca con un @, por eso el + 1
                        alias_usuario = texto[(entidad.offset + 1)..(fin - 1)].strip
                        id_afectada = obtener_id_de_alias(alias_usuario)
                    # Me fijo si esa entidad efectivamente
                    # era una mención de usuario sin alias
                    when 'text_mention'
                        id_afectada = entidad.user.id
                    end
                end
            end

            # Si no logré nada con las entidades, entonces chequeo si
            # me pasaron una id como texto
            if id_afectada.nil?
                id_afectada, otro_texto = id_numérica_y_otro_texto(args_mensaje)
            end
            # Si no conseguí ninguna id, entonces todo el argumento es "otro_texto"
            otro_texto = args_mensaje if id_afectada.nil?
        end
        # Si está respondiendo a un mensaje y no se obtuvo un id de los argumentos
        # toma el id de ese miembro para ser afectado. Notar que el otro texto
        # es obtenido en el if anterior (si existe)
        if msj.reply_to_message && id_afectada.nil?
            id_afectada = msj.reply_to_message.from.id
        end

        [id_afectada, alias_usuario, otro_texto]
    end

    def id_numérica_y_otro_texto(args_mensaje)
        lista_palabras = args_mensaje.split
        primer_palabra = natural(lista_palabras.first)

        if primer_palabra
            [primer_palabra, lista_palabras[1..].join(' ')]
        else
            [nil, nil]
        end
    end

    # Trata de obtener un miembro de chat, y si no lo consigue
    # manda un mensaje de error.
    def obtener_miembro(msj, id_usuario)
        miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: id_usuario)
        miembro = miembro['result']
        Telegram::Bot::Types::ChatMember.new(miembro)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /USER_ID_INVALID/
            @logger.error("Me dieron una id inválida en #{grupo_del_msj(msj)}")
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Disculpame pero no puedo reconocer esta '\
                                   "id: #{id_usuario}. O es inválida, o es de "\
                                   'alguien que nunca estuvo en este chat.',
                             reply_to_message_id: msj.message_id)
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
        tiene_autorización = true

        if !miembro
            tiene_autorización = false
        elsif miembro.status != 'creator'
            if miembro.status != 'administrator'
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: "#{error_no_admin} ser admin para hacer eso",
                                 reply_to_message_id: msj.message_id)
            # Chequeo si tiene el permiso
            elsif !(miembro.send permiso)
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_permisos,
                                 reply_to_message_id: msj.message_id)
            end
        end
        tiene_autorización
    end

    def log_y_aviso(msj, error, al_canal: true)
        @logger.error("#{error} en #{grupo_del_msj(msj)}", al_canal: al_canal)
        @tg.send_message(chat_id: msj.chat.id,
                         text: error,
                         reply_to_message_id: msj.message_id)
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

    # Método que mete un id_mensaje en una cola de mensajes que
    # son borrados despues de cierto límite, para evitar el spam.
    def añadir_a_cola_spam(id_chat, id_mensaje)
        borrado = nil
        @redis.rpush "spam:#{id_chat}", id_mensaje
        if @redis.llen("spam:#{id_chat}") > 24
            id_mensaje = @redis.lpop("spam:#{id_chat}").to_i
            borrado = @tg.delete_message(chat_id: id_chat, message_id: id_mensaje)
        end
        borrado
    end

    # Función que recibe un arreglo de Time o unix-time y verifica si se mandaron
    # muchos mensajes seguidos. Devuelve true o false
    def chequear_flood(arr)
        return true if arr.size.between? 0, 1

        promedio = 0
        arr.each { |i| promedio += i.to_r }
        promedio /= arr.size
        diferencia_ahora = Time.now.to_r - promedio

        diferencia_ahora > 89
    end

    def incremetar_arr_flood(arr, tiempo)
        arr << tiempo
        arr.shift until arr.size <= 13
    end

    def arreglo_tablero(conjunto_iterable, arr, título,
                        subtítulo, contador, max_cant, max_tam,
                        agr_elemento, inicio_en_subtítulo: false)
        return if conjunto_iterable.nil? || conjunto_iterable.empty?

        # .dup crea una copia del objeto original
        if inicio_en_subtítulo && !arr.empty? && subtítulo &&
           contador < max_cant && arr.last.size < max_tam
            # Meto subtítulo si queda bien ponerlo en este caso
            arr.last << subtítulo.dup
        end
        # Itero sobre los elementos
        conjunto_iterable.each do |elemento|
            # Si es una página nueva agrego título y subtítulo
            if arr.empty? || contador >= max_cant || arr.last.size >= max_tam
                arr << título.dup
                arr.last << subtítulo.dup if subtítulo
                contador = 0
            end
            # Agrego el elemento juju
            arr.last << agr_elemento.call(elemento)
            contador += 1
        end
        # Devuelvo el contador para que pueda ser usado luego en futuras
        # llamadas a esta función, recordar que los integers se pasan por
        # copia
        contador
    end
end
