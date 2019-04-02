require_relative 'dankie'
require_relative 'version'
Dir[File.dirname(__FILE__) + '/plugins/*'].each { |file| require_relative file } # esta cosa carga todos los plugins del bot
require 'telegram/bot'
require 'redis'
require 'ruby_reddit_api'

$config = YAML.load_file(File.join(__dir__, 'config.yml'))
$config.transform_keys!(&:to_sym)

# apis de todas las porquerías
bot = Telegram::Bot::Client.new($config[:tg_token], logger: Logger.new($stderr))
redis = Redis.new port: $config[:redis_port], host: $config[:redis_host], password: $config[:redis_pass]
reddit = Reddit::Api.new

dankie = Dankie.new(bot.api, bot.logger, redis, reddit)

plugins = Dir[File.dirname(__FILE__) + '/plugins/*.rb'].map { |file| file.split('/').last.gsub('.rb', '').to_sym }
bot.listen do |message|
    # TODO: validar blacklist acá (crearla antes)
    next if message.is_a?(Telegram::Bot::Types::Message) && message.edit_date

    # acá ocurre la magia
    plugins.each do |plugin|
        dankie.send(plugin, message)
    end
rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
    dankie.logger.error e
	retry
end
