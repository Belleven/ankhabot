require 'concurrent-ruby'

TIPOS_MMEDIA = { text: :send_message,
                 photo: :send_photo,
                 sticker: :send_sticker,
                 audio: :send_audio,
                 voice: :send_voice,
                 video: :send_video,
                 video_note: :send_video_note,
                 document: :send_document }.freeze

class Dankie
    add_handler Handler::Mensaje.new(:chequear_triggers,
                                     permitir_editados: false,
                                     ignorar_comandos: true,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:settrigger, :validar_poner_trigger_local,
                                     permitir_params: true,
                                     descripción: 'Agrega un trigger al bot')
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
                                     #                                     parámetros: params_triggers,
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

        if $hilo_triggers[:hora].value > 0 && (Time.now.to_i - $hilo_triggers[:hora].value) > 10
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
            t1 = Time.now
            match = regexp =~ texto
            t2 = Time.now

            # Si el trigger tardó mucho en procesar, lo borro.
            if (t2.to_f - t1.to_f) > 0.500 # 500ms
                Trigger.borrar_trigger(id_grupo, regexp)
                texto = 'Trigger '
                texto << "<code>#{html_parser Trigger.regexp_a_str(regexp)}</code> "
                texto << 'borrado en el grupo '
                texto << "#{html_parser msj.chat&.title} (#{msj.chat.id}) "
                texto << "por ralentizar al bot.\n"
                texto << "Tiempo de procesado: <pre>#{t2.to_f - t1.to_f}s</pre>"
                @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto)
                @tg.send_message(chat_id: @canal, parse_mode: :html, text: texto)
                next
            end

            next unless match

            next unless chequear_flood(@trigger_flood[msj.chat.id])

            incremetar_arr_flood(@trigger_flood[msj.chat.id], Time.now)

            trigger = Trigger.new(id_grupo, regexp)
            enviar_trigger(msj.chat.id, trigger)
        end
    end

    # MOVER ESTAS DOS A LIB/DANKIE.RB ????????????

    # Función que recibe un arreglo de Time o unix-time y verifica si se mandaron
    # muchos mensajes seguidos. Devuelve true o false
    def chequear_flood(arr)
        return true if arr.size.between? 0, 1

        promedio = 0
        arr.each { |i| promedio += i.to_r }
        promedio /= arr.size
        diferencia_ahora = Time.now.to_r - promedio

        # POR AHORA 20 SEGUNDOS, DESPUES DE TESTEAR PONER EN 89
        diferencia_ahora > 20
    end

    def incremetar_arr_flood(arr, tiempo)
        arr << tiempo
        arr.shift until arr.size <= 7
    end

    def validar_poner_trigger_local(msj, params)
        validar_set_trigger(msj, params, :local)
    end

    def validar_poner_trigger_global(msj, params)
        validar_set_trigger(msj, params, :global)
    end

    def callback_set_trigger_global(callback)
        # valido usuario
        return unless DEVS.member? callback.from.id

        match = callback.data.match(/settrigger:(?<id_regexp>\d+):(?<acción>.+)/)

        Trigger.redis ||= @redis

        case match[:acción]
        when 'confirmar'
            temp = Trigger.confirmar_trigger match[:id_regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> confirmado por #{callback.from.id}."
        when 'rechazar'
            temp = Trigger.rechazar_trigger match[:id_regexp]
            texto = "Trrigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> rechazado por #{callback.from.id}."
        end

        @tg.answer_callback_query(callback_query_id: callback.id)
        @tg.edit_message_text(chat_id: callback.message.chat.id,
                              parse_mode: :html, text: texto,
                              message_id: callback.message.message_id)
        texto = 'Trigger <code>'
        texto << (html_parser Trigger.regexp_a_str(temp[:regexp])).to_s
        texto << "</code> #{match[:acción] == 'confirmar' ? 'aceptado' : 'rechazado'}."
        @tg.send_message(chat_id: temp[:id_grupo], parse_mode: :html,
                         text: texto)
    rescue Telegram::Bot::Exceptions::ResponseError
        puts 'no logear esto'
    end

    def callback_del_trigger_global(callback)
        # valido usuario
        return unless DEVS.member? callback.from.id

        match = callback.data.match(/deltrigger:(?<id_regexp>\d+):(?<acción>.+)/)

        Trigger.redis ||= @redis
        temp = Trigger.obtener_del_trigger_temp match[:id_regexp]

        case match[:acción]
        when 'borrar'
            Trigger.borrar_trigger :global, temp[:regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << "</code> borrado por #{callback.from.id}."
        when 'ignorar'
            Trigger.descartar_temporal match[:id_regexp]
            texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(temp[:regexp])}"
            texto << '</code> no fue borrado.'
        end

        @tg.answer_callback_query(callback_query_id: callback.id)
        @tg.edit_message_text(chat_id: callback.message.chat.id,
                              parse_mode: :html, text: texto,
                              message_id: callback.message.message_id)
        texto = 'Trigger <code>'
        texto << (html_parser Trigger.regexp_a_str(temp[:regexp])).to_s
        texto << "</code> #{match[:acción] == 'borrar' ? 'borrado' : 'no borrado'}."
        @tg.send_message(chat_id: temp[:id_grupo], parse_mode: :html,
                         text: texto)
    rescue Telegram::Bot::Exceptions::ResponseError
        puts 'no logear esto'
    end

    def validar_borrar_trigger(msj, params)
        unless params
            texto = '<b>Modo de uso:</b>'
            texto << "\nRespondé a un mensaje con /deltrigger trigger"
            texto << "\npodés tirar una expresión regular"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        unless (regexp_recibida = Trigger.str_a_regexp params)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No sirve tu trigger, #{TROESMAS.sample}.",
                             reply_to_message_id: msj.message_id)
            return
        end

        Trigger.redis ||= @redis

        encontrado = false
        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            next unless regexp_recibida == regexp

            encontrado = true

            if id_grupo == :global
                confirmar_borrar_trigger_global(regexp, msj.chat, msj.from.id)
            elsif id_grupo == msj.chat.id
                borrar_trigger regexp, id_grupo, msj
            end

            break
        end

        unless encontrado
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No encontré el trigger, #{TROESMAS.sample}.\n"\
                                   "fijate en /triggers@#{@user.username}.",
                             reply_to_message_id: msj.message_id)
        end
    end

    def listar_triggers(msj, _params)
        Trigger.redis ||= @redis

        triggers_globales = []
        triggers_locales = []

        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            if id_grupo == msj.chat.id
                triggers_locales << Trigger.regexp_a_str(regexp)
            else
                triggers_globales << Trigger.regexp_a_str(regexp)
            end
        end

        título = "<b>Lista de triggers</b> <i>(#{Time.now.strftime('%d/%m/%Y %T')})</i>:"
        hay_elementos = false
        contador = 0
        arr = [título.to_s]

        unless triggers_locales.empty?
            hay_elementos = true
            arr.first << "\n<b>Locales:</b>"
        end
        triggers_locales.each do |trig|
            if contador == 30 || arr.last.size >= 1000
                arr << título.to_s
                arr.last << "\n<b>Locales:</b>"
                contador = 0
            end
            arr.last << "\n<pre> - #{html_parser trig}</pre>"
            contador += 1
        end

        # cuando se haga el coso para desactivar triggers globales,
        # hacer algo para ignorar estos dos bloques
        unless triggers_globales.empty?
            hay_elementos = true
            arr.last << "\n<b>Globales:</b>"
        end
        triggers_globales.each do |trig|
            if contador == 30 || arr.last.size >= 1000
                arr << título.to_s
                arr.last << "\n<b>Globales:</b>"
                contador = 0
            end
            arr.last << "\n<pre> - #{html_parser trig}</pre>"
            contador += 1
        end

        # armo botonera y envío
        opciones = armar_botonera 0, arr.size, msj.from.id

        respuesta = @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                                     reply_markup: opciones,
                                     text: if hay_elementos
                                               arr.first
                                           else
                                               'No hay triggers en este grupo u.u'
                                           end)
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
        texto << "\nCreador: #{enlace_usuario_id(trigger.creador, msj.chat.id)}"
        texto << "\nTotal de usos: #{trigger.contador}"
        texto << "\nAñadido: <i>#{trigger.fecha.strftime('%d/%m/%Y %T')}</i>"

        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         disable_web_page_preview: true, text: texto)
    end

    def triggered(msj)
        unless (texto = msj.reply_to_message&.text || msj.reply_to_message&.caption)
            texto = "Respondele a un mensaje de texto, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: msj.message_id)
            return
        end

        Trigger.redis ||= @redis

        enviar = "triggers que matchean el mensaje respondido:\n"
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

    private

    # Función que envía un trigger al grupo
    # recibe el id del grupo, y un objeto Trigger para enviar
    def enviar_trigger(id_grupo, trigger)
        TIPOS_MMEDIA.each do |media, send_media|
            next unless trigger.data[media]

            # espero que esta línea mágica funcione
            resp = @tg.public_send(send_media, chat_id: id_grupo,
                                               caption: trigger.caption,
                                               media => trigger.data[media])
            trigger.aumentar_contador
            break unless resp['ok']

            añadir_a_cola_spam(id_grupo, resp.dig('result', 'message_id').to_i)
            @logger.info("Trigger enviado en #{id_grupo}", al_canal: false)
        end
    end

    # Función para poner triggers de grupo o globales
    def poner_trigger(regexp, msj, id_grupo, id_usuario, global = false)
        data = {:caption => msj.caption}

        if !msj.photo.empty?
            data[:photo] = msj.photo.first.file_id
        elsif msj.text
            data[:text] = msj.text
        else
            media = nil
            (TIPOS_MMEDIA.keys - %i[photo text]).each do |media|
                data[media], media = msj.send(media).file_id, media if msj.send(media)
            end
        end

        # Si el mensaje no contenía algo que pueda ser un trigger, aviso
        if media.nil?
            texto = "Ese tipo de mensaje no está soportado "
            texto << "como trigger, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: texto)
            return nil
        end

        i = nil
        if global
            Trigger.poner_trigger('global', id_usuario, regexp, data)
            i = Trigger.confirmar_poner_trigger(msj.chat.id, regexp)
        else
            Trigger.poner_trigger(id_grupo, id_usuario, regexp, data)
        end

        texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(regexp)}</code> "
        texto << "añadido por #{enlace_usuario_id(id_usuario, msj.chat.id)} "
        texto << "en #{html_parser(msj.chat&.title || msj.chat&.username)} "
        texto << "(#{msj.chat.id})"

        @logger.info(texto, al_canal: global)

        unless global
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             reply_to_message_id: msj.message_id,
                             disable_web_page_preview: true)
        end
        i
    end

    # Función para enviar un mensaje de logging y aceptar o rechazar triggers
    def confirmar_trigger_global(regexp, msj, id_grupo, id_usuario, id_regexp)
        texto = "Usuario #{enlace_usuario_id id_usuario, id_grupo} en el chat "
        texto << "#{html_parser(msj.chat&.title || msj.chat&.username)} "
        texto << 'quiere añadir trigger: '
        texto << "<code>#{html_parser Trigger.regexp_a_str(regexp)}</code>\n"
        texto << 'Mensaje:'
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

        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        @tg.send_message(chat_id: @canal, parse_mode: :html, text: texto,
                         reply_markup: opciones, disable_web_page_preview: true)
        trigger = Trigger.new(regexp, :global, true)
        enviar_trigger(@canal, trigger)
    end

    # Función para enviar un mensaje de logging y confirmar si se borra un trigger
    def confirmar_borrar_trigger_global(regexp, chat, id_usuario)
        id_regexp = Trigger.confirmar_borrar_trigger(chat.id, regexp)

        texto = "Usuario #{enlace_usuario_id id_usuario, chat.id} en el chat "
        texto << "#{html_parser(chat&.title || chat&.username)} "
        texto << 'quiere borrar trigger: '
        texto << "<code>#{html_parser Trigger.regexp_a_str(regexp)}</code>\n"
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

        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        @tg.send_message(chat_id: @canal, parse_mode: :html, text: texto,
                         reply_markup: opciones, disable_web_page_preview: true)
    end

    # Función para borrar triggers de grupo o globales
    def borrar_trigger(regexp, id_grupo, msj)
        Trigger.borrar_trigger(id_grupo, regexp)

        texto = "Trigger <code>#{html_parser Trigger.regexp_a_str(regexp)}</code> "
        texto << "borrado por #{enlace_usuario_id(msj.from.id, msj.chat.id)} "
        texto << "en #{html_parser(msj.chat&.title || msj.chat&.username)} "
        texto << "(#{msj.chat.id})"

        @logger.info(texto, al_canal: id_grupo == 'global')

        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         disable_web_page_preview: true, text: texto)
    end

    def validar_set_trigger(msj, params, tipo)
        if !params || !msj.reply_to_message
            texto = '<b>Modo de uso:</b>'
            texto << "\nRespondé a un mensaje con /settrigger trigger"
            texto << "\npodés tirar una expresión regular"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             reply_to_message_id: msj.message_id, text: texto)
            return
        end

        if params.length > 89 && !DEVS.member?(msj.from.id)
            texto = "Perdón, #{TROESMAS.sample}, pero tu trigger es muy largo."
            @tg.send_message(chat_id: msj.chat.id, text: texto,
                             reply_to_message_id: message_id)
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

        if tipo == :global && Trigger.temporal?(regexp)
            texto = 'Alguien ya está poniendo un trigger con esa expresión '
            texto << "regular, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             reply_to_message_id: msj.message_id, text: texto)
            return
        end

        i = poner_trigger(regexp, msj.reply_to_message, msj.chat.id,
                          msj.from.id, tipo == :global)

        if tipo == :global
            confirmar_trigger_global(regexp, msj.reply_to_message,
                                     msj.chat.id, msj.from.id, i)
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             reply_to_message_id: msj.message_id,
                             text: 'Esperando a que mi senpai acepte el trigger uwu.')

        end
    end
