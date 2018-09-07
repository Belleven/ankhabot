require_relative "dankie"
Dir[File.dirname(__FILE__) + "/commands/*"].each { |file| require_relative file } #esta cosa carga los comandos en la carpeta
require "telegram/bot"
require "redis"
require "ruby_reddit_api"

#TODO: mover a otro archivo?
def get_token(file)
	return nil unless File.exist?(file)
	IO.read(file).chomp
end

#apis de todas las porquerías
bot = Telegram::Bot::Client.new(get_token("token"), logger: Logger.new($stderr))
redis = Redis.new port: 42069
reddit = Reddit::Api.new
dankie = Dankie.new(bot.api, bot.logger, redis, reddit)

messages = []
Thread.new do
	bot.listen do |message|		#Tengo entendido que como ruby no permite que se ejecuten dos hilos a la vez,
		messages << message	#no habría problema con manosear una variable desde dos hilos distintos.
	end
end.abort_on_exception = true


commands = Dir[File.dirname(__FILE__) + "/commands/*"].map { |file| file.split("/").last.gsub(".rb", "").to_sym }

while true do
	next if messages.empty?
	message = messages.shift
	next unless message.is_a? Telegram::Bot::Types::Message #esto valida que se reciba un mensaje
								#por ahí recibe un texto inline u otra cosa

	command = dankie.parse_command(message.text) if message.text
	if command and commands.include? command[:command]
		dankie.send(command[:command], message)
	end

end
