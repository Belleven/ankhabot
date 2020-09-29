# Datos necesarios para iniciar
require 'yaml'

# pongo Dir en la raíz del projecto
Dir.chdir __dir__

require_relative 'lib/dankie'

# Esto carga todos los módulos del bot
Dir['base/*.rb'].each { |file| require_relative File.absolute_path(file) }
Dir['módulos/*.rb'].each { |file| require_relative File.absolute_path(file) }

# Busco el archivo de configuración
rutas_posibles = [File.join(Dir.pwd, 'config.yml'),
                  File.join(Dir.home, '.config/dankie.yml'),
                  '/etc/dankie.yml']

config = nil
rutas_posibles.each do |archivo|
    next unless File.exist? archivo

    config = YAML.load_file(archivo)
    config.transform_keys!(&:to_sym)
    break
end

raise 'No se puede iniciar el bot, falta el archivo de configuración' unless config

dankie = Dankie.new(config)
dankie.run
