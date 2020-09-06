require 'gruff'

class Dankie
    add_handler Handler::Mensaje.new(:stats_básicas)
    #    add_handler Handler::Comando.new(:stats, :enviar_stats_grupo,
    #                                     permitir_params: true,
    #                                     chats_permitidos: %i[group supergroup],
    #                                     descripción: 'Te digo cuanto me usan'\
    #                                     'en el grupo 7u7')
    add_handler Handler::Comando.new(:stats_bot, :enviar_stats_bot,
                                     permitir_params: true)

    def stats_básicas(msj)
        # Mensajes recibidos por día
        # ejemplo: msj_recibidos:-2020-12-25
        Stats.incr("msj_recibidos:#{Time.now.strftime('%Y-%m-%d')}")

        # Mensajes recibidos por día por grupo
        # ejemplo: msj_recibidos:-10000000:2020-12-25
        Stats.incr "msj_recibidos:#{msj.chat.id}:#{Time.now.strftime '%Y-%m-%d'}"

        # Mensajes recibidos por día por grupo por usuario
        # ejemplo: msj_recibidos:<group_id>:<user_id>:2020-12-25
        Stats.incr "msj_recibidos:#{msj.chat.id}:#{msj.from.id}"\
                   ":#{Time.now.strftime '%Y-%m-%d'}"

        # Chats con los que el bot interactúa cada día, según su tipo
        # ejemplo: chats:supergroup:2020-12-25
        Stats.redis.sadd("chats:#{msj.chat.type}:#{Time.now.strftime '%Y-%m-%d'}",
                         msj.chat.id)

        # Hora del último mensaje recibido en un grupo
        # ejemplo: últ_msj:<group_id>
        Stats.set "último_msj:#{msj.chat.id}", msj.date.to_s
    end

    def enviar_stats_grupo(msj, parámetros)
        tiempo = :día
        case parámetros
        when /d[ií]a/i
            tiempo = :día
        when /semana/i
            tiempo = :semana
        when /mes/i
            tiempo = :mes
        end

        texto = 'Uso del bot en '
        texto << { día: 'el último día', semana: 'la última semana',
                   mes: 'el último mes' }[tiempo]

        @tg.send_message(chat_id: msj.chat.id,
                         text: texto)
    end

    def enviar_stats_bot(msj, _parámetros)
        # Que genere estos gráficos:
        #   - mensajes recibidos y enviados por día (gráfico multi area)
        #   - cantidad de chats con los que interactúa por día (gráfico de barras)
        #   - imágenes enviadas por día (gráfico de barras)
        #   - tiempo promedio de procesado del loop, con su desviación estándar (línea)
        # Un parámetro que sea tiempo: n [semana|mes](semana por defecto)
        # para que solo grafique eso.
        # Un parámetro que sea gráficos: [mensajes|chats|imágenes|procesado]
        # o estos separados por coma ',' para que solo genere esos.
        # Los gráficos generados se cachean para no generar el mismo gráfico
        # dos veces en un día.
        # El resultado se envía en forma de botonera.

        tiempo = 30 # 30 días, hacerlo variar según el parámetro

        gráficos = []
        gráficos << gráfico_mensajes_total_bot(tiempo)
        gráficos << gráfico_cantidad_chats(tiempo)
        gráficos << gráfico_imágenes_enviadas(tiempo)
        gráficos << gráfico_tiempo_procesado(tiempo)

        gráficos.each do |img|
            @tg.send_photo(chat_id: msj.chat.id,
                           photo: Faraday::FilePart.new(img, 'image/png'))
        end
    end

    private

    def gráfico_mensajes_total_bot(tiempo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('mensajes_total', tiempo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        gráfico = Gruff::Area.new
        gráfico.theme_pastel
        gráfico.title = 'Mensajes recibidos y enviados'

        etiquetas = generar_hash_labels tiempo

        recibidos = []
        enviados = []
        tiempo.times do |n|
            recibidos << Stats.counter("msj_recibidos:#{etiquetas[n]}")
            enviados  << Stats.counter("msj_enviados:#{etiquetas[n]}")
        end

        gráfico.labels = filtrar_hash_labels etiquetas
        gráfico.data 'Recibidos', recibidos
        gráfico.data 'Enviados', enviados
        gráfico.write nombre
        nombre
    end

    def gráfico_cantidad_chats(tiempo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('cantidad_chats', tiempo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        gráfico = Gruff::Bar.new
        gráfico.theme_pastel
        gráfico.title = 'Total de chats'

        etiquetas = generar_hash_labels tiempo

        datos = { group: [], supergroup: [],
                  private: [], channel: [] }

        tiempo.times do |n|
            datos.each do |nombre, arr|
                arr << Stats.redis.scard("chats:#{nombre}:#{etiquetas[n]}")
            end
        end

        gráfico.labels = filtrar_hash_labels etiquetas
        gráfico.data 'Grupos', datos[:group]
        gráfico.data 'Supergrupos', datos[:supergroup]
        gráfico.data 'Chats privados', datos[:private]
        gráfico.data 'Canales', datos[:private]

        gráfico.write nombre
        nombre
    end

    def gráfico_imágenes_enviadas(tiempo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('imágenes_enviadas', tiempo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        gráfico = Gruff::StackedArea.new
        gráfico.theme_pastel
        gráfico.title = 'Imágenes enviadas'

        etiquetas = generar_hash_labels tiempo

        búsquedas = []
        excedidas = []

        tiempo.times do |n|
            búsquedas << Stats.counter("googleapi:#{etiquetas[n]}")
            excedidas << Stats.counter("googleapi:excedida:#{etiquetas[n]}")
        end

        gráfico.labels = filtrar_hash_labels etiquetas
        gráfico.data 'Búsquedas', búsquedas
        gráfico.data 'Rechazadas por límite diario', excedidas

        gráfico.write nombre
        nombre
    end

    def gráfico_tiempo_procesado(tiempo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('tiempo_procesado_loop', tiempo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        gráfico = Gruff::Line.new
        gráfico.theme_pastel
        gráfico.title = 'Tiempo de procesado de mensaje'

        etiquetas = generar_hash_labels tiempo

        tiempos = []
        desviaciones = []

        tiempo.times do |n|
            valores = Stats.get_times("tiempo_procesado_loop:#{etiquetas[n]}")
            tiempos << valores.avg.to_f
            desviaciones << valores.std_dev.to_f
        end

        gráfico.labels = filtrar_hash_labels etiquetas
        gráfico.data 'Tiempo de procesado (ms)', tiempos
        gráfico.data '+error', (tiempos.map.with_index { |t, i| t + desviaciones[i] })
        gráfico.data '-error', (tiempos.map.with_index { |t, i| t - desviaciones[i] })

        gráfico.write nombre
        nombre
    end

    # Método que devuelve un hash con el formato que necesita Gruff, donde la clave es
    # un índice y su valor la etiqueta. Ejemplo {0 => '2020-12-25', 1 => '2020-12-26'}
    def generar_hash_labels(tiempo)
        etiquetas = {}

        tiempo.times do |n|
            etiquetas[tiempo - n - 1] = (Time.now - (n + 1) * 24 * 60 * 60)
                                        .strftime('%Y-%m-%d')
        end

        etiquetas
    end

    # Método que toma un hasha de labels y les da formato bonito para la imagen.
    def filtrar_hash_labels(hash)
        hash.filter! { |k, _v| (k % 7).zero? }

        hash.each_value do |v|
            v.sub!(/^\d{4}-(\d{2})-(\d{2})/, '\2/\1')
        end

        hash
    end

    # Verifica si existe la carpeta cache y da el nombre del archivo a usar
    def nombre_temporal_stats(prefijo, tiempo)
        Dir.mkdir('cache') unless Dir.exist?('cache')

        "./cache/#{prefijo}_#{Time.now.strftime('%Y-%m-%d')}_#{tiempo}.png"
    end
end
