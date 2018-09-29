require_relative "dankie"
require_relative "version"
Dir[File.dirname(__FILE__) + "/plugins/*"].each { |file| require_relative file } #esta cosa carga todos los plugins del bot
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


plugins = Dir[File.dirname(__FILE__) + "/plugins/*.rb"].map { |file| file.split("/").last.gsub(".rb", "").to_sym }
bot.listen do |message|
	#TODO: validar blacklist acá (crearla antes)
	next if message.is_a? Telegram::Bot::Types::Message and message.edit_date

	#acá ocurre la magia
	plugins.each do |plugin|
		dankie.send(plugin, message)
	end

end