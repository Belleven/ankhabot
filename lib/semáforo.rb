require 'concurrent-ruby'

class Semáforo
    
    def initialize()
        @semáforo = Concurrent::AtomicFixnum.new(0)
    end

    def bloqueo_uno()
        while !@semáforo.compare_and_set(0, -1)
            sleep(1)
        end           
    end
    
    def bloqueo_muchos()
        # Esto no es starvation-free
        while true
     
            # Tomo el valor actual
            actual = @semáforo.value
     
            # Si es mayor o igual a 0, quiere decir que el chequeo de poles no
            # "tomó" el semáforo
            if actual >= 0

                # Me fijo si mientras chequeaba que actual >= 0 u obtenía 
                # siguiente, no cambió el valor del semáforo, en cuyo caso lo tomo,
                # si no, pruebo de nuevo luego del sleep
                if @semáforo.compare_and_set(actual, actual + 1)
                    break
                end
     
            end
     
            # Si no pude tomar el recurso, duermo al proceso por 1 segundo
            sleep(1)
        end
    end
    
    def valor()
        @semáforo.value
    end

    def desbloqueo_uno()
        @semáforo.increment
    end
    
    def desbloqueo_muchos()
        @semáforo.decrement
    end

end