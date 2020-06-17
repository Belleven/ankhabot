require 'concurrent-ruby'
require 'byebug'

TIPOS_MMEDIA = { text: :send_message,
                 photo: :send_photo,
                 sticker: :send_sticker,
                 audio: :send_audio,
                 voice: :send_voice,
                 video: :send_video,
                 video_note: :send_video_note,
                 animation: :send_animation,
                 document: :send_document }.freeze

class Dankie
    add_handler Handler::Mensaje.new(:chequear_triggers,
                                     permitir_editados: false,
                                     ignorar_comandos: true,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:settrigger, :validar_poner_trigger_local,
                                     permitir_params: true,
                                     descripción: 'Agrega un trigger al bot',
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:setglobal, :validar_poner_trigger_global,
                                     permitir_params: true,
                                     descripción: 'Agrega un trigger global al bot')
    add_handler Handler::Comando.new(:deltrigger, :validar_borrar_trigger,
                                     permitir_params: true,
                                     descripción: 'Borra un trigger')
    # params_triggers = Parámetros.new(órden: [:fecha, :uso, :nombre],
    #                                  máximo: Integer)
    add_handler Handler::Comando.new(:triggers, :listar_triggers,
                                     permitir_params: true,
                                     # parámetros: params_triggers,
                                     descripción: 'Envía la lista de triggers')
    add_handler Handler::Comando.new(:infotrigger, :enviar_info_trigger,
                                     permitir_params: true,
                                     descripción: 'Envía información del trigger')
    add_handler Handler::Comando.new(:triggered, :triggered,
                                     permitir_params: false,
                                     descripción: 'Muestra que triggers reaccionan'\
                                     ' al mensaje respsondido')
    add_handler Handler::CallbackQuery.new(:callback_set_trigger_global, 'settrigger')
    add_handler Handler::CallbackQuery.new(:callback_del_trigger_global, 'deltrigger')

    add_handler Handler::EventoDeChat.new(:triggers_supergrupo,
                                          tipos: [:migrate_from_chat_id],
                                          chats_permitidos: %i[supergroup])

    # Método que mete un mensaje en la cola de mensajes a procesar por los triggers.
    def despachar_mensaje_a_trigger(msj)
        puts 'entra a función'
        @cola_triggers ||= Concurrent::Array.new
        @cola_triggers << msj
        @hilo_triggers_creado ||= false

        unless @hilo_triggers_creado
            $hilo_triggers = Thread.new { loop_hilo_triggers }
            $hilo_triggers.abort_on_exception = true
            @hilo_triggers_creado = true
        end
        puts 'fuera de hilos'

        # por las dudas que esto se ejecute antes que el otro bloque
        $hilo_triggers[:hora] ||= Concurrent::AtomicFixnum.new

        if $hilo_triggers[:hora].value.positive? &&
           (Time.now.to_i - $hilo_triggers[:hora].value) > 10

            puts 'por matar el hilo'
            $hilo_triggers.kill
            puts 'hilo matado'
            $hilo_triggers_creado = false
            @logger.info('triggers colgados en algún grupo', al_canal: true)
        end
        puts 'termina'
    end

    def loop_hilo_triggers
        puts 'hilo creado'
        Thread.current[:hora] ||= Concurrent::AtomicFixnum.new

        loop do
            puts 'en el loop'
            Thread.current[:hora].value = Time.now.to_i

            if @cola_triggers.empty?
                sleep(0.200)
                next
            end
            puts "mensaje: #{@cola_triggers.first&.text}"

            chequear_triggers @cola_triggers.shift
        end
    end

    def chequear_triggers(msj)
        return unless (texto = msj.text || msj.caption)

        Trigger.redis ||= @redis

        # Acá guardo los unix-time de cuando se manda un trigger
        @trigger_flood ||= {}
        @trigger_flood[msj.chat.id] ||= []

        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            next unless chequear_flood(@trigger_flood[msj.chat.id])

            match = Timeout.timeout(0.500) { regexp.match? texto }
            next unless match

            trigger = Trigger.new(id_grupo, regexp)

            # No manda el trigger si fue lo último que mandó en cinco minutos
            next unless (Time.now.to_i - trigger.último_envío(msj.chat.id)) > 300

            trigger.actualizar_último_envío(msj.chat.id)
            incremetar_arr_flood(@trigger_flood[msj.chat.id], Time.now)

            puede_globales = validar_globales_en_chat(msj.chat.id)
            unless !puede_globales && id_grupo == :global
                enviar_trigger(msj.chat.id,
                               trigger)
            end

        # Si el trigger tardó mucho en procesar, lo borro.
        rescue Timeout::Error
            Trigger.borrar_trigger(id_grupo, regexp)
            texto = 'Trigger '
            texto << "<code>#{html_parser Trigger.regexp_a_str(regexp)}</code> "
            texto << 'borrado en el grupo '
            texto << "#{html_parser msj.chat&.title} (#{msj.chat.id}) "
            texto << "por ralentizar al bot.\n"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto)
            @tg.send_message(chat_id: @canal, parse_mode: :html, text: texto)
        end
    end

    def validar_globales_en_chat(id_chat)
        Configuración.redis ||= @redis
        puede = Configuración.config(id_chat, :admite_triggers_globales)
        puede.nil? ? true : puede.to_i.positive?
    end

    def validar_poner_trigger_local(msj, params)
        validar_set_trigger(msj, params, msj.chat.id)
    end

    def validar_poner_trigger_global(msj, params)
        validar_set_trigger(msj, params, :global)
    end

    def callback_set_trigger_global(callback)
        # Valido usuario
        unless DEVS.member? callback.from.id
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Solo devs pueden usar esto')
            return
        end

        match = callback.data.match(/settrigger:(?<id_regexp>\d+):(?<acción>.+)/)
        Trigger.redis ||= @redis

        unless Trigger.existe_temporal? match[:id_regexp]
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Procesando otra respuesta')
            return
        end

        usuario = obtener_enlace_usuario(callback.from, callback.chat_instance) || 'dou'
        case match[:acción]
        when 'confirmar'
            temp = Trigger.confirmar_trigger match[:id_regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> confirmado por #{usuario} (#{callback.from.id})."
        when 'rechazar'
            temp = Trigger.rechazar_trigger match[:id_regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> rechazado por #{usuario} (#{callback.from.id})."
        end

        @tg.answer_callback_query(callback_query_id: callback.id)
        @tg.edit_message_text(chat_id: callback.message.chat.id,
                              parse_mode: :html, text: texto,
                              message_id: callback.message.message_id,
                              disable_web_page_preview: true,
                              disable_notification: true)
        texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
        texto << "</code> #{match[:acción] == 'confirmar' ? 'aceptado' : 'rechazado'}."
        @tg.send_message(chat_id: temp[:id_grupo], parse_mode: :html,
                         text: texto, reply_to_message_id: temp[:id_msj])
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.warn e.to_s
    end

    def callback_del_trigger_global(callback)
        # Valido usuario
        unless DEVS.member? callback.from.id
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Solo devs pueden usar esto')
            return
        end

        match = callback.data.match(/deltrigger:(?<id_regexp>\d+):(?<acción>.+)/)

        Trigger.redis ||= @redis

        unless Trigger.existe_temporal? match[:id_regexp]
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Procesando otra respuesta')
            return
        end

        temp = Trigger.obtener_del_trigger_temp match[:id_regexp]

        usuario = obtener_enlace_usuario(callback.from, callback.chat_instance) || 'dou'
        case match[:acción]
        when 'borrar'
            Trigger.borrar_trigger :global, temp[:regexp], match[:id_regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> borrado por #{usuario} (#{callback.from.id})."
        when 'ignorar'
            Trigger.descartar_temporal match[:id_regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> salvado por #{usuario} (#{callback.from.id})."
        end

        Trigger.borrar_global_resuelto(temp[:regexp])

        @tg.answer_callback_query(callback_query_id: callback.id)
        @tg.edit_message_text(chat_id: callback.message.chat.id,
                              parse_mode: :html, text: texto,
                              message_id: callback.message.message_id,
                              disable_web_page_preview: true,
                              disable_notification: true)
        texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
        texto << "</code> #{match[:acción] == 'borrar' ? 'borrado' : 'no fue borrado'}."
        @tg.send_message(chat_id: temp[:id_grupo], parse_mode: :html,
                         text: texto, reply_to_message_id: temp[:id_msj],
                         disable_web_page_preview: true,
                         disable_notification: true)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.warn e.to_s
    end

    def validar_borrar_trigger(msj, params)
        unless params
            texto = '<b>Modo de uso:</b>'
            texto << "\n/deltrigger trigger"
            texto << "\nfijate en /triggers cuáles existen"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        unless (regexp = Trigger.str_a_regexp params)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No sirve tu trigger, #{TROESMAS.sample}.",
                             reply_to_message_id: msj.message_id)
            return
        end

        Trigger.redis ||= @redis

        # grupo_trigger se fija si es local o global, si no devuelve nil
        # en caso de ser local en otro grupo no se entera
        if (grupo = Trigger.grupo_trigger(msj.chat.id, regexp)).nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No encontré el trigger, #{TROESMAS.sample}.\n"\
                                  "fijate en /triggers@#{@user.username}.",
                             reply_to_message_id: msj.message_id)
        elsif grupo == :global
            if Trigger.temporal_deltrigger(regexp)
                texto = 'Alguien ya está borrando un trigger con esa expresión '
                texto << "regular, #{TROESMAS.sample}."
                @tg.send_message(chat_id: msj.chat.id, text: texto,
                                 reply_to_message_id: msj.message_id)
            else
                confirmar_borrar_trigger_global(regexp, msj.chat, msj.date,
                                                msj.from.id, msj.message_id)
                @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Ahora veo si lo borran')
            end
        # En este caso es trigger local sí o sí
        else
            borrar_trigger regexp, msj.chat.id, msj
        end
    end

    def listar_triggers(msj, _params)
        Trigger.redis ||= @redis

        triggers_globales = Trigger.triggers_grupo_ordenados(:global)
        triggers_locales = Trigger.triggers_grupo_ordenados(msj.chat.id)

        # Caso en el que no hay triggers
        if (triggers_globales.nil? || triggers_globales.empty?) &&
           (triggers_locales.nil? || triggers_locales.empty?)

            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No hay triggers en este grupo u.u')
            return
        end

        # Variables "globales" que va a usar la función que crea el array del tablero
        título = "<b>Lista de triggers</b> <i>(#{Time.now.strftime('%d/%m/%Y %T')})</i>:"
        contador = 0
        arr = []
        # Código para agregar elemento en el array del tablero
        agr_elemento = proc do |elemento|
            "\n<pre> - #{html_parser elemento}</pre>"
        end

        # Definido en Dankie.rb
        contador = arreglo_tablero(triggers_locales, arr, título,
                                   "\n<b>Locales:</b>", contador,
                                   30, 1000, agr_elemento)

        # Cuando se haga el coso para desactivar triggers globales,
        # hacer algo para ignorar estos dos bloques
        arreglo_tablero(triggers_globales, arr, título,
                        "\n<b>Globales:</b>", contador,
                        30, 1000, agr_elemento, true)

        # Armo botonera y envío
        opciones = armar_botonera 0, arr.size, msj.from.id

        respuesta = @tg.send_message(chat_id: msj.chat.id,
                                     parse_mode: :html,
                                     reply_markup: opciones,
                                     text: arr.first)
        return unless respuesta

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']
        armar_lista(msj.chat.id, respuesta.message_id, arr)
    end

    def enviar_info_trigger(msj, params)
        # Si no tengo parámetros explico el modo de uso
        unless params
            texto = '<b>Modo de uso:</b>'
            texto << "\n<pre>/infotrigger trigger</pre>"
            texto << "\n<pre>trigger</pre> tiene que ser exactamente"
            texto << ' la expresión regular que activa al trigger.'
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             reply_to_message_id: msj.message_id, text: texto)
            return
        end

        # Si es una expresión regular inválida aviso
        unless (regexp_recibida = Trigger.str_a_regexp params)
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "No sirve tu trigger, #{TROESMAS.sample}.")
            return
        end

        # Seteo la BBDD
        Trigger.redis ||= @redis
        # Obtengo el id_grupo si es que existe el trigger
        id_grupo = Trigger.grupo_trigger(msj.chat.id, regexp_recibida)

        # Si el trigger no existía, aviso
        unless id_grupo
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'No pude encontrar el trigger úwù')
            return
        end

        # Creo el trigger con todos sus datazos
        trigger = Trigger.new(id_grupo, regexp_recibida)

        # Relleno el texto a enviar
        texto = '<b>Info del trigger:</b>'
        texto << "\nRegexp: <code>"
        texto << "#{html_parser Trigger.regexp_a_str(trigger.regexp)}</code>"
        campo = trigger.data.compact
        texto << "\nMedia: #{campo.keys.first}"
        texto << "\n#{campo.keys.first.to_s == 'text' ? 'Valor' : 'Id'}: "
        texto << if campo.values.first.size < 100
                     "<code>#{html_parser campo.values.first}</code>"
                 else
                     "<code>#{html_parser campo.values.first[0, 100]}...</code>"
                 end
        unless trigger.caption.empty?
            texto << "\nCaption: <code>#{html_parser trigger.caption}</code>"
        end
        texto << "\nTipo: #{id_grupo == :global ? 'global' : 'de grupo'}"
        texto << "\nCreador: #{obtener_enlace_usuario(trigger.creador,
                                                      msj.chat.id) || 'eliminado'}"
        texto << "\nTotal de usos: #{trigger.contador}"
        texto << "\nAñadido: <i>#{trigger.fecha.strftime('%d/%m/%Y %T')}</i>"

        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         disable_web_page_preview: true, text: texto,
                         disable_notification: true)
    end

    def triggered(msj)
        unless (texto = msj.reply_to_message&.text || msj.reply_to_message&.caption)
            texto = "Respondele a un mensaje de texto, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        Trigger.redis ||= @redis

        enviar = "Triggers que matchean el mensaje respondido:\n"
        emparejó = false
        Trigger.triggers(msj.chat.id) do |_id_grupo, regexp|
            next unless (match = regexp.match texto)

            enviar << "\n<pre>#{html_parser Trigger.regexp_a_str(regexp)}</pre>\n"
            línea = html_parser(match.string)
            texto_match = html_parser match[0]
            línea.gsub!(texto_match, "<b>#{texto_match}</b>")
            enviar << línea << "\n"
            emparejó = true
        end
        enviar = emparejó ? enviar : 'Ningún trigger matchea con este mensaje'

        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id, text: enviar)
    end

    def triggers_supergrupo(msj)
        # Para cada trigger en el grupete tengo que cambiar su clave y la clave
        # de la metada
        @redis.smembers("triggers:#{msj.migrate_from_chat_id}").each do |trigger|
            cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                      msj.chat.id, 'trigger:', ":#{trigger}")
            cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                      msj.chat.id, 'trigger:', ":#{trigger}:metadata")
            # Acá la clave ya fue cambiada
            @redis.hset("trigger:#{msj.chat.id}:#{trigger}:metadata",
                        'chat_origen', msj.chat.id.to_s)
        end

        # Hay que cambiar la clave del conjunto de triggers del grupete
        cambiar_claves_supergrupo(msj.migrate_from_chat_id, msj.chat.id, 'triggers:')

        # Hay que cambiar los datos de las claves de triggers temporales
        # Tremenda virgueada esto, pero no queda otra papá, por lo menos
        # no con como tenemos las claves ahora y no pienso cambiar el diseño
        # de la bbdd porque me da paja pelearme con el luke soladri por eso
        @redis.each_key do |clave|
            next unless clave.start_with?('triggers:settrigger:') ||
                        clave.start_with?('triggers:deltrigger:')
            next unless @redis.hget(clave, 'id_grupo') == msj.migrate_from_chat_id.to_s

            @redis.hset(clave, 'id_grupo', msj.chat.id.to_s)
        end
    end

    private

    # Función que envía un trigger al grupo
    # recibe el id del grupo, y un objeto Trigger para enviar
    def enviar_trigger(id_chat, trigger, id_msj_log = nil)
        TIPOS_MMEDIA.each do |media, send_media|
            next unless trigger.data[media]

            # Esta cosa mágica funciona
            resp = @tg.public_send(send_media,
                                   chat_id: id_chat,
                                   caption: trigger.caption,
                                   media => trigger.data[media],
                                   reply_to_message_id: id_msj_log)
            # Salgo si era un log esto
            return resp if id_msj_log

            # Si no aumento el contador y añado el msj a la cola de spam
            trigger.aumentar_contador
            break unless resp && resp['ok']

            añadir_a_cola_spam(id_chat, resp.dig('result', 'message_id').to_i)
            @logger.info("Trigger enviado en #{id_chat}", al_canal: false)
        end
    end

    # Función para poner triggers de grupo o globales
    def poner_trigger(regexp, msj, id_grupo, id_usuario, id_msj)
        data = { caption: msj.caption }

        if !msj.photo.empty?
            data[:photo] = msj.photo.first.file_id
        elsif msj.text
            data[:text] = msj.text
        else
            trigger_media = nil
            (TIPOS_MMEDIA.keys - %i[photo text]).each do |media|
                next unless msj.send(media)

                data[media] = msj.send(media).file_id
                trigger_media = media
                break
            end

            # Si el mensaje no contenía algo que pueda ser un trigger, aviso
            if trigger_media.nil?
                texto = 'Ese tipo de mensaje no está soportado '
                texto << "como trigger, #{TROESMAS.sample}."
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: id_msj,
                                 text: texto)
                return nil
            end
        end

        # El .to_s es porque id_grupo puede ser :global y hay que castearlo a string
        Trigger.poner_trigger(id_grupo.to_s, id_usuario, regexp, data)

        regexp = Trigger.regexp_a_str regexp
        if id_grupo == :global
            loggear = "Trigger #{regexp} sugerido para ser global por #{id_usuario} "
            loggear << "en el chat #{msj.chat.id}"
            contador = Trigger.confirmar_poner_trigger(msj.chat.id, regexp, id_msj)
        else
            loggear = "Trigger #{regexp} agregado por #{id_usuario} "
            loggear << "en el chat #{msj.chat.id}"
            contador = nil

            texto = "Trigger <code>#{html_parser regexp}</code> "
            texto << "añadido por #{obtener_enlace_usuario(id_usuario,
                                                           msj.chat.id) || 'eliminado'} "
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             reply_to_message_id: id_msj,
                             disable_web_page_preview: true,
                             disable_notification: true)
        end
        @logger.info(loggear)
        contador
    end

    # Función para enviar un mensaje de logging y aceptar o rechazar triggers
    def confirmar_trigger_global(regexp, chat, fecha, id_usuario, id_regexp)
        regexp_sanitizada = html_parser Trigger.regexp_a_str(regexp)

        arr = [[
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Aceptar',
                callback_data: "settrigger:#{id_regexp}:confirmar"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Rechazar',
                callback_data: "settrigger:#{id_regexp}:rechazar"
            )
        ]]

        # Aviso que quieren poner un gatillo
        fecha = Time.at(fecha, in: @tz.utc_offset)

        texto = fecha.strftime("<code>[%d/%m/%Y %T]</code>\n")
        texto << 'Usuario '
        texto << obtener_enlace_usuario(id_usuario, chat.id,
                                        con_apodo: false) || 'eliminado'
        texto << " (#{id_usuario}) en el chat "
        texto << "#{html_parser(chat&.title || chat&.username)} (#{chat.id}) "
        texto << 'quiere añadir el trigger: '
        texto << "<code>#{regexp_sanitizada}</code>\n"
        msj_log = @tg.send_message(chat_id: @canal, parse_mode: :html, text: texto,
                                   disable_web_page_preview: true,
                                   disable_notification: true)
        id_msj_log = msj_log['result']['message_id'].to_i

        # Mando el trigger al canal de logging
        trigger = Trigger.new(:global, regexp, true)
        msj_enviado = enviar_trigger(@canal, trigger, id_msj_log)
        id_enviado = msj_enviado['result']['message_id'].to_i

        # Mando el tablero para aceptar o rechazarlo
        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        @tg.send_message(chat_id: @canal, parse_mode: :html,
                         text: "¿Aceptar el trigger <code>#{regexp_sanitizada}</code>?",
                         reply_markup: opciones, disable_web_page_preview: true,
                         disable_notification: true,
                         reply_to_message_id: id_enviado)
    end

    # Función para enviar un mensaje de logging y confirmar si se borra un trigger
    def confirmar_borrar_trigger_global(regexp, chat, fecha, id_usuario, id_msj)
        id_regexp = Trigger.confirmar_borrar_trigger(chat.id, regexp, id_msj)
        regexp_sanitizada = html_parser Trigger.regexp_a_str(regexp)

        arr = [[
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Borrar',
                callback_data: "deltrigger:#{id_regexp}:borrar"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Ignorar',
                callback_data: "deltrigger:#{id_regexp}:ignorar"
            )
        ]]

        # Aviso que quieren borrar un gatillo
        fecha = Time.at(fecha, in: @tz.utc_offset)

        texto = fecha.strftime("<code>[%d/%m/%Y %T]</code>\n")
        texto << 'Usuario '
        texto << obtener_enlace_usuario(id_usuario, chat.id,
                                        con_apodo: false) || 'eliminado'
        texto << "(#{id_usuario}) en el chat "
        texto << "#{html_parser(chat&.title || chat&.username)} (#{chat.id}) "
        texto << 'quiere borrar el trigger: '
        texto << " <code>#{regexp_sanitizada}</code>\n"
        msj_log = @tg.send_message(chat_id: @canal, parse_mode: :html, text: texto,
                                   disable_web_page_preview: true,
                                   disable_notification: true)
        id_msj_log = msj_log['result']['message_id'].to_i

        # Mando el trigger al canal de logging
        trigger = Trigger.new(:global, regexp)
        msj_enviado = enviar_trigger(@canal, trigger, id_msj_log)
        id_enviado = msj_enviado['result']['message_id'].to_i

        # Mando tablero con opciones para decidir si borrarlo o no
        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        @tg.send_message(chat_id: @canal, parse_mode: :html,
                         text: "¿Borrar el trigger <code>#{regexp_sanitizada}</code>?",
                         reply_markup: opciones, disable_web_page_preview: true,
                         reply_to_message_id: id_enviado,
                         disable_notification: true)
    end

    # Función para borrar triggers de grupo
    def borrar_trigger(regexp, id_grupo, msj)
        Trigger.borrar_trigger(id_grupo, regexp)
        regexp_str = Trigger.regexp_a_str(regexp)

        # Loggeo
        loggear = "Trigger #{regexp_str} borrado por "
        loggear << "#{msj.from.id} en el chat #{msj.chat.id}"
        @logger.info(loggear)
        # Aviso en grupete
        texto = "Trigger <code>#{html_parser regexp_str}</code> "
        texto << "borrado por #{obtener_enlace_usuario(msj.from.id,
                                                       msj.chat.id) || 'eliminado'} "
        texto << "en #{html_parser(msj.chat&.title || msj.chat&.username)} "
        texto << "(#{msj.chat.id})"
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         disable_web_page_preview: true, text: texto,
                         disable_notification: true)
    end

    def validar_set_trigger(msj, params, grupo)
        unless params && msj.reply_to_message
            texto = '<b>Modo de uso:</b>'
            texto << "\nRespondé a un mensaje con /settrigger <i>trigger</i>"
            texto << "\nPodés tirar una expresión regular"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             reply_to_message_id: msj.message_id, text: texto)
            return
        end

        if params.length > 89 && !DEVS.member?(msj.from.id)
            texto = "Perdón, #{TROESMAS.sample}, pero tu trigger es muy largo."
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        unless (regexp = Trigger.str_a_regexp params)
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "No sirve tu trigger, #{TROESMAS.sample}.")
            return
        end

        Trigger.redis ||= @redis

        if Trigger.existe_trigger?(msj.chat.id, regexp)
            texto = "Ya hay un trigger así, #{TROESMAS.sample}.\n"
            texto << "Borralo con <code>/deltrigger #{html_parser params}</code>"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             reply_to_message_id: msj.message_id, text: texto)
            return
        end

        if grupo == :global && Trigger.temporal?(regexp)
            texto = 'Alguien ya está poniendo un trigger con esa expresión '
            texto << "regular, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        contador = poner_trigger(regexp, msj.reply_to_message, grupo,
                                 msj.from.id, msj.message_id)
        # Si contador era nil es porque era un trigger local o no era un trigger válido
        return if contador.nil?

        confirmar_trigger_global(regexp, msj.chat, msj.date, msj.from.id, contador)
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         text: 'Esperando a que mi senpai acepte el trigger uwu.')
    end
