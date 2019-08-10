require_relative 'versión.rb'
require_relative 'handlers.rb'
require_relative 'dankie_logger.rb'
require_relative 'telegram.rb'
require_relative 'images.rb'
require_relative 'last_fm_parser.rb'
require_relative 'semáforo.rb'
require 'redis'
require 'tzinfo'
require 'set'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user
    TROESMAS = File.readlines('resources/troesmas.txt', encoding: 'UTF-8').map(&:chomp).freeze
    REKT = File.readlines('resources/rekt.txt', encoding: 'UTF-8').map(&:chomp).freeze
    CALLEFUEGOS = File.readlines('resources/callefuegos.txt').map(&:chomp).freeze
    DEUS_VULT = File.readlines('resources/deus.txt').map(&:chomp).freeze
    DEVS = Set.new([240_524_686, # Luke
                    98_631_116,  # M
                    263_078_683, # Santi
                    267_832_653, # Galerazo
                    196_535_916, # Ale
                    298_088_760, # Mel
                    36_557_595   # Bruno
    ]).freeze

    def self.add_handler(handler)
        @handlers ||= []
        @handlers << handler
    end

    def self.handlers
        @handlers ||= []
    end

    # Creo que esto es un dispatch si entendí bien
    def dispatch(msj)
        self.class.handlers.each do |handler|
            handler.check_message(self, msj)
        end
    end

    # Recibe un Hash con los datos de config.yml
    def initialize(args)
        @logger = DankieLogger.new args[:canal_logging], args[:tg_token]
        @tg = TelegramAPI.new args[:tg_token], @logger
        @redis = Redis.new port: args[:redis_port], host: args[:redis_host], password: args[:redis_pass]
        @img = ImageSearcher.new args[:google_image_key], args[:google_image_cx]
        @user = Telegram::Bot::Types::User.new @tg.get_me['result']
        @lastFM = LastFMParser.new args[:last_fm_api]
        @tz = TZInfo::Timezone.get args[:timezone]
    end

    def run
        # Ciclo principal
        @tg.client.listen do |msj|
            # Chequeo que msj sea un mensaje válido, y que quien lo manda no
            # esté bloqueado por el bot, o restringido del bot en el chat
            next unless msj&.from&.id
            next if @redis.sismember('lista_negra:global', msj.from.id.to_s)
            next if msj.is_a?(Telegram::Bot::Types::Message) &&
                    @redis.sismember("lista_negra:#{msj.chat.id}", msj.from.id.to_s)

            # Le paso el mensaje a los handlers correspondientes
            dispatch(msj)

        rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
            begin
                texto, backtrace = @logger.excepcion_texto(e)
                @logger.log Logger::ERROR, texto, al_canal: true, backtrace: backtrace
            rescue StandardError => e
                @logger.log Logger::FATAL, 'EXCEPCIÓN LEYENDO LA EXCEPCIÓN', al_canal: true
            end
            retry

        rescue StandardError => e

            begin
                texto, backtrace = @logger.excepcion_texto(e)
                @logger.log Logger::FATAL, texto, al_canal: true, backtrace: backtrace
            rescue StandardError => e
                @logger.log Logger::FATAL, 'EXCEPCIÓN LEYENDO LA EXCEPCIÓN', al_canal: true
            end

            # Sacar este raise cuando el bot deje de ser testeadísimo
            # lo puse porque luke dice que es pesado cuando se pone a mandar
            # errores en el grupete.
            raise
        end
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @handlers.each do |handler|
            next unless handler.is_a? Handler::Comando

            yield handler.cmd, handler.descripción if handler.descripción
        end
    end

    # El to_s es al pedo, si lo que le pasamos no es un string entonces
    # tiene que saltar el error para que veamos bien qué carajo le estamos pasando
    # Hecho así solo recorre una vez el string en vez de 3.
    def html_parser(texto)
        html_dicc = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;' }
        texto.gsub(/&|<|>|\"/, html_dicc)
    end

    def get_command(msj)
        cmd = _parse_command(msj)
        cmd[:command]
    end

    def get_command_params(msj)
        cmd = _parse_command(msj)
        cmd[:params]
    end

    private

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def _parse_command(msj)
        unless (text = msj.text || msj.caption)
            return { command: nil, params: nil }
        end

        command = nil
        params = nil

        if text.start_with? '/' # "/cmd params" o "/cmd@bot params"
            command, params = text.split ' ', 2
            command.downcase!
            command.gsub!(%r{^/([a-z]+)(@#{@user.username.downcase})?}, '\\1')

        elsif ['!', '>', '$'].include? text[0] # "!cmd params" o ">cmd params"
            command, params = text[1..-1].split ' ', 2
            command.downcase!
        else
            arr = text.split(' ', 3) # ["user", "comando", "params"]
            arr.first.downcase!
            if arr.first.casecmp(@user.username.sub(/...$/, '').downcase).zero?
                command = arr[1]&.downcase.to_sym
                params = arr[2]

            elsif msj.reply_to_message&.from&.id == @user.id # responde al bot
                command, params = text.split ' ', 2
                command.downcase!
            end
        end

        { command: command&.to_sym, params: params }
    end

    def obtener_enlace_usuario(id_chat, id_usuario)
        usuario = @tg.get_chat_member(chat_id: id_chat, user_id: id_usuario)
        usuario = Telegram::Bot::Types::ChatMember.new(usuario['result']).user
        enlace_usuario = crear_enlace(usuario)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        enlace_usuario = nil
        @logger.error(e)
    ensure
        return enlace_usuario || 'ay no c (' + usuario_id.to_s + ')'
    end

    def crear_enlace(usuario)
        if usuario.username
            "<a href='https://telegram.me/#{usuario.username}'>" \
                "#{usuario.username}</a>"
        elsif !usuario.first_name.empty?
            "<a href='tg://user?id=#{usuario.id}'>" \
                "#{html_parser(usuario.first_name)}</a>"
        else
            'ay no c (' + usuario.id.to_s + ')'
        end
    end

    def natural(numero)
        if numero.length < 25
            begin
                num = Integer(numero)
            rescue StandardError
                return false
            end

            return num if num > 0
        end

        false
    end

    def validar_grupo(type, chat_id, mensaje_id)
        if type == 'private'
            @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id,
                             text: 'Esto solo funciona en grupetes')
            return false

        elsif type == 'channel'
            return false

        end

        true
    end

    def validar_desarrollador(usuario_id, chat_id, mensaje_id, _text = nil, _id = nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(usuario_id)
            @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id,
                             text: 'Vos no podés usar esto pa')
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
                @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id, text: text)
            end
            return false
        end

        true
    end

    def grupo_del_msj(msj)
        if msj.chat.title.nil?
            msj.chat.id.to_s
        else
            msj.chat.title + ' (' + msj.chat.id.to_s + ')'
        end
    end

    def cambiar_claves_supergrupo(vieja_id, nueva_id, texto_antes = '', texto_después = '')
        vieja_clave = texto_antes + vieja_id.to_s + texto_después
        nueva_clave = texto_antes + nueva_id.to_s + texto_después

        @redis.rename(vieja_clave, nueva_clave) if @redis.exists(vieja_clave)
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

                    otro_texto = texto[(entidad.offset + entidad.length)..-1].strip
                    otro_texto = nil if otro_texto.empty?

                    # Me fijo si esa entidad efectivamente era un alias
                    if entidad.type == 'mention'
                        # La entidad arranca con un @, por eso el + 1
                        alias_usuario = texto[(entidad.offset + 1)..(entidad.offset + entidad.length - 1)].strip
                        id_afectada = obtener_id_de_alias(alias_usuario)
                    # Me fijo si esa entidad efectivamente era una mención de usuario sin alias
                    elsif entidad.type == 'text_mention'
                        id_afectada = entidad.user.id
                    end
                end
            end

            # Si no logré nada con las entidades, entonces chequeo si me pasaron una id como texto
            id_afectada, otro_texto = id_numérica_y_otro_texto(args_mensaje) if id_afectada.nil?
            # Si no conseguí ninguna id, entonces todo el argumento es "otro_texto"
            otro_texto = args_mensaje if id_afectada.nil?

        # Si está respondiendo a un mensaje y no se obtuvo un id de los argumentos
        # toma el id de ese miembro para ser afectado. Notar que el otro texto
        # es obtenido en el if anterior (si existe)
        elsif msj.reply_to_message && id_afectada.nil?
            id_afectada = msj.reply_to_message.from.id
        end

        [id_afectada, alias_usuario, otro_texto]
    end

    def id_numérica_y_otro_texto(args_mensaje)
        lista_palabras = args_mensaje.split
        primer_palabra = natural(lista_palabras.first)

        if primer_palabra
            [primer_palabra, lista_palabras[1..-1].join(' ')]
        else
            [nil, nil]
        end
    end

    # Trata de obtener un miembro de chat, y si no lo consigue
    # manda un mensaje de error.
    def obtener_miembro(msj, id_usuario)
        miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: id_usuario)['result']
        Telegram::Bot::Types::ChatMember.new(miembro)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /USER_ID_INVALID/
            @logger.log(Logger::ERROR, 'Me dieron una id inválida en ' + grupo_del_msj(msj))
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Disculpame pero no puedo reconocer esta id: #{id_usuario}. "\
                                   'O es inválida, o es de alguien que nunca estuvo en el chat.',
                             reply_to_message_id: msj.message_id)
        else
            raise
        end

        nil
    end
end
