require "telegram/bot"

class Dankie
	attr_reader :api, :logger, :redis, :reddit, :user
	@@commands = {}

	def initialize(api, logger, redis, reddit)
		@api = api
		@logger = logger
		@redis = redis
		@reddit = reddit
		@user = Telegram::Bot::Types::User.new(@api.get_me["result"]) #TODO: validar?
	end

	#Analiza un texto y se fija si es un comando válido, devuelve el comando y el resto del texto
	def parse_command(text)
		text.downcase!
		return unless text.start_with? "/"
		command, params = text.split " ", 2
		command.gsub!(/(\/|@#{@user.username})/, "")

		{ command: command.to_sym, params: params } #TODO: reemplazar esto por un objeto Command????
	end

	#Con esta función agregás un comando para el comando de ayuda, y su descripción
	def self.command(args)
		raise ArgumentException unless args.is_a? Hash

		@@commands.merge!(args)
	end
end
