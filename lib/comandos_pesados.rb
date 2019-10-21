require 'timeout'

class Dankie
    # Comunica el thread principal con el thread de comandos pesados
    @cola_msj = Queue.new
    # Thread
    @thread_ejecución = Thread.new { comandos_pesados }

    # Thread principal ejecuta esto
    def encolar_msj_pesado(msj)
        @cola_msj.push(msj)
    end

    # Es un bucle infinito que va desencolando mensajes y ejecutándolos
    def comandos_pesados
        loop do
            # Si la cola está vacía, se queda bloqueado acá el thread
            # hasta que se vuelva a encolar un elemento
            msj = @cola_msj.pop

            # Esto hasta el final del loop es por cada comando pesado

            # Elementos a borrar en caso de timeout
            bloqueantes = []
            actual_bloq = nil

            # Variables de tiempo
            timeout = 30 # Segundos, en el handler debería venir el timeout
            timeout_elem = 2 # Segundos, en el handler debería venir el timeout
            tiempo_actual = Time.now

            begin
                # Tener en cuenta que esto puede morir en cualquier momento
                resultado = Timeout.timeout(timeout) do
                    # Ejecuta el comando: pasarle bloqueantes. actual_bloq y
                    # tiempo_actual
                    # Fin ejecución
                end
            rescue Timeout::TimeoutError
                # El elemento actual es el que genera el bloqueo, lo agrego a la lista
                # de elementos a eliminar por bloqueantes
                bloqueantes << actual_bloq if Time.now - tiempo_actual >= timeout_elem
                # Ejecutar función eliminadora de bloqueantes
            end
        end
    end
end
