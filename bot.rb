require 'yaml'
require_relative 'dankie'
require_relative 'version'
require_relative 'handlers'
Dir[File.dirname(__FILE__) + '/plugins/*.rb'].each { |file| require_relative file } # esta cosa carga todos los plugins del bot

config = YAML.load_file(File.join(__dir__, 'config.yml'))
config.transform_keys!(&:to_sym)

dankie = Dankie.new config



dankie.run

#plugins = Dir[File.dirname(__FILE__) + '/plugins/*.rb'].map { |file| file.split('/').last.gsub('.rb', '').to_sym }
