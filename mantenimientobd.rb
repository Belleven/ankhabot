# Este script es para controlar las claves de la base de datazos a manopla

require 'redis'

redis = Redis.new port: args[:redis_port], host: args[:redis_host], password: args[:redis_pass]

redis.keys do |clave|
	valor = redis.get(clave)
	puts valor

end