end

class Trigger
    attr_reader :regexp, :caption, :data, :contador, :creador, :fecha

    # id_grupo debe ser un Integer o el Symbol :global
    # regexp debe ser una Regexp
    def initialize(id_grupo, regexp, temp = false)
        @clave = "trigger:#{temp ? 'temp:' : ''}"
        @clave << "#{id_grupo}:#{self.class.regexp_a_str regexp}"

        trigger = self.class.redis.hgetall @clave
        @data = {}
        TIPOS_MMEDIA.each_key { |k| @data[k] = trigger[k.to_s] }

        @caption = trigger['caption']
        @regexp = regexp
        @contador = self.class.redis.hget @clave + ':metadata', 'contador'
        @creador = self.class.redis.hget @clave + ':metadata', 'creador'
        @fecha = Time.at self.class.redis.hget(@clave + ':metadata', 'fecha').to_i
    end

    def aumentar_contador
        self.class.redis.hincrby @clave + ':metadata', 'contador', 1
    end

    # Método que devuelve la fecha del último envío del trigger en un grupo
    # en unix time
    def último_envío(id_grupo)
        self.class.redis.hget(@clave + ':último_envío', id_grupo).to_i
    end

    def actualizar_último_envío(id_grupo)
        self.class.redis.hset @clave + ':último_envío', id_grupo, Time.now.to_i
    end

    # Con esto meto redis en la clase Trigger para no pasarlo a cada rato
    class << self
        attr_accessor :redis
    end

    # Método que pone un trigger, data es un Hash(ruby) por lo que debe tener el
    # mensaje a enviar.
    # El trigger se guarda en un hash(redis) de la forma trigger:id_grupo:regexp
    # Por ejemplo, un trigger se podría llamar trigger:-1000000000000:/hola/
    # Ademas, en el hash se guarda el nombre del método que va a usar para mandar
    # el mensaje.
    # Si el trigger es global, lo añade en claves temporales que despues hay que
    # mover a las claves correspondientes, y devuelve un id para confirmarlo.
    def self.poner_trigger(id_grupo, id_usuario, regexp, data)
        temp = id_grupo == 'global' ? ':temp' : ''
        regexp_str = regexp_a_str(regexp)
        @redis.sadd "triggers#{temp}:#{id_grupo}", regexp_str

        # Nótese que acá es trigger sin s al final
        clave = "trigger#{temp}:#{id_grupo}:#{regexp_str}"
        @redis.hmset(clave, *data)

        clave << ':metadata'
        @redis.mapped_hmset(clave, creador: id_usuario, contador: 0,
                                   chat_origen: id_grupo, fecha: Time.now.to_i)
    end

    # Método que toma un trigger y devuleve un id, así es identificable a la hora de
    # aceptarlo
    def self.confirmar_poner_trigger(id_grupo, regexp, id_msj)
        # Este es un entero con signo de 64 bits así que hay más de 16 trillones de
        # valores posibles
        contador = @redis.incr 'triggers:contador'
        @redis.mapped_hmset("triggers:settrigger:#{contador}",
                            regexp: regexp,
                            id_grupo: id_grupo,
                            id_msj: id_msj)
        contador
    end

    # Ver si existe un temporal
    def self.existe_temporal?(id)
        @redis.exists("triggers:settrigger:#{id}") ||
            @redis.exists("triggers:deltrigger:#{id}")
    end

    # Método que mueve las claves de un trigger temporal a la lista de trigger globales.
    def self.confirmar_trigger(contador)
        hash = @redis.hgetall "triggers:settrigger:#{contador}"
        hash.transform_keys!(&:to_sym)
        @redis.del "triggers:settrigger:#{contador}"
        @redis.srem 'triggers:temp:global', hash[:regexp]
        @redis.sadd 'triggers:global', hash[:regexp]
        @redis.rename("trigger:temp:global:#{hash[:regexp]}",
                      "trigger:global:#{hash[:regexp]}")
        @redis.rename("trigger:temp:global:#{hash[:regexp]}:metadata",
                      "trigger:global:#{hash[:regexp]}:metadata")
        hash[:regexp] = Trigger.str_a_regexp hash[:regexp]
        hash
    end

    # Método que borra un trigger temporal al ser rechazado
    def self.rechazar_trigger(contador)
        hash = @redis.hgetall "triggers:settrigger:#{contador}"
        hash.transform_keys!(&:to_sym)
        @redis.del "triggers:settrigger:#{contador}"
        @redis.srem 'triggers:temp:global', hash[:regexp]
        @redis.del "trigger:temp:global:#{hash[:regexp]}"
        @redis.del "trigger:temp:global:#{hash[:regexp]}:metadata"
        hash[:regexp] = Trigger.str_a_regexp hash[:regexp]
        hash
    end

    # Método que borra un trigger, sus metadatos y su clave en el conjunto de triggers.
    # id_grupo puede ser 'global'
    def self.borrar_trigger(id_grupo, regexp, id_trigger = nil)
        regexp_str = regexp_a_str(regexp)
        @redis.srem "triggers:#{id_grupo}", regexp_str

        # Nótese que acá es trigger sin s al final
        clave = "trigger:#{id_grupo}:#{regexp_str}"
        @redis.del clave

        clave << ':metadata'
        @redis.del clave
        return unless id_trigger

        descartar_temporal id_trigger
    end

    # Método que toma un trigger y devuelve un id, así es identificable a la hora de
    # borrarlo.
    def self.confirmar_borrar_trigger(id_grupo, regexp, id_msj)
        contador = @redis.incr 'triggers:contador'
        @redis.sadd 'triggers:temp:deltrigger', regexp_a_str(regexp)
        @redis.mapped_hmset("triggers:deltrigger:#{contador}",
                            regexp: regexp_a_str(regexp),
                            id_grupo: id_grupo,
                            id_msj: id_msj)
        contador
    end

    # Método que devuelve la regexp de un trigger para borrar.
    def self.obtener_del_trigger_temp(id_trigger)
        hash = @redis.hgetall("triggers:deltrigger:#{id_trigger}")
        hash.transform_keys!(&:to_sym)
        hash[:regexp] = Trigger.str_a_regexp hash[:regexp]
        hash
    end

    # Método que informa si existe un temporal de deltrigger global
    def self.temporal_deltrigger(regexp)
        @redis.sismember('triggers:temp:deltrigger', regexp_a_str(regexp))
    end

    def self.borrar_global_resuelto(regexp)
        @redis.srem('triggers:temp:deltrigger', regexp_a_str(regexp))
    end

    # Método que descarta un temporal de deltrigger global
    def self.descartar_temporal(id_trigger)
        regexp = @redis.hget "triggers:deltrigger:#{id_trigger}", regexp
        @redis.srem 'trigger:temp:deltrigger', regexp
        @redis.del "triggers:deltrigger:#{id_trigger}"
    end

    # Itera sobre el conjunto de triggers tanto globales como de grupo.
    # Los conjuntos se llaman triggers:global y triggers:id_grupo
    def self.triggers(id_grupo)
        @redis.smembers("triggers:#{id_grupo}").shuffle!.each do |exp|
            yield id_grupo, str_a_regexp(exp)
        end
        @redis.smembers('triggers:global').shuffle!.each do |exp|
            yield :global, str_a_regexp(exp)
        end
    end

    def self.existe_trigger?(id_grupo, regexp)
        regexp = regexp_a_str regexp

        @redis.sismember("triggers:#{id_grupo}", regexp) ||
            @redis.sismember('triggers:global', regexp)
    end

    # Devuelve el grupo del trigger, si es que existe, si no nil
    def self.grupo_trigger(id_grupo, regexp)
        regexp = regexp_a_str regexp

        return id_grupo if @redis.sismember("triggers:#{id_grupo}", regexp)
        return :global if @redis.sismember('triggers:global', regexp)

        nil
    end

    # Devuelve los triggers de un grupo
    def self.triggers_grupo_ordenados(id_grupo)
        elementos = @redis.smembers("triggers:#{id_grupo}")
        return nil if elementos.nil?

        elementos.sort
    end

    def self.temporal?(regexp)
        regexp = regexp_a_str regexp
        @redis.sismember 'triggers:temp:global', regexp
    end

    def self.str_a_regexp(str)
        regexp = /#{str}/i
    rescue RegexpError, ArgumentError
        regexp = nil
    ensure
        regexp
    end

    def self.regexp_a_str(regexp)
        regexp.inspect.gsub(%r{/(.*)/i}m, '\\1')
    end
end
