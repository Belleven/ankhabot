require 'benchmark'
require 'redis'

module Estadísticas
    class Base
        def self.redis=(servidor)
            @@redis = servidor
        end

        def self.redis
            return @@redis if @@redis

            Redis.new
        end

        def self.borrar(clave)
            redis.del(clave)
        end

        def initialize; end
    end

    # Clase para guardar claves simples
    class Simple < Base
        # Crea o cambia el valor de una clave
        def self.set(clave, valor)
            redis.set(clave, valor)
        end

        # Devuelve el valor de una clave
        def self.get(clave)
            redis.get(clave)
        end
    end

    # Clase para manejar contadores
    class Contador < Base
        # Aumenta el contador según número, se puede definir la hora del evento
        # en segundos, y un intervalo de tiempo en segundos, para aumentar el
        # contador solo en el intervalo que corresponda (por ejemplo contar
        # cuantas veces ocurre algo por hora o por día)
        def self.incr(clave, número = 1, hora: nil, intervalo: nil)
            return redis.incrby(clave, número).to_i unless intervalo && hora

            redis.incrby("#{clave}:#{hora / intervalo * intervalo}", número).to_i
        end

        # Lo mismo pero decrementa
        def self.decr(clave, número = 1, hora: nil, intervalo: nil)
            incr(clave, -número, hora: hora, intervalo: intervalo)
        end

        # Devuelve el valor del contador, o la suma de los contadores en un
        # rango de desde..hasta, según cierto intervalo
        def self.get(clave, desde: nil, intervalo: nil, hasta: nil)
            return redis.get(clave).to_i unless desde

            if intervalo && hasta
                return (desde..hasta).step(intervalo).inject(0) do |acc, i|
                    acc + redis.get("#{clave}:#{i}").to_i
                end
            end

            redis.get("#{clave}:#{desde}").to_i
        end
    end

    # Clase para guardar conjuntos de elementos, se pueden separar en intervalos
    # de tiempo así se puede tener conjuntos por día o por hora.
    class Conjunto < Base
        def self.add(clave, valor, hora: nil, intervalo: nil)
            return redis.sadd(clave, valor) unless intervalo && hora

            redis.sadd("#{clave}:#{hora / intervalo * intervalo}", valor)
        end

        def self.members(clave, desde: nil, intervalo: nil, hasta: nil)
            return redis.smembers(clave) unless desde

            if intervalo && hasta
                return (desde..hasta).step(intervalo).map do |h|
                    redis.smembers("#{clave}:#{h}")
                end.flatten.uniq
            end

            redis.smembers("#{clave}:#{desde}")
        end

        def self.size(clave, desde: nil, intervalo: nil, hasta: nil)
            return redis.scard(clave) unless desde

            if intervalo && hasta
                return members(clave, desde: desde,
                                      intervalo: intervalo, hasta: hasta).size
            end

            redis.scard("#{clave}:#{desde}")
        end
    end

    # Clase para manejar temporizadores y guardarlos en listas
    class Temporizador < Base
        # Añade un tiempo de ejecución de un bloque a la lista.
        def self.time(clave, intervalo: nil, &bloque)
            unless bloque
                error_texto = 'Se necesita un bloque de código para saber su tiempo.'
                raise ArgumentError, error_texto
            end

            tiempo = Benchmark.realtime { bloque.call }

            return redis.rpush(clave, tiempo) unless intervalo

            hora = Time.now.to_i / intervalo * intervalo
            clave += ":#{hora}"

            # Si la clave que se va a usar ahora no tiene elementos, entonces la
            # clave anterior ya se llenó y se pueden achicar sus datos
            reducir_datos("#{clave}:#{hora - intervalo}") if redis.llen(clave).zero?

            redis.rpush(clave, tiempo)
        end

        def self.obtener_tiempos(clave, hora: nil, intervalo: nil)
            return new(clave) unless hora

            clave += ":#{hora}"

            if intervalo && (Time.now.to_i / intervalo * intervalo) > hora
                reducir_datos(clave)
            end

            new(clave)
        end

        def self.media_ponderada(arr)
            media = arr.inject(0) { |acc, t| acc + t.sumatoria }
            total_muestras = arr.inject(0) { |acc, t| acc + t.total_datos }

            return 0 if total_muestras.zero?

            media / total_muestras
        end

        def initialize(clave)
            super

            @arr = self.class.redis.lrange(clave, 0, -1).map(&:to_f)

            @datos_reducidos = self.class.redis.hgetall("#{clave}:reducido")
            @datos_reducidos.transform_keys!(&:to_sym)
            @datos_reducidos.transform_values!(&:to_f)
        end

        def total_datos
            @datos_reducidos[:total_datos] || @arr.size
        end

        def sumatoria
            if @datos_reducidos[:promedio]
                return @datos_reducidos[:promedio] * total_datos
            end

            @arr.inject(0) { |acc, i| acc + i }
        end

        def promedio
            return 0 if total_datos.zero?

            @datos_reducidos[:promedio] || sumatoria / total_datos
        end

        def varianza
            return 0 if total_datos.zero?
            return @datos_reducidos[:varianza] if @datos_reducidos[:varianza]

            prom = promedio
            @arr.inject(0) { |acc, i| acc + (i - prom)**2 } / total_datos
        end

        def desviación_estándar
            return 0 if total_datos.zero?
            return @datos_reducidos[:desviación] if @datos_reducidos[:desviación]

            Math.sqrt varianza
        end

        def self.reducir_datos(clave)
            return if redis.llen(clave).zero?

            datos = new(clave)

            hash = { total_datos: datos.total_datos, promedio: datos.promedio,
                     varianza: datos.varianza, desviación: datos.desviación_estándar }

            redis.mapped_hmset("#{clave}:reducido", hash)
            borrar clave
        end
    end
end
