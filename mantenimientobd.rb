# Este script es para controlar las claves de la base de datazos a manopla
require 'yaml'
require 'redis'

def imprimir_todas_las_claves(redis, patrón = '')
    redis.keys('*').each do |clave|
        next unless clave.include? patrón

        case redis.type(clave)

        when 'string'
            valor = redis.get(clave)
            puts "CLAVE NORMAL: #{clave}\nVALOR: #{valor}\n\n"

        when 'list'
            valores = redis.lrange(clave, 0, -1)
            puts "LISTA: #{clave}\nELEMENTOS: #{valores}\n\n"

        when 'set'
            valores = redis.smembers(clave)
            puts "CONJUNTO: #{clave}\nELEMENTOS: #{valores}\n\n"

        when 'zset'
            imprimir_zset clave, redis

        when 'hash'
            imprimir_hash clave, redis

        when 'stream'
            puts "STREAM: #{clave}\n"\
                 "VALOR: ¿QUÉ MIERDA ES ESTO FLACO? USÁ CLAVES NORMALES\n\n"

        end
    end
end

def modificar_base
    datazos = YAML.load_file(File.join(__dir__, 'config.yml'))
    datazos.transform_keys!(&:to_sym)

    redis = Redis.new(port: datazos[:redis_port],
                      host: datazos[:redis_host],
                      password: datazos[:redis_pass])

    imprimir_antes redis

    # Acá meter funciones para modificar la BD, NO OLVIDARSE de borrarlos después
    # Por ejemplo: redis.del("agregar:5")
    #
    # redis.flushdb
    #
    # redis.keys('*').each do |clave|
    #   redis.del(clave)
    # end

    imprimir_después redis
end

def imprimir_antes(redis)
    puts "\n"
    puts '-' * 30
    puts 'ANTES DE CAMBIAR LA BBDD'
    puts '-' * 30
    puts "\n"

    imprimir_todas_las_claves redis

    puts '-' * 30
    puts 'CAMBIANDO LA BBDD'
    puts '-' * 30
end

def imprimir_después(redis)
    puts 'CAMBIADA'
    puts '-' * 30
    puts 'DESPUÉS DE CAMBIAR LA BBDD'
    puts '-' * 30
    puts "\n"

    imprimir_todas_las_claves redis

    puts '-' * 30
    puts 'FIN'
end

def imprimir_hash(clave, redis)
    valores = redis.hgetall(clave)
    puts "HASH: #{clave}\nELEMENTOS: "
    valores.each do |atributo|
        puts " #{atributo[0]}: #{atributo[1]}"
    end
    puts "\n"
end

def imprimir_zset(clave, redis)
    valores = redis.zrevrange(clave, 0, -1, with_scores: true)
    puts "CONJUNTO ORDENADO: #{clave}\nELEMENTOS: "
    valores.each do |atributo|
        puts " #{atributo[0]}: #{atributo[1]}"
    end
    puts "\n"
end

modificar_base
