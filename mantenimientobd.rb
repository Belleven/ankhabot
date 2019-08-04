# Este script es para controlar las claves de la base de datazos a manopla
require 'yaml'
require 'redis'

datazos = YAML.load_file(File.join(__dir__, 'config.yml'))
datazos.transform_keys!(&:to_sym)

$redis = Redis.new port: datazos[:redis_port], host: datazos[:redis_host], password: datazos[:redis_pass]

def imprimir_todas_las_claves(patron = '')
    $redis.keys.each do |clave|
        if clave.include? patron

            if $redis.type(clave) == 'string'

                valor = $redis.get(clave)
                puts 'CLAVE NORMAL: ' + clave + "\nVALOR: " + valor	+ "\n\n"

            elsif $redis.type(clave) == 'list'

                valores = $redis.lrange(clave, 0, -1)
                puts 'LISTA: ' + clave + "\nELEMENTOS: " + valores.to_s + "\n\n"

            elsif $redis.type(clave) == 'set'

                valores = $redis.smembers(clave)
                puts 'CONJUNTO: ' + clave + "\nELEMENTOS: " + valores.to_s + "\n\n"

            elsif $redis.type(clave) == 'zset'

                valores = $redis.zrevrange(clave, 0, -1, with_scores: true)
                puts 'CONJUNTO ORDENADO: ' + clave + "\nELEMENTOS: "
                valores.each do |atributo|
                    puts ' ' + atributo[0].to_s + ': ' + atributo[1].to_s
                end
                puts "\n"

            elsif $redis.type(clave) == 'hash'

                valores = $redis.hgetall(clave)
                puts 'HASH: ' + clave + "\nELEMENTOS: "
                valores.each do |atributo|
                    puts ' ' + atributo[0].to_s + ': ' + atributo[1].to_s
                end
                puts "\n"

            elsif $redis.type(clave) == 'stream'

                puts 'STREAM: ' + clave + "\NVALOR: ¿QUÉ MIERDA ES ESTO FLACO? USÁ CLAVES NORMALES\n\n"

            end

        end
    end
end

def modificar_base
    puts "\n"
    puts '-' * 30
    puts 'ANTES DE CAMBIAR LA BBDD'
    puts '-' * 30
    puts "\n"

    imprimir_todas_las_claves

    puts '-' * 30
    puts 'CAMBIANDO LA BBDD'
    puts '-' * 30

    # Acá meter funciones para modificar la BD, NO OLVIDARSE de borrarlos después
    # Por ejemplo: $redis.del("agregar:5")

    puts 'CAMBIADA'
    puts '-' * 30
    puts 'DESPUÉS DE CAMBIAR LA BBDD'
    puts '-' * 30
    puts "\n"

    imprimir_todas_las_claves

    puts '-' * 30
    puts 'FIN'
end

modificar_base
