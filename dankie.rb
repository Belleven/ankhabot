require 'telegram/bot'

class Dankie
    attr_reader :api, :logger, :redis, :reddit, :user
    @@commands = {}
    # TROESMAS = %w[mostro genio figura crack mastodonte ídolo champion referente maquina artista elemento jefe fiera maestro socio golfo valiente héroe tanque fenómeno gacela tigre bestia titán animal gigante prenda semental coloso hacha mostrenco campeón helicóptero killer ciclón pieza brontosaurio vikingo vividor crack fiera mostro animal máquina gigante artista titán caimán tiranosaurio superman prenda semental ninja figura genio tsunami león terminator goliat terremoto tigre vaquero tanque mole samurai coloso paladin willyrex lobezno velociraptor espectro vikingo godzilla caza de combate campeón adamantium robocop zeus capitán king kong depredador tornado monster truck presa canario johnny bravo mastodonte coronel héroe canallita champion jefe chulazo truhan maquinola].freeze
    # REKT = ['☑️ Rekt', '☑️ Really Rekt', '☑️ Tyrannosaurus Rekt', '☑️ Cash4Rekt.com', '☑️ Grapes of Rekt', '☑️ Ship Rekt', '☑️ Rekt markes the spot', '☑️ Caught rekt handed', '☑️ The Rekt Side Story', "☑️ Singin' In The Rekt", '☑️ Painting The Roses Rekt', '☑️ Rekt Van Winkle', '☑️ Parks and Rekt', '☑️ Lord of the Rekts: The Reking of the King', '☑️ Star Trekt', '☑️ The Rekt Prince of Bel-Air', '☑️ A Game of Rekt', '☑️ Rektflix', "☑️ Rekt it like it's hot", '☑️ RektBox 360', '☑️ The Rekt-men', '☑️ School Of Rekt', '☑️ I am Fire, I am Rekt', '☑️ Rekt and Roll', '☑️ Professor Rekt', '☑️ Catcher in the Rekt', '☑️ Rekt-22', '☑️ Harry Potter: The Half-Rekt Prince', '☑️ Great Rektspectations', '☑️ Paper Scissors Rekt', '☑️ RektCraft', '☑️ Grand Rekt Auto V', '☑️ Call of Rekt: Modern Reking 2', '☑️ Legend Of Zelda: Ocarina of Rekt', '☑️ Rekt It Ralph', '☑️ Left 4 Rekt', '☑️ www.rekkit.com', '☑️ Pokemon: Fire Rekt', '☑️ The Shawshank Rektemption', '☑️ The Rektfather', '☑️ The Rekt Knight', '☑️ Fiddler on the Rekt', '☑️ The Rekt Files', '☑️ The Good, the Bad, and The Rekt', '☑️ Forrekt Gump', '☑️ The Silence of the Rekts', '☑️ The Green Rekt', '☑️ Gladirekt', '☑️ Spirekted Away', '☑️ Terminator 2: Rektment Day', '☑️ The Rekt Knight Rises', '☑️ The Rekt King', '☑️ REKT-E', '☑️ Citizen Rekt', '☑️ Requiem for a Rekt', '☑️ REKT TO REKT ass to ass', '☑️ Star Wars: Episode VI - Return of the Rekt', '☑️ Braverekt', '☑️ Batrekt Begins', '☑️ 2001: A Rekt Odyssey', '☑️ The Wolf of Rekt Street', "☑️ Rekt's Labyrinth", '☑️ 12 Years a Rekt', '☑️ Gravirekt', '☑️ Finding Rekt', '☑️ The Arekters', '☑️ There Will Be Rekt', '☑️ Christopher Rektellston', '☑️ Hachi: A Rekt Tale', '☑️ The Rekt Ultimatum', '☑️ Shrekt', '☑️ Rektal Exam', '☑️ Rektium for a Dream', '☑️ www.Trekt.tv', '☑️ Erektile Dysfunction'].freeze
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
    rescue Telegram::Bot::Exceptions::ResponseError => e
        puts e.error_code
        puts e.to_s
        puts e.response
    end

    def send_sticker(args)
        @api.send_sticker(args)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        puts e.error_code
        puts e.to_s
        puts e.response
    end
end
