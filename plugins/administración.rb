class Dankie
    add_handler Handler::Comando.new(:rajar, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:kick, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:ban, :ban,
                                     description: 'Baneo al usuario que me digas')
    add_handler Handler::Comando.new(:nisban, :ban,
                                     description: 'Baneo al usuario que me digas')
    add_handler Handler::Comando.new(:desban, :desban,
                                     description: 'Baneo al usuario que me digas')

    # Comando /rajar /kick
    def rajar(msj)
        # Función que uso para chequear que se cumplan condiciones específicas del comando
        chequeo_afectado = proc do |miembro|
            miembro.status == 'left' || miembro.status == 'kicked' ||
                (miembro.status == 'restricted' && !miembro.is_member)
        end
        # Función para moderar el grupete
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.unban_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No voy a echar a alguien que no estaba en el grupo '\
                         'al momento de mandar este comando'
        despedida = 'Ni nos vimos'

        aplicar_moderación(msj, chequeo_afectado, func_moderadora, error_afectado, despedida)
    end

    # Comando /ban /nisban
    def ban(msj)
        chequeo_afectado = proc do |miembro|
            miembro.status == 'kicked'
        end
        func_moderadora = proc do |chat_id, id_afectada|
            @tg.kick_chat_member(chat_id: chat_id, user_id: id_afectada)
        end

        error_afectado = 'No puedo a banear a alguien que ya lo estaba '\
                         'al momento de mandar este comando'
        despedida = 'Pero mirá el ban que te comiste'

        aplicar_moderación(msj, chequeo_afectado, func_moderadora, error_afectado, despedida)
    end

    private

    # Función que chequea los requisitos y ejecuta finalmente el comando moderador
    def aplicar_moderación(msj, chequeo_afectado, func_moderadora, error_afectado, despedida)
        cumple, miembro, razón = cumple_requisitos(msj)

        if cumple
            miembro = Telegram::Bot::Types::ChatMember.new(miembro)
            if chequeo_afectado.call(miembro)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_afectado,
                                 reply_to_message_id: msj.message_id)
            elsif moderar(msj, miembro.user.id, func_moderadora)
                razón = razón.nil? ? '' : ".\nRazón: " + razón + (razón[-1] == '.' ? '' : '.')
                @tg.send_message(chat_id: msj.chat.id,
                                 text: despedida + ' ' + crear_enlace(miembro.user) + razón,
                                 reply_to_message_id: msj.reply_to_message.nil? ? msj.message_id : msj.reply_to_message.message_id,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    # Todos los requisitos que hay que cumplir para banear/kickear
    def cumple_requisitos(msj)
        # Siempre que alguna de estas sea falsa, va a mandar un mensaje de error
        cumple = false
        miembro = nil
        razón = nil

        # Chequeo que sea en un grupo (implementada en Dankie.rb)
        if validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)
            # Chequeo que esté pasando una id para afectar
            id_afectada, razón, alias_id = dar_id_afectada(msj)

            if id_afectada && razón && razón.length > 233
                @tg.send_message(chat_id: msj.chat.id,
                                 text: "No puedo ejecutar el comando\n"\
                                 'Razón: la razón es muy larga.',
                                 reply_to_message_id: msj.message_id)
            elsif !id_afectada.nil? &&
                  # Chequeo que el bot sea admin en ese grupo y tenga los permisos correspondientes
                  # 'Necesito' y 'No tengo' son para los mensajes de error
                  tiene_permisos(msj, @user.id, 'can_restrict_members', 'Necesito', 'No tengo')

                # Chequeo que el usuario que llamó al comando sea admin y que quién se vea afectado no
                # Además devuelve el chat_member del usuario afectado.
                cumple, miembro = chequear_usuarios(msj, id_afectada, alias_id)
            end
        end
        [cumple, miembro, razón]
    end

    # Chequea que el miembro sea admin y tenga los permisos adecuados
    def tiene_permisos(msj, id_usuario, permiso, error_no_admin, error_no_permisos)
        miembro = obtener_miembro(msj.chat.id, id_usuario)
        tiene_autorización = true

        if !miembro
            tiene_autorización = false
        elsif miembro['status'] != 'creator'
            if miembro['status'] != 'administrator'
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_admin + ' ser admin para hacer eso',
                                 reply_to_message_id: msj.message_id)
            elsif !miembro[permiso]
                tiene_autorización = false
                @tg.send_message(chat_id: msj.chat.id,
                                 text: error_no_permisos + ' permisos para restringir/suspender usuarios',
                                 reply_to_message_id: msj.message_id)
            end
        end
        tiene_autorización
    end

    # Chequea que se esté respondiendo un mensaje
    def dar_id_afectada(msj)
        razón = nil
        id_afectada = nil
        args_mensaje = get_command_params(msj)
        alias_id = false

        # Si el mensaje tiene argumentos, reviso si me sirven para identificar
        # al usuario y/o si tiene la razón del baneo/kickeo/etc
        id_afectada, razón, alias_id = id_y_razón(msj, args_mensaje.strip) if args_mensaje

        # Si está respondiendo a un mensaje y no se obtuvo un id de los argumentos
        # toma el id de ese miembro para ser afectado. Notar que la razón de baneo/kick/etc
        # es obtenida en el if anterior (si existe), por lo tanto no se puede poner
        # if elsif
        if msj.reply_to_message && id_afectada.nil?
            id_afectada = msj.reply_to_message.from.id
        end

        # Si no se pudo obtener id, aviso
        if id_afectada.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Si no me decís contra quién usar esto '\
                                   'no puedo hacer nada papurri. Tenés que pasarme '\
                                   'SOLO UN miembro al que quieras que afecte: dame '\
                                   'su id, alias (mención si no tiene alias) '\
                                   'o respondé un mensaje suyo. También podés acompañar '\
                                   'el comando con una razón (de hasta 233 caracteres) de '\
                                   'por qué estás usando esto, '\
                                   "con el siguiente formato ''/comando usuario razón'', "\
                                   "o ''/comando razón'' si estás respondiendo a un mensaje "\
                                   '(notar que si en este caso la razón empieza con un usuario, '\
                                   'entonces el comando lo va a afectar a él). Si ponés varios '\
                                   'usuarios, solo va a afectar al primero.',
                             reply_to_message_id: msj.message_id)
        # Al botazo no le pueden afectar los comandos
        elsif id_afectada == @user.id
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Ni se te ocurra',
                             reply_to_message_id: msj.message_id)
            id_afectada = nil
        end

        [id_afectada, razón, alias_id]
    end

    def id_y_razón(msj, args_mensaje)
        id = nil
        lista_entidades = nil
        razón = nil
        alias_id = false

        if msj.entities && !msj.entities.empty?
            texto = msj.text
            lista_entidades = msj.entities
        elsif msj.caption_entities && !msj.caption_entities.empty?
            texto = msj.caption
            lista_entidades = msj.caption_entities
        end

        if lista_entidades
            entidad = nil

            # Si se llama al comando así -> "/comando" entonces eso ya
            # cuenta como una entidad
            if lista_entidades.length >= 2 &&
               lista_entidades[0].type == 'bot_command' &&
               lista_entidades[0].offset == 0

                entidad = lista_entidades[1]
            # msj.entities.length == 1, por ejemplo si se llama
            # así -> "!comando"
            elsif !lista_entidades.empty?
                entidad = lista_entidades[0]
            end

            # Veo si efectivamente había una entidad que ocupaba el principio del argumento del comando
            # (me parece mal chequear que ocupe todo el texto acá, porque
            # podría ser un hashtag por ejemplo y estaría chequeando cosas al
            # pedo, pero bueno las posibilidades de eso son muy bajas y prefiero
            # eso a estar repitiendo código)
            if entidad &&
               args_mensaje.start_with?(texto[entidad.offset..(entidad.offset + entidad.length - 1)])

                # Me fijo si era un alias
                if entidad.type == 'mention'
                    # TODO: algo que relacione alias con id
                    alias_id = texto[entidad.offset..(entidad.offset + entidad.length - 1)]
                    razón = texto[(entidad.offset + entidad.length)..-1].strip
                    razón = nil if razón.empty?
                # Me fijo si era una mención de usuario sin alias
                elsif entidad.type == 'text_mention'
                    id = entidad.user.id
                    razón = texto[(entidad.offset + entidad.length)..-1].strip
                    razón = nil if razón.empty?
                end
            end
        end
        # Si no logré nada con las entidades, entonces chequeo si me pasaron una id como texto
        id, razón = id_numérica_y_razón(args_mensaje) if id.nil?

        # Si hay más de dos entidades, se que no es un caso que
        # quiero (solo permito banear/desbanear de a 1)
        razón = args_mensaje if id.nil?

        [id, razón, alias_id]
    end

    def id_numérica_y_razón(args_mensaje)
        lista_palabras = args_mensaje.split
        primer_palabra = natural(lista_palabras.first)

        if primer_palabra
            [primer_palabra, lista_palabras[1..-1].join(' ')]
        else
            [nil, nil]
        end
    end

    def chequear_usuarios(msj, id_afectada, alias_id)
        resultado = false
        miembro = nil

        # Chequeo que quien llame al comando sea admin y tenga permisos para restringir usuarios
        if tiene_permisos(msj, msj.from.id, 'can_restrict_members', 'Tenés que', 'No tenés')

            miembro = obtener_miembro(msj.chat.id, id_afectada)

            if miembro
                # Chequeo si a quien le afecta el comando es admin, y de ser necesario, devuelvo el estatus
                if miembro['status'] == 'administrator' || miembro['status'] == 'creator'
                    @tg.send_message(chat_id: msj.chat.id,
                                     text: 'No podés usar este comando contra un admin',
                                     reply_to_message_id: msj.message_id)
                elsif alias_id && (!miembro['status']['username'] ||
                        miembro['status']['username'] != alias_id)
                    @tg.send_message(chat_id: msj.chat.id,
                                     text: 'No reconozco ese alias, lo más probable es que '\
                    		     	   	'haya sido cambiado recientemente',
                                     reply_to_message_id: msj.message_id)
                else
                    resultado = true
                end
            end
        end

        [resultado, miembro]
    end

    def moderar(msj, id_afectada, funcion)
        funcion.call(msj.chat.id, id_afectada)['result']
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when %r{not enough rights to restrict/unrestrict chat member}
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                             'mientras se ejecutaba el comando, y por '\
                             'ahora no puedo sacar a nadie del grupete'
            log_y_aviso(msj, error_permisos)
        when /user is an administrator of the chat/
            error_admin = 'El miembro al que tratás de restringir fue '\
                          'convertido en admin mientras se ejecutaba este comando '\
                          'y no puedo hacerle nada'
            log_y_aviso(msj, error_admin)
        else
            raise
        end

        false
    end

    def obtener_miembro(chat_id, user_id)
        @tg.get_chat_member(chat_id: chat_id, user_id: user_id)['result']
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /USER_ID_INVALID/
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Disculpame pero no puedo reconocer esta ID: #{user_id}",
                             reply_to_message_id: msj.message_id)
        else
            raise
        end

        nil
    end

    def log_y_aviso(msj, error)
        @logger.log(Logger::ERROR, error + ' en ' + grupo_del_msj(msj))
        @tg.send_message(chat_id: msj.chat.id,
                         text: error,
                         reply_to_message_id: msj.message_id)
    end
end
