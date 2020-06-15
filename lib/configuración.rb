class Configuración
    attr_reader :id_grupo, :categoria, :valor
    #categoria es la categoría de configuración. Ej: :acepta_triggers_globales
    #valor es el valor en Integer de la configuración. Si es booleano, 0=false 1=true

#    def initialize(id_grupo, categoria, valor)
#        clave = "configs:#{id_grupo}"
#    end

    # Con esto meto redis en la clase Configuración para no pasarlo a cada rato
    class << self
        attr_accessor :redis
    end

    # Método que pone una configuracion. Las configs se guardan en un has del tipo
    # config:id_grupo = {categoria=>valor}
    def self.poner_config(id_grupo, categoria, valor)
        clave = "configs:#{id_grupo}"
        @redis.hset(clave, categoria, valor)
    end

    # Itera sobre el conjunto de configuraciones del grupo.
    # Arma un hash con las configs existentes y lo devuelve
    def self.configs(id_grupo)
        clave = "configs:#{id_grupo}"
        @redis.hgetall(clave)
    end

    #Devuelve el valor de la config de ese grupo.
    def self.config(id_grupo,categoria)
        clave = "configs:#{id_grupo}"
        @redis.hget(clave,categoria)
    end
end
