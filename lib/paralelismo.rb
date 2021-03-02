require 'json'

# Una cola por chat_id, la cola de id 0 es para handlers que requieren sincronía global
# o updates sin chat_id asociado (callbacks por ejemplo)
class Colita
    def self.redis=(servidor)
        @@redis = servidor
    end

    def self.redis
        return @@redis if @@redis

        Redis.new
    end

    CLAVE = 'colita:'.freeze
    ESPERAR = ':esperar'.freeze

    def self.meter(chat_id, texto)
        redis.rpush(CLAVE + chat_id.to_s, texto.to_json)
    end

    def self.sacar(chat_id)
        dato = redis.lpop(CLAVE + chat_id.to_s)
        dato.nil? ? nil : JSON.parse(dato)
    end

    def self.tamaño(chat_id)
        redis.llen(CLAVE + chat_id.to_s)
    end

    def self.vaciar(chat_id)
        redis.del(CLAVE + chat_id.to_s)
    end

    def self.vacía?(chat_id)
        tamaño(chat_id).zero?
    end

    def self.bloquear(chat_id, tiempo)
        redis.setex(CLAVE + chat_id.to_s + ESPERAR, tiempo, tiempo)
    end

    def self.bloqueada?(chat_id)
        !redis.get(CLAVE + chat_id.to_s + ESPERAR).nil?
    end

    def self.tiempo_de_bloqueo_restante(chat_id)
        redis.ttl(CLAVE + chat_id.to_s + ESPERAR).to_i
    end
end

class Procesador
    def self.redis=(servidor)
        @@redis = servidor
    end

    def self.redis
        return @@redis if @@redis

        Redis.new
    end

    attr_reader :id

    def initialize(id, planificador, bot)
        @id = id
        @planificador = planificador
        @bot = bot
        # Set de redis donde guardo los chats que procesa este Procesador
        @clave_chats = "chats_por_proceso:#{id}".freeze

        procesar_colas
    end

    def procesar_colas
        fork do
            loop do
                # Tomo una update de cada grupo por vez
                chats.each do |chat|
                    actualización = Colita.sacar(chat)
                    # Puede haber una condición de carrera donde chat_vacío?
                    # devuelva true, luego se encole un mensaje, y luego se
                    # llame a desasignar_chat. Pero si pasa esto, el chat va a
                    # pasar a otro Procesador así que ta to' OK supongo, a ver
                    # que dice el vergalera.
                    if chat_vacío?(chat) && id != -1 # Al procesador -1 nunca le saco
                        @planificador.desasignar_chat(self, chat)
                    end

                    next if actualización.nil?

                    @bot.procesar_actualización(actualización,
                                                sincronía: chat.zero? ? :global : :local)
                end

                sleep(0.2) if chats.empty?
            end
        end
    end

    def chats
        redis.smembers(@clave_chats).map(&:to_i)
    end

    def chat_vacío?(chat_id)
        Colita.vacía?(chat_id)
    end

    def pertenece?(chat_id)
        redis.sismember(chat_id)
    end

    def añadir_chat(chat_id)
        redis.sadd @clave_chats, chat_id
    end

    def bajar_chat(chat_id)
        redis.srem @clave_chats, chat_id
    end

    private

    def redis
        self.class.redis
    end
end

class Planificador
    NÚM_PROCESOS = 10

    # Hash de redis que mapea un grupo_id al proceso encargado de procesar
    # la cola de ese grupo
    CLAVE_COLAS = 'procesos_por_cola'.freeze

    def self.redis=(servidor)
        @@redis = servidor
    end

    def self.redis
        return @@redis if @@redis

        Redis.new
    end

    def initialize(bot)
        # Arreglo con todos los Procesador
        @procesos = NÚM_PROCESOS.times.map { |i| Procesador.new(i, self, bot) }
        @proceso_sincrónico_global = Procesador.new(-1, self, bot)
    end

    def encolar(actualización, chat_id)
        Colita.meter(chat_id, actualización)
        Colita.meter(0, actualización)

        #        return if @procesos.map(&:chats).flatten.include?(chat_id)
        return unless chats[chat_id].nil?

        asignar_chat(proceso_con_menos_chats, chat_id)
    end

    def desasignar_chat(procesador, chat)
        redis.multi do
            procesador.bajar_chat(chat)
            redis.hset(CLAVE_COLAS, chat, nil)
        end
    end

    def asignar_chat(procesador, chat)
        redis.multi do
            procesador.añadir_chat(chat)
            redis.hset(CLAVE_COLAS, chat, procesador.id)
        end
    end

    def chats
        redis.hgetall(CLAVE_COLAS).transform_keys(&:to_i).transform_values do |val|
            if val.empty?
                nil
            else
                val.to_i
            end
        end
    end

    def proceso_con_menos_chats
        @procesos.min { |a, b| a.chats.size <=> b.chats.size }
    end

    private

    def redis
        self.class.redis
    end
end