end

class Trigger
    attr_reader :regexp, :caption, :data, :contador, :creador, :fecha

    # id_grupo debe ser un Integer o el Symbol :global
    # regexp debe ser una Regexp
    def initialize(id_grupo, regexp, temp = false)
        @clave = "trigger:#{temp ? 'temp:' : ''}"
        @clave << "#{id_grupo}:#{Trigger.regexp_a_str regexp}"

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

    # Con esto meto redis en la clase Trigger para no pasarlo a cada rato
    class << self
        attr_accessor :redis
    end

    # Método que pone un trigger, data es un Hash(ruby) con lo que debe tener el
    # mensaje a enviar.
    # El trigger se guarda en un hash(redis) de la forma trigger:id_grupo:regexp
    # Por ejemplo, un trigger se podría llamar trigger:-1000000000000:/hola/
    # Ademas, en el hash se guarda el nombre del método que va a usar para mandar
    # el mensaje.
    # Si el trigger es global, lo añade en claves temporales que despues hay que
    # mover a las claves correspondientes, y devuelve un id para confirmar el trigger.
    def self.poner_trigger(id_grupo, id_usuario, regexp, data)
        temp = id_grupo == 'global' ? ':temp' : ''
        @redis.sadd "triggers#{temp}:#{id_grupo}", regexp_a_str(regexp)
        @redis.hmset("trigger#{temp}:#{id_grupo}:#{regexp_a_str regexp}", *data)
        @redis.mapped_hmset("trigger#{temp}:#{id_grupo}:#{regexp_a_str regexp}:metadata",
                            creador: id_usuario, contador: 0,
                            chat_origen: id_grupo,
                            fecha: Time.now.to_i)
    end

    # Método que toma un trigger y devuleve n id, así es identificable a la hora de
    # aceptarlo
    def self.confirmar_poner_trigger(id_grupo, regexp)
        i = @redis.incr 'triggers:contador'
        @redis.mapped_hmset("triggers:settrigger:#{i}", regexp: regexp_a_str(regexp),
                                                        id_grupo: id_grupo)
        i
    end

    # Método que mueve las claves de un trigger temporal a la lista de trigger globales.
    def self.confirmar_trigger(i)
        hash = @redis.hgetall "triggers:settrigger:#{i}"
        hash.transform_keys!(&:to_sym)
        @redis.del "triggers:settrigger:#{i}"
        @redis.srem 'triggers:temp:global', hash[:regexp]
        @redis.sadd 'triggers:global', hash[:regexp]
        @redis.rename "trigger:temp:global:#{hash[:regexp]}", "trigger:global:#{hash[:regexp]}"
        @redis.rename("trigger:temp:global:#{hash[:regexp]}:metadata",
                      "trigger:global:#{hash[:regexp]}:metadata")
        hash[:regexp] = Trigger.str_a_regexp hash[:regexp]
        hash
    end

    # Método que borra un trigger temporal al ser rechazado
    def self.rechazar_trigger(i)
        hash = @redis.hgetall "triggers:settrigger:#{i}"
        hash.transform_keys!(&:to_sym)
        @redis.del "triggers:settrigger:#{i}"
        @redis.srem 'triggers:temp:global', hash[:regexp]
        @redis.del "trigger:temp:global:#{hash[:regexp]}"
        @redis.del "trigger:temp:global:#{hash[:regexp]}:metadata"
        hash[:regexp] = Trigger.str_a_regexp hash[:regexp]
        hash
    end

    # Método que borra un trigger, sus metadatos y su clave en el conjunto de triggers.
    # id_grupo puede ser 'global'
    def self.borrar_trigger(id_grupo, regexp)
        @redis.srem "triggers:#{id_grupo}", regexp_a_str(regexp)
        @redis.del "trigger:#{id_grupo}:#{regexp_a_str regexp}"
        @redis.del "trigger:#{id_grupo}:#{regexp_a_str regexp}:metadata"
        return unless id_grupo == :global

        @redis.del "triggers:deltrigger:#{id_grupo}"
    end

    # Método que toma un trigger y devuelve un id, así es identificable a la hora de
    # borrarlo.
    def self.confirmar_borrar_trigger(id_grupo, regexp)
        i = @redis.incr 'triggers:contador'
        @redis.mapped_hmset("triggers:deltrigger:#{i}", regexp: regexp_a_str(regexp),
                                                        id_grupo: id_grupo)
        i
    end

    # Método que devuelve la regexp de un trigger para borrar.
    def self.obtener_del_trigger_temp(id_trigger)
        hash = @redis.hgetall("triggers:deltrigger:#{id_trigger}")
        hash.transform_keys!(&:to_sym)
        hash[:regexp] = Trigger.str_a_regexp hash[:regexp]
        hash
    end

    def self.descartar_temporal(id_trigger)
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
