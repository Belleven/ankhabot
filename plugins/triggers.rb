TIPOS_MMEDIA = { text: :send_message,
                 photo: :send_photo,
                 sticker: :send_sticker,
                 audio: :send_audio,
                 voice: :send_voice,
                 video: :send_video,
                 video_note: :send_video_note,
                 document: :send_document }.freeze

class Dankie
    add_handler Handler::Mensaje.new(:chequear_triggers, permitir_editados: false,
                                     ignorar_comandos: true,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:settrigger, :validar_set_trigger,
                                     permitir_params: true,
                                     descripción: 'Agrega un trigger al bot')
    add_handler Handler::Comando.new(:deltrigger, :validar_borrar_trigger,
                                     permitir_params: true,
                                     descripción: 'Borra un trigger')
    add_handler Handler::Comando.new(:triggers, :listar_triggers,
                                     permitir_params: true,
                                     descripción: 'Envía la lista de triggers')
    add_handler Handler::Comando.new(:infotrigger, :enviar_info_trigger,
                                     permitir_params: true,
                                     descripción: 'Envía información del trigger')
    add_handler Handler::Comando.new(:triggered, :triggered,
                                     permitir_params: false,
                                     descripción:  'Muestra que triggers reaccionan'\
                                     ' al mensaje respsondido')
    #     add_handler CallbackQueryHandler.new()

    def chequear_triggers(msj)
        return unless (texto = msj.text || msj.caption)

        Trigger.redis ||= @redis

        # Acá guardo los unix-time de cuando se manda un trigger
        @trigger_flood ||= {}
        @trigger_flood[msj.chat.id] ||= []

        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            next unless regexp =~ texto
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

        return true if diferencia_ahora > 7 # POR AHORA 7 SEGUNDOS, DESPUES DE TESTEAR PONER EN 89

        false
    end

    def incremetar_arr_flood(arr, tiempo)
        arr << tiempo
        arr.shift until arr.size <= 7
    end

    # TODA ESTA FUNCIÓN CREO QUE NO SE USA. BORRAR DESPUES DE VER PARA QUE SE SUPONÍA QUE ERA
    $set_trigger_callbacks = {}
    def triggers(msg)
        case msg

        when Telegram::Bot::Types::CallbackQuery
            # el callback_data es set_trigger:si/no:msg_id
            return unless msg.data.start_with? 'set_trigger'
            return unless $set_trigger_callbacks[msg.message.chat.id]

            response, id = msg.split(':').last(2)

            if response == 'no'
                $set_trigger_callbacks[msg.message.chat.id].delete(id)
            elsif response == 'yes'
                if msg.from.id == $set_trigger_callbacks[msg.message.chat.id][id]&.from.id
                    tmp_h = $set_trigger_callbacks[msg.message.chat.id][id]
                    set_trigger(tmp_h[:regexp], tmp_h[:msj], tmp_h[:user_id], tmp_h[:group_id])
                    $set_trigger_callbacks[msg.message.chat.id].delete(id)
                end
            end
        end
    end

    # POR AHORA ESTÁ PONIENDO TRIGGERS DE GRUPO, ACOMODAR PARA PREGUNTAR SI SE QUIEREN GLOBALES
    def validar_set_trigger(msj, params)
        if !params || !msj.reply_to_message
            text = '<b>Modo de uso:</b>'
            text << "\nRespondé a un mensaje con /settrigger trigger"
            text << "\npodés tirar una expresión regular"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html', text: text)
            return
        end

        unless regexp = Trigger.validar_regexp(params)
            send_message(chat_id: msj.chat.id,
                         text: "No sirve tu trigger, #{TROESMAS.sample}.")
            return
        end

        Trigger.redis ||= @redis

        if Trigger.existe_trigger?(msj.chat.id, regexp)
            texto = "Ya hay un trigger, #{TROESMAS.sample}.\n"
            texto << "Borralo con <pre>/deltrigger #{params}</pre>"
            @tg.send_message chat_id: msj.chat.id, text: text
            return
        end

        poner_trigger(regexp, msj.reply_to_message, msj.chat.id, msj.from.id)
    end

    def validar_borrar_trigger(msj, params)
        unless params
            texto = '<b>Modo de uso:</b>'
            texto << "\nRespondé a un mensaje con /deltrigger trigger"
            texto << "\npodés tirar una expresión regular"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html', text: texto)
            return
        end

        unless regexp_recibida = Trigger.validar_regexp(params)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No sirve tu trigger, #{TROESMAS.sample}.")
            return
        end

        Trigger.redis ||= @redis

        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            next unless regexp_recibida == regexp

            if id_grupo == :global
                @tg.send_message(chat_id: msj.chat.id, text: 'Agregar el código para borrar triggers globales')
                # pedir confirmación en canal público
            elsif id_grupo == msj.chat.id
                borrar_trigger regexp, id_grupo, msj
            end

            break
        end
    end

    def listar_triggers(msj, _params)
        Trigger.redis ||= @redis

        triggers_globales = []
        triggers_locales = []

        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            if id_grupo == msj.chat.id
                triggers_locales << regexp.inspect
            else
                triggers_globales << regexp.inspect
            end
        end

        texto = "<b>Lista de triggers:</b>\n"

        # cuando se haga el coso para desactivar triggers globales,
        # hacer algo para ignorar estas dos líneas
        texto << "\n<b>Globales:</b>"
        triggers_globales.each { |trig| texto << "\n<pre>#{trig}</pre>" }

        texto << "\n<b>Locales:</b>"
        triggers_locales.each { |trig| texto << "\n<pre>#{trig}</pre>" }

        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html', text: texto)
    end

    def enviar_info_trigger(msj, params)
        unless params
            texto = '<b>Modo de uso:</b>'
            texto << "\n<pre>/infotrigger trigger</pre>"
            texto << "\n<pre>trigger</pre> tiene que ser exactamente"
            texto << "la expresión regular que activa al trigger."
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html', text: texto)
            return
        end

        unless regexp_recibida = Trigger.validar_regexp(params)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No sirve tu trigger, #{TROESMAS.sample}.")
            return
        end

        Trigger.redis ||= @redis

        trigger = nil
        id = nil
        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            next unless regexp_recibida == regexp

            trigger = Trigger.new(id_grupo, regexp)
            id = id_grupo
        end

        unless trigger
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                             text: 'No pude encontrar el trigger úwù')
            return
        end
        
        texto = '<b>Info del trigger:</b>'
        texto << "\nRegexp: <code>#{trigger.regexp.inspect}</code>"
        texto << "\nTipo: #{id == :global ? 'global' : 'de grupo'}"
        texto << "\nCreador: #{obtener_enlace_usuario(msj.chat.id, trigger.creador)}"
        texto << "\nTotal de usos: #{trigger.contador}"
        texto << "\nMedia: #{trigger.data.compact.keys.first.to_s}"
        texto << "\nid/valor: <code>#{trigger.data.compact.values.first}</code>"
        texto << "\nCaption: <code>#{trigger.caption}</code>"

        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                         disable_web_page_preview: true, text: texto)


    end

    def triggered(msj)
        unless (texto = msj.reply_to_message&.text || msj.reply_to_message&.caption)
            texto = "Respondele a un mensaje de texto, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html', text: texto)
            return
        end

        Trigger.redis ||= @redis

        enviar = "triggers que matchean el mensaje respondido:\n"
        emparejó = false
        Trigger.triggers(msj.chat.id) do |id_grupo, regexp|
            next unless (match = regexp.match texto)

            enviar << "\n<pre>#{html_parser(regexp.inspect)}</pre>\n"
            línea = html_parser(match.string)
            línea.gsub!(match[0], "<b>#{html_parser match[0]}</b>")
            enviar << línea << "\n"
            emparejó = true
        end
        enviar = emparejó ? enviar : 'Ningún trigger matchea con este mensaje'

        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html', text: enviar)


    end

    private

    # Función que envía un trigger al grupo
    # recibe el id del grupo, y un objeto Trigger para enviar
    def enviar_trigger(id_grupo, trigger)
        TIPOS_MMEDIA.each do |media, send_media|
            next unless trigger.data[media]

            # espero que esta línea mágica funcione
            @tg.public_send(send_media, chat_id: id_grupo,
                                        caption: trigger.caption,
                                        media => trigger.data[media])
            trigger.aumentar_contador
            @logger.info("Trigger enviado en #{id_grupo}", al_canal: false)
        end
    end

    # Función para poner triggers de grupo o globales
    def poner_trigger(regexp, msj, id_grupo, id_usuario)
        data = {}
        data[:caption] = msj.caption

        if !msj.photo.empty?
            data[:photo] = msj.photo.first.file_id
        elsif msj.text
            data[:text] = msj.text
        else
            (TIPOS_MMEDIA.keys - %i[photo text]).each do |media|
                data[media] = msj.send(media).file_id if msj.send(media)
            end
        end

        Trigger.poner_trigger(id_grupo, id_usuario, regexp, data)

        texto = 'Trigger añadido por '
        texto << "#{obtener_enlace_usuario(msj.chat.id, id_usuario)} "
        texto << "en #{html_parser(msj.chat&.title || msj.chat&.username)} "
        texto << "(#{msj.chat.id})\nTrigger: "
        texto << "<pre>#{html_parser(regexp.inspect)}</pre>"

        @logger.info(texto, al_canal: id_grupo == 'global')

        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                         disable_web_page_preview: true, text: texto)
    end

    # Función para borrar triggers de grupo o globales
    def borrar_trigger(regexp, id_grupo, msj)
        Trigger.borrar_trigger(id_grupo, regexp)

        texto = 'Trigger borrado por '
        texto << "#{obtener_enlace_usuario(msj.chat.id, msj.from.id)} "
        texto << "en #{html_parser(msj.chat&.title || msj.chat&.username)} "
        texto << "(#{msj.chat.id})\nTrigger: "
        texto << "<pre>#{html_parser(regexp.inspect)}</pre>"

        @logger.info(texto, al_canal: id_grupo == 'global')

        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                         disable_web_page_preview: true, text: texto)
    end
