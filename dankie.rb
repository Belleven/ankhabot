require 'telegram/bot'

class Dankie
    attr_reader :api, :logger, :redis, :reddit, :user
    @@commands = {}
    TROESMAS = File.readlines('troesmas.txt')
    REKT = File.readlines('rekt.txt')

    def initialize(api, logger, redis, reddit)
        @api = api
        @logger = logger
        @redis = redis
        @reddit = reddit
        @user = Telegram::Bot::Types::User.new(@api.get_me['result']) # TODO: validar?
    end

    # Analiza un texto y se fija si es un comando válido, devuelve el comando y el resto del texto
    def parse_command(text)
        return unless text.start_with? '/'

        command, params = text.split ' ', 2
        command.downcase!
        command.gsub!(/^\/([a-zñ]+)(@#{@user.username})?/, '\\1')

        { command: command.to_sym, params: params } # TODO: reemplazar esto por un objeto Command????
    end

    # Con esta función agregás un comando para el comando de ayuda, y su descripción
    def self.command(args)
        raise ArgumentException unless args.is_a? Hash

        @@commands.merge!(args)
    end

    def self.commands
        @@commands.each do |k, v|
            yield k, v
        end
    end

    # text: 'typing',
    # photo: 'upload_photo'
    # video: 'upload_video'
    # audio: 'upload_audio'
    # file: 'upload_document'
    # animation: 'upload_document'
    # video_note: 'upload_video_note'
    def send_message(args)
        @api.send_chat_action(chat_id: args[:chat_id], action: 'typing')
        @api.send_message(args)
    rescue Net::OpenTimeout => e
        @logger.error e
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error e
    end

    def send_sticker(args)
        @api.send_sticker(args)
    rescue Net::OpenTimeout => e
        @logger.error e
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error e
    end
end
