require 'gruff'

class Dankie
    add_handler Handler::Mensaje.new(:stats_básicas)
    #    add_handler Handler::Comando.new(:stats, :enviar_stats_grupo,
    #                                     permitir_params: true,
    #                                     chats_permitidos: %i[group supergroup],
    #                                     descripción: 'Te digo cuanto me usan en el grupo 7u7')
    add_handler Handler::Comando.new(:stats_bot, :enviar_stats_bot,
                                     permitir_params: true)

    def stats_básicas(msj)
        # Mensajes recibidos por hora
        # ejemplo: msj_recibidos:1598302800
        Stats::Contador.incr('msj_recibidos', hora: msj.date, intervalo: 600)

        # Mensajes recibidos por hora por grupo
        # ejemplo: msj_recibidos:-10000000:1598302800
        Stats::Contador.incr("msj_recibidos:#{msj.chat.id}",
                             hora: msj.date, intervalo: 600)

        # Mensajes recibidos por hora por grupo por usuario
        # ejemplo: msj_recibidos:<group_id>:<user_id>:<unix_time>
        Stats::Contador.incr("msj_recibidos:#{msj.chat.id}:#{msj.from.id}",
                             hora: msj.date, intervalo: 600)

        # Chats con los que el bot interactúa cada hora, según su tipo
        # ejemplo: chats:supergroup:1598302800
        Stats::Conjunto.add("chats:#{msj.chat.type}", msj.chat.id,
                            hora: msj.date, intervalo: 600)

        # Hora del último mensaje recibido en un grupo
        # ejemplo: últ_msj:<group_id>
        Stats::Simple.set "último_msj:#{msj.chat.id}", msj.date.to_s
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

    def enviar_stats_bot(msj, parámetros)
        # Que genere estos gráficos:
        #   - mensajes recibidos y enviados por día (gráfico multi area)
        #   - cantidad de chats con los que interactúa por día (gráfico de barras)
        #   - imágenes enviadas por día y límite de la api (gráfico de barras)
        #   - tiempo promedio de procesado del loop, con su desviación estándar (línea)
        # Un parámetro que sea tiempo: n [semana|mes](semana por defecto)
        # para que solo grafique eso.
        # Un parámetro que sea gráficos: [mensajes|chats|imágenes|procesado]
        # Los gráficos generados se cachean para no generar el mismo gráfico
        # dos veces en un día.
        # El resultado se envía en forma de botonera.

        unless DEVS.include? msj.from.id
            @tg.send_message(chat_id: msj.chat.id, reply_to_message: msj.message_id,
                             text: 'Gomen ne, este comando es solo para los admins. >///<')
            return
        end

        unless (parámetros = params_enviar_stats_bot(parámetros))
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "Pasame bien los parámetros, #{TROESMAS.sample}."\
                                   "\n\nModo de uso: escribir más tarde xd.")
            return
        end

        gráficos = []

        desde = Time.now.to_i - (parámetros[:tiempo] * 600)
        desde -= desde % 600

        parámetros[:gráficos].each do |param|
            case param
            when /mensajes/
                gráficos << gráfico_mensajes_total_bot(desde, 600,
                                                       parámetros[:sobreescribir])
            when /chats/
                gráficos << gráfico_cantidad_chats(desde, 600,
                                                   parámetros[:sobreescribir])
            when /imágenes/
                gráficos << gráfico_imágenes_enviadas(desde, 600,
                                                      parámetros[:sobreescribir])
            when /procesado/
                gráficos << gráfico_tiempo_procesado(desde, 600,
                                                     parámetros[:sobreescribir])
            end
        end

        gráficos.each do |img|
            @tg.send_photo(chat_id: msj.chat.id,
                           photo: Faraday::FilePart.new(img, 'image/png'))
        end
    end

    private

    def params_enviar_stats_bot(parámetros)
        parámetros = parse_params(parámetros || 'tiempo: 30 días gráficos: mensajes '\
                                                'chats imágenes procesado')

        if parámetros.class != Hash || (parámetros.keys & %i[tiempo gráficos]).empty?
            return nil
        end

        parámetros[:tiempo] ||= '30 días'
        match = parámetros[:tiempo].match(/(\d+)\s*(h(oras)?|d([ií]as)?|s(emanas)?|m(eses)?)/)
        return nil unless match

        tiempo = match[1].to_i # el primer match es un número
        case match[2][0] # el segundo match es el string, su primer caracter es h, d, s, m
        when 'h'
            tiempo *= 6 # intervalos de 10 minutos
        when 'd'
            tiempo *= 6 * 24
        when 's'
            tiempo *= 6 * 24 * 7
        when 'm'
            tiempo *= 6 * 24 * 30
        else
            return nil
        end

        hash = { tiempo: [tiempo, 3600].min } # número random xd ver que tal queda

        gráficos_por_defecto = %w[mensajes chats imágenes procesado]
        hash[:gráficos] = if parámetros[:gráficos]
                              parámetros[:gráficos].split
                          else
                              gráficos_por_defecto
                          end

        return nil if gráficos_por_defecto | hash[:gráficos] != gráficos_por_defecto

        hash[:sobreescribir] = parámetros[:sobreescribir]

        hash
    end

    def gráfico_mensajes_total_bot(desde, intervalo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('mensajes_total', desde, intervalo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        hasta = Time.now.to_i

        # Busco el primer dato no nulo
        while Stats::Contador.get('msj_recibidos', desde: desde).zero?
            desde += intervalo
            break if desde >= hasta # No vaya a ser que me quede encerrado en el bucle xd
        end

        # Veo con que intervalo hago los saltos de las muestras
        saltos = ampliar_intervalo_datos(desde, hasta, intervalo)

        recibidos = []
        enviados = []
        (desde..hasta).step(saltos).each_cons(2) do |hora, siguiente|
            recibidos << Stats::Contador.get('msj_recibidos', desde: hora,
                                                              intervalo: intervalo,
                                                              hasta: siguiente - intervalo)
            enviados << Stats::Contador.get('msj_enviados', desde: hora,
                                                            intervalo: intervalo,
                                                            hasta: siguiente - intervalo)
        end

        armar_gráfico(Gruff::Area, 'Mensajes recibidos y enviados', desde, saltos,
                      hasta, { 'Recibidos' => recibidos, 'Enviados' => enviados }, nombre)
    end

    def gráfico_cantidad_chats(desde, intervalo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('cantidad_chats', desde, intervalo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        hasta = Time.now.to_i

        # Busco el primer dato no nulo
        while Stats::Conjunto.size('chats:supergroup', desde: desde).zero?
            desde += intervalo
            break if desde >= hasta # No vaya a ser que me quede encerrado en el bucle xd
        end

        # Veo con que intervalo hago los saltos de las muestras
        saltos = ampliar_intervalo_datos(desde, hasta, intervalo)

        datos = { group: [], supergroup: [],
                  private: [], channel: [] }

        (desde..hasta).step(saltos).each_cons(2) do |hora, siguiente|
            datos.each do |nombre, arr|
                arr << Stats::Conjunto.size("chats:#{nombre}", desde: hora,
                                                               intervalo: intervalo,
                                                               hasta: siguiente - intervalo)
            end
        end

        datos.replace({ 'Grupos' => datos[:group], 'Supergrupos' => datos[:supergroup],
                        'Chats privados' => datos[:private], 'Canales' => datos[:private] })

        armar_gráfico(Gruff::StackedBar, 'Total de chats', desde, saltos,
                      hasta, datos, nombre)
    end

    def gráfico_imágenes_enviadas(desde, intervalo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('imágenes_enviadas', desde, intervalo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        hasta = Time.now.to_i

        # Busco el primer dato no nulo
        while Stats::Contador.get('googleapi', desde: desde).zero?
            desde += intervalo
            break if desde >= hasta # No vaya a ser que me quede encerrado en el bucle xd
        end

        # Veo con que intervalo hago los saltos de las muestras
        saltos = ampliar_intervalo_datos(desde, hasta, intervalo)

        búsquedas = []
        excedidas = []

        (desde..hasta).step(saltos).each_cons(2) do |hora, siguiente|
            búsquedas << Stats::Contador.get('googleapi', desde: hora,
                                                          intervalo: intervalo,
                                                          hasta: siguiente - intervalo)
            excedidas << Stats::Contador.get('googleapi:excedida', desde: hora,
                                                                   intervalo: intervalo,
                                                                   hasta: siguiente - intervalo)
        end

        datos = { 'Búsquedas' => búsquedas,
                  'Rechazadas por el límite diario' => excedidas }

        armar_gráfico(Gruff::StackedArea, 'Imágenes enviadas', desde, saltos,
                      hasta, datos, nombre)
    end

    def gráfico_tiempo_procesado(desde, intervalo, forzar_sobreescribir = false)
        nombre = nombre_temporal_stats('tiempo_procesado_loop', desde, intervalo)
        return nombre if !forzar_sobreescribir && File.exist?(nombre)

        hasta = Time.now.to_i

        # Busco el primer dato no nulo
        while Stats::Temporizador.obtener_tiempos('tiempo_procesado_loop',
                                                  hora: desde).promedio.zero?
            desde += intervalo
            break if desde >= hasta # No vaya a ser que me quede encerrado en el bucle xd
        end

        # Veo con que intervalo hago los saltos de las muestras
        saltos = ampliar_intervalo_datos(desde, hasta, intervalo)

        tiempos = []

        (desde..hasta).step(saltos).each_cons(2) do |hora, siguiente|
            valores = (hora..(siguiente - intervalo)).step(intervalo).map do |h|
                Stats::Temporizador.obtener_tiempos('tiempo_procesado_loop',
                                                    hora: h,
                                                    intervalo: intervalo)
            end
            tiempos << Stats::Temporizador.media_ponderada(valores)
        end

        datos = { 'Tiempo de procesado (ms)' => tiempos }

        armar_gráfico(Gruff::Line, 'Tiempo de procesado de mensaje', desde, saltos,
                      hasta, datos, nombre)
    end

    # Método que devuelve un hash con el formato que necesita Gruff, donde la clave es
    # un índice y su valor es un texto con la fecha en un formato bonito.
    def generar_hash_labels(desde, intervalo, hasta)
        etiquetas = {}

        (desde..hasta).step(intervalo).with_index do |hora, i|
            etiquetas[i] = hora
        end

        saltos = [etiquetas.size / 7, 1].max
        etiquetas.filter! { |k, _v| (k % saltos).zero? }

        etiquetas.transform_values! do |hora|
            Time.at(hora, in: @tz.utc_offset).strftime "%m-%d\n%H:%M"
        end

        etiquetas
    end

    def ampliar_intervalo_datos(desde, hasta, intervalo)
        intervalo *= 6 while (desde..hasta).step(intervalo).size > 36

        intervalo
    end

    def armar_gráfico(tipo, título, desde, saltos, hasta, datos, archivo)
        gráfico = tipo.new
        gráfico.theme_pastel
        gráfico.title = título
        gráfico.labels = generar_hash_labels(desde, saltos, hasta)

        datos.each { |nombre, arr| gráfico.data(nombre, arr) }
        gráfico.write archivo
        archivo
    end

    # Verifica si existe la carpeta cache y da el nombre del archivo a usar
    def nombre_temporal_stats(prefijo, tiempo, intervalo)
        Dir.mkdir('cache') unless Dir.exist?('cache')

        "./cache/#{prefijo}_#{Time.now.to_i / intervalo * intervalo}_#{tiempo}.png"
    end
end
