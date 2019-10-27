require_relative 'versión.rb'
require_relative 'handlers.rb'
require_relative 'logger.rb'
require_relative 'telegram.rb'
require_relative 'images.rb'
require_relative 'last_fm_parser.rb'
require_relative 'semáforo.rb'
require_relative 'botoneras.rb'
require 'redis'
require 'tzinfo'
require 'set'
require 'securerandom'
require 'ruby_reddit_api'
require 'cgi'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user
    TROESMAS = File.readlines('resources/troesmas.txt', encoding: 'UTF-8').map(&:chomp)
    TROESMAS.freeze
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
        @comandos ||= {}
        @handlers ||= []

        if handler.is_a? Handler::Comando
            @comandos[handler.cmd] = handler
        else
            @handlers << handler
        end
    end

    def self.handlers
        @handlers ||= []
    end

    def self.comandos
        @comandos ||= {}
    end

    # Handler de las botoneras de lista, lo meto acá porque no se donde mas ponerlo
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')

    # Creo que esto es un dispatch si entendí bien
    def dispatch(msj)
        # Handlers generales, no los de comando si no los de mensajes/eventos de chat
        self.class.handlers.each do |handler|
            handler.ejecutar(self, msj) if handler.verificar(self, msj)
        end

        # Handlers de comando
        return unless msj.is_a? Telegram::Bot::Types::Message

        self.class.comandos[get_command(msj)]&.ejecutar(self, msj)
    end

    # Recibe un Hash con los datos de config.yml
    def initialize(args)
        @canal = args[:canal_logging]
        # Tanto tg como dankielogger usan un cliente para mandar mensajes
        # Y además tg usa un logger
        logger = Logger.new $stderr
        @logger = DankieLogger.new logger, @canal
        @tg = TelegramAPI.new args[:tg_token], @logger
        @logger.inicializar_cliente @tg.client

        @redis = Redis.new port: args[:redis_port], host: args[:redis_host],
                           password: args[:redis_pass]
        @img = ImageSearcher.new args[:google_image_key], args[:google_image_cx],
                                 args[:google_image_gl], @logger
        @user = Telegram::Bot::Types::User.new @tg.get_me['result']
        @lastfm = LastFM::Api.new args[:last_fm_api]
        @tz = TZInfo::Timezone.get args[:timezone]
        @redditApi = Reddit::Api.new
    end

    def run
        # Ciclo principal
        @tg.client.listen do |msj|
            # Si se cerró una encuesta, no hago nada más que loggear
            if msj.is_a?(Telegram::Bot::Types::Poll)
                información = 'Se acaba de cerrar esta encuesta:'
                agregar_encuesta(información, msj, 1, false)
                @logger.info información
                next
            end

            # Chequeo que msj sea un mensaje válido, y que quien lo manda no
            # esté bloqueado por el bot, o restringido del bot en el chat
            next unless msj&.from&.id
            next if @redis.sismember('lista_negra:global', msj.from.id.to_s)
            next if msj.is_a?(Telegram::Bot::Types::Message) &&
                    @redis.sismember("lista_negra:#{msj.chat.id}", msj.from.id.to_s)

            # Le paso el mensaje a los handlers correspondientes
            dispatch(msj)

        rescue Faraday::ConnectionFailed, Faraday::TimeoutError,
               HTTPClient::ReceiveTimeoutError, Net::OpenTimeout => e
            begin
                texto, backtrace = @logger.excepcion_texto(e)
                @logger.error texto, al_canal: true, backtrace: backtrace
            rescue StandardError => e
                @logger.fatal "EXCEPCIÓN LEYENDO LA EXCEPCIÓN\n#{e}", al_canal: true
            end
            retry

        rescue StandardError => e

            begin
                texto, backtrace = @logger.excepcion_texto(e)
                @logger.fatal texto, al_canal: true, backtrace: backtrace
            rescue StandardError => e
                @logger.fatal "EXCEPCIÓN LEYENDO LA EXCEPCIÓN\n#{e}", al_canal: true
            end

            # Sacar este raise cuando el bot deje de ser testeadísimo
            # lo puse porque luke dice que es pesado cuando se pone a mandar
            # errores en el grupete.
            #       raise
        end
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @comandos.each_value do |comando|
            yield comando.cmd, comando.descripción if comando.descripción
        end
    end

    def html_parser(texto)
        CGI.escapeHTML(texto)
    end

    def get_command(msj)
        cmd = _parse_command(msj)
        cmd[:command]
    end

    # Este método analiza parámetros en el mensaje. se podría hacer una combinación
    # tomando parámetros de acá y usar un mensaje respondido como el resto del
    # argumento, pero eso no se hace acá porque podría ser peligroso en algunos
    # comandos.
    def get_command_params(msj)
        cmd = _parse_command(msj)
        cmd[:params]
    end

    def chat_inválido(msj, válidos)
        return if msj.chat.type == 'channel'

        traducciones = { 'private' => 'privado', 'group' => 'grupos',
                         'supergroup' => 'supergrupos', 'channel' => 'canales' }

        texto = "Este comando es válido solo en #{traducciones[válidos.first]}"

        if válidos.length == 2
            texto << " y #{traducciones[válidos[1]]}"
        elsif válidos.length == 3
            texto << ", #{traducciones[válidos[1]]} y #{traducciones[válidos[2]]}"
        end

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    private

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def _parse_command(msj)
        unless (text = msj.text || msj.caption)
            return { command: nil, params: nil }
        end

        return { command: nil, params: nil } if text.size <= 1

        command = nil
        params = nil

        if text.start_with? '/' # "/cmd params" o "/cmd@bot params"
            command, params = text.split ' ', 2
            command.downcase!
            command.gsub!(%r{^/([a-z]+)(@#{@user.username.downcase})?}, '\\1')

        elsif ['!', '>', '$', '.'].include? text[0] # "!cmd params" o ">cmd params"
            command, params = text.split ' ', 2
            command = command[1..-1]
            command.downcase!
        else
            arr = text.split(' ', 3) # ["user", "comando", "params"]
            arr.first.downcase!
            if (arr.size > 1) && arr.first.casecmp(@user.username[0..-4]).zero?
                command = arr[1].downcase.to_sym
                params = arr[2]
            # Responde al bot
            elsif msj.reply_to_message&.from&.id == @user.id
                command, params = text.split ' ', 2
                command.downcase!
            end
        end

        { command: command&.to_sym, params: params }
    end

    def enlace_usuario_id(id_usuario, id_chat)
        if (apodo = @redis.hget("apodo:#{id_chat}", id_usuario.to_s))
            enlace_usuario = "<a href='tg://user?id=#{id_usuario}'>" \
                             "#{html_parser(apodo)}</a>"
        else
            usuario = @tg.get_chat_member(chat_id: id_chat, user_id: id_usuario)
            usuario = Telegram::Bot::Types::ChatMember.new(usuario['result']).user
            enlace_usuario = crear_enlace(usuario)
        end
    rescue StandardError, Telegram::Bot::Exceptions::ResponseError => e
        enlace_usuario = nil
        error = if e.to_s.include? 'USER_ID_INVALID'
                    "Traté de obtener el nombre de una cuenta eliminada: #{id_usuario}"
                else
                    e.to_s
                end
        @logger.error(error, al_canal: false)
    ensure
        return enlace_usuario || "ay no c (#{id_usuario})"
    end

    def enlace_usuario_objeto(usuario, id_chat)
        if (apodo = @redis.hget("apodo:#{id_chat}", usuario.id.to_s))
            "<a href='tg://user?id=#{usuario.id}'>" \
                   "#{html_parser(apodo)}</a>"
        else
            crear_enlace(usuario)
        end
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

            return num if num.positive?
        end

        false
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

                    otro_texto = texto[fin..-1].strip
                    otro_texto = nil if otro_texto.empty?

                    # Me fijo si esa entidad efectivamente era un alias
                    if entidad.type == 'mention'
                        # La entidad arranca con un @, por eso el + 1
                        alias_usuario = texto[(entidad.offset + 1)..(fin - 1)].strip
                        id_afectada = obtener_id_de_alias(alias_usuario)
                    # Me fijo si esa entidad efectivamente era una mención de usuario sin alias
                    elsif entidad.type == 'text_mention'
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
            [primer_palabra, lista_palabras[1..-1].join(' ')]
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
            @logger.error('Me dieron una id inválida en ' + grupo_del_msj(msj))
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
                                 text: error_no_admin + ' ser admin para hacer eso',
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
        @logger.error(error + ' en ' + grupo_del_msj(msj), al_canal: al_canal)
        @tg.send_message(chat_id: msj.chat.id,
                         text: error,
                         reply_to_message_id: msj.message_id)
    end

    def descargar_archivo_tg(_id_archivo, nombre_guardado)
        archivo = @tg.get_file(id_imagen)
        archivo = Telegram::Bot::Types::File.new(archivo['result'])

        return false if archivo.file_size && archivo.file_size > 20

        # TODO: ver que esta virgueada ande y validar hasta el ojete,
        # ni me quiero imaginar la cantidad de excepciones que hay que
        # manejar acá
        enlace_archivo = "https://api.telegram.org/file/bot<#{@tg.token}>"\
                         "/#{archivo.file_path}"

        descargar_archivo_internet(enlace_archivo, nombre_guardado)
    end

    def descargar_archivo_internet(enlace_internet, _nombre_guardado)
        enlace_disco = "./tmp/dankie/#{SecureRandom.uuid}.#{extension}"
        # TODO: ver que esta virgueada ande y validar hasta el ojete,
        # ni me quiero imaginar la cantidad de excepciones que hay que
        # manejar acá
        open(enlace_internet) do |archivo_internet|
            File.open(enlace_disco, 'wb') do |archivo_disco|
                archivo_disco.write(archivo_internet.read)
            end
        end
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
        @redis.rpush "spam:#{id_chat}", id_mensaje
        if @redis.llen("spam:#{id_chat}") > 24
            id_mensaje = @redis.lpop("spam:#{id_chat}").to_i
            @tg.delete_message(chat_id: id_chat, message_id: id_mensaje)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /message to delete not found/
            @logger.error("Traté de borrar un mensaje (id mensaje: #{id_mensaje}) "\
                          "muy viejo (id chat: #{id_chat}).",
                          al_canal: false)
        when /message can't be deleted/
            @logger.error("No pude borrar un mensaje (id mensaje: #{id_mensaje}) "\
                          "(id chat: #{id_chat}).",
                          al_canal: false)
        end
    end

    def arreglo_tablero(conjunto_iterable, arr, título,
                        subtítulo, contador, max_cant, max_tam,
                        agr_elemento, inicio_en_subtítulo = false)
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
