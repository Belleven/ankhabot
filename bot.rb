# Datos necesarios para iniciar
require 'yaml'
# Esto prepara a Dankie
require_relative 'lib/dankie'
# Esto carga todos los plugins del bot
Dir[File.dirname(__FILE__) + '/plugins/*.rb'].each { |file| require_relative file }

config = YAML.load_file(File.join(__dir__, 'config.yml'))
config.transform_keys!(&:to_sym)

dankie = Dankie.new config
dankie.run