end

class Trigger
    attr_reader :regexp, :caption, :data, :contador, :creador

    # id_grupo debe ser un Integer o el Symbol :global
    # regexp debe ser una Regexp
    def initialize(id_grupo, regexp)
        @clave = "trigger:#{id_grupo}:#{regexp.inspect}"

        trigger = self.class.redis.hgetall @clave

        @data = {}
        TIPOS_MMEDIA.each_key { |k| @data[k] = trigger[k.to_s] }

        @caption = trigger['caption']
        @regexp = regexp
        @contador = self.class.redis.hget @clave + ':metadata', 'contador'
        @creador = self.class.redis.hget @clave + ':metadata', 'creador'
    end

    def aumentar_contador
        self.class.redis.hincrby @clave + ':metadata', 'contador', 1
    end

    # Con esto meto redis en la clase Trigger para no pasarlo a cada rato
    class << self
        attr_accessor :redis
    end

    # Método que pone un trigger, data es un Hash(ruby) con lo que debe tener el mensaje a enviar
    # El trigger se guarda en un hash(redis) de la forma trigger:id_grupo:regexp
    # Por ejemplo, un trigger se podría llamar trigger:-1000000000000:/hola/
    # Ademas, en el hash se guarda el nombre del método que va a usar para mandar el mensaje.
    def self.poner_trigger(id_grupo, id_usuario, regexp, data)
        @redis.sadd "triggers:#{id_grupo}", regexp.inspect
        @redis.hmset("trigger:#{id_grupo}:#{regexp.inspect}", *data)
        @redis.mapped_hmset("trigger:#{id_grupo}:#{regexp.inspect}:metadata",
                            creador: id_usuario, contador: 0)
    end

    # Método que borra un trigger, sus metadatos y su clave en el conjunto de triggers.
    # id_grupo puede ser 'global'
    def self.borrar_trigger(id_grupo, regexp)
        @redis.srem "triggers:#{id_grupo}", regexp.inspect
        @redis.del "trigger:#{id_grupo}:#{regexp.inspect}"
        @redis.del "trigger:#{id_grupo}:#{regexp.inspect}:metadata"
    end

    # Itera sobre el conjunto de triggers tanto globales como de grupo.
    # Los conjuntos se llaman triggers:global y triggers:id_grupo
    # Cada conjunto guarda el trigger en la forma /regexp/, por lo que hay
    # que sacarle las barritas antes de yieldearlo.
    def self.triggers(id_grupo)
        @redis.smembers("triggers:#{id_grupo}").shuffle!.each do |exp|
            yield id_grupo, /#{exp.gsub(%r{/(.*)/i}, "\\1")}/i
        end
        @redis.smembers('triggers:global').shuffle!.each do |exp|
            yield :global, /#{exp.gsub(%r{/(.*)/i}, "\\1")}/i
        end

    end

    def self.existe_trigger?(id_grupo, trigger)
        triggers(id_grupo) do |_id, exp|
            return true if trigger == exp
        end
        false
    end

    def self.validar_regexp(str)
        regexp = /#{str}/i
    rescue RegexpError
        regexp = nil
    ensure
        regexp
    end




end
