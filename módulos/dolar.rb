require 'nokogiri'
require 'httpclient'

class Dankie
    add_handler Handler::Comando.new(
        :dolar,
        :dolar,
        permitir_params: true,
        descripción: 'Te muestra el precio del dolar'
    )
    def dolar(msj, params)
        factor = obtener_factor_valor_dolar(msj, params)
        return unless factor

        @dolar ||= Dolar.new @logger

        @tg.send_message(
            chat_id: msj.chat.id,
            text: @dolar.obtener_valores(factor),
            parse_mode: :html,
            disable_web_page_preview: true
        )
    end

    private

    def obtener_factor_valor_dolar(msj, params)
        return 1.to_r if params.nil?

        params.gsub!(',', '.')
        return params.to_r if /\A-?(\d{1,9})(\.\d{0,2})?\z/.match? params

        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: msj.message_id,
            text: 'Tenés que pasarme un número válido con hasta 2 decimales entre '\
                  '-999999999,99 y 999999999,99'
        )
        nil
    end
end

class Dolar
    URL_COTIZACIONES = 'https://www.dolarhoy.com/cotizacion'.freeze
    URL_PRINCIPAL = 'https://www.dolarhoy.com'.freeze
    XPATH_ACTUALIZADO = '//span[starts-with(text(),"Actualizado el")]'.freeze

    def initialize(logger)
        @valores_monedas = {}
        @logger = logger
        @cliente = HTTPClient.new

        # Solo se puede loggear una vez por llamada al comando
        @loggeado = false
    end

    def obtener_valores(factor)
        # 3600 es una hora en segundos, me fijo si nunca fue parseada la página o
        # si sí lo fue pero hace más de una hora, en ese caso lo hago de vuelta
        if @fecha_act.nil? || ((fecha_ahora = Time.now) - @fecha_act).to_i > 3600
            actualizar_página_dólar
            # Esto es para que se loggee una sola vez por llamada al comando
            # si se rompe la página
            @loggeado = false
            @fecha_act = fecha_ahora || Time.now
        end

        generar_texto_valores_monedas(factor)
    end

    private

    # Toma las páginas y parsea los valores
    def actualizar_página_dólar
        actualizar_valores_principal(
            Nokogiri.HTML(URI.parse(URL_PRINCIPAL).open, nil, 'UTF-8')
        )

        actualizar_valores_cotizaciones(
            Nokogiri.HTML(URI.parse(URL_PRINCIPAL).open, nil, 'UTF-8')
        )
    end

    # Actualiza los valores de la página principal en el diccionario valores_monedas
    # (el dólar oficial promedio y el dólar solidario), y después toma el texto
    # que dice cuándo fue que la página actualizó los valores.
    def actualizar_valores_principal(página)
        promedio = 'Dólar oficial promedio'
        @valores_monedas[promedio] = {
            'COMPRA' => calc_valor(página, promedio, 'compra',
                                   promedio, :valor_xpath_principal),

            'VENTA' => calc_valor(página, promedio, 'venta',
                                  promedio, :valor_xpath_principal)
        }

        solidario = 'Dólar Solidario'
        @valores_monedas[solidario] = {
            'VENTA' => calc_valor(página, solidario, 'venta',
                                  solidario, :valor_xpath_principal)
        }

        @fecha_valores_en_página = página.xpath(XPATH_ACTUALIZADO).text

        if @fecha_valores_en_página.empty? && !@loggeado
            @logger.error(
                'El xpath para la fecha ya no es válido, se va a mostrar un valor '\
                "viejo (o ninguno). Revisar si cambió el link: #{URL_PRINCIPAL}\n",
                al_canal: true
            )
            @loggeado = true
        else
            @fecha_valores_en_página << ' (hora Argentina)'
        end
    end

    # Actualiza los valores de las otras cotizaciones que no aparecen en la página
    # principal (o sí aparecen pero es más fácil tomarlos acá)
    def actualizar_valores_cotizaciones(página)
        mapeos_nombres = {
            'Banco Nación' => 'Dólar Banco Nación',
            'Dólar Mayorista' => 'Dólar mayorista',
            'Dólar Bolsa' => 'Dólar MEP - bolsa',
            'Contado con liqui' => 'Dólar CCL (contado con liqui)',
            'Dólar Libre' => 'Dólar blue',
            'Euro' => 'Euro oficial',
            'Real brasileño' => 'Real oficial',
            'Peso uruguayo' => 'Peso uruguayo oficial',
            'Peso chileno' => 'Peso chileno oficial'
        }

        mapeos_nombres.each_key do |moneda|
            nombre_real = mapeos_nombres[moneda]

            @valores_monedas[nombre_real] = {
                'COMPRA' => calc_valor(página, moneda, 'compra',
                                       nombre_real, :valor_xpath_cotizaciones),

                'VENTA' => calc_valor(página, moneda, 'venta',
                                      nombre_real, :valor_xpath_cotizaciones)
            }
        end
    end

    # Usa el xpath para buscar los valores en la página, si no los encuentra porque
    # cambió la página entonces toma el último valor que registró (o ninguno si no
    # llegó a hacerlo)
    def calc_valor(página, moneda, cambio, nombre_real, valor_xpath)
        valor = send(valor_xpath, página, moneda, cambio)

        if valor.empty?
            tomar_valor_antiguo_y_loggear(moneda, cambio, nombre_real)
        else
            valor.to_r
        end
    end

    def valor_xpath_cotizaciones(página, moneda, cambio)
        valor_xpath(
            página,
            "//div[text()=\"#{moneda}\"]/following-sibling::div[@class=\"#{cambio}\"]"
        )
    end

    def valor_xpath_principal(página, moneda, cambio)
        valor = valor_xpath(
            página,
            "//a[text()=\"#{moneda}\"]/following-sibling::div[@class=\"values\"]"\
            "//div[@class=\"#{cambio}\"]//div[@class=\"val\"]"
        )

        valor.gsub!('$', '')
        valor
    end

    def valor_xpath(página, xpath)
        página.xpath(xpath).text
    end

    # Loggea en el canal si falla el xpath así nos apuramos a
    # cambiar esta clase otra vez
    def tomar_valor_antiguo_y_loggear(moneda, cambio, nombre_real)
        unless @loggeado
            @logger.error "El xpath para la moneda #{nombre_real} (#{moneda}) en "\
                          "la operación #{cambio} ya no es válido, se va a mostrar "\
                          'un valor viejo (o ninguno). Revisar si cambiaron los '\
                          "links:\n- #{URL_PRINCIPAL}\n- #{URL_COTIZACIONES}\n",
                          al_canal: true
            @loggeado = true
        end

        if @valores_monedas && (mon = @valores_monedas[nombre_real]) &&
           (precio = mon[cambio])

            precio
        end
    end

    # Arma el texto que se tiene que mandar en el mensaje y lo deja en una variable
    # ya que estamos así no hay que generarlo a cada rato
    def generar_texto_valores_monedas(factor)
        array_textos = @valores_monedas.to_a.map do |moneda, valores|
            texto = "<b><i>#{moneda}</i></b>"

            añadir_valor_dólar_a_texto!(texto, valores, 'COMPRA', factor)
            añadir_valor_dólar_a_texto!(texto, valores, 'VENTA', factor)

            texto
        end

        array_textos << @fecha_valores_en_página

        "Valor en pesos argentinos para #{cant_dólares_sustantivo(factor)} "\
        '(y de otras monedas también, en distintas cotizaciones, '\
        "según información de #{URL_PRINCIPAL})\n\n#{array_textos.join("\n\n")}"
    end

    def añadir_valor_dólar_a_texto!(texto, valores, cambio, factor)
        return unless valores.key?(cambio)

        texto << "\n#{cambio}: #{calcular_valor_precio(valores[cambio], factor)}"
    end

    def calcular_valor_precio(precio, factor)
        return 'No encontré el precio F' unless precio

        cálculo_precio = (precio * factor).round(2).to_f
        precio = float_en_string_precio(cálculo_precio)

        "$#{precio}"
    end

    def cant_dólares_sustantivo(valor)
        cantidad = float_en_string_precio(valor.to_f)

        cantidad == '1' ? '1 dólar' : "#{cantidad} dólares"
    end

    def float_en_string_precio(float)
        # Este if chequea si es un "float entero" (ej: 1.0)
        if float == (valor_int = float.to_i)
            valor_int.to_s
        else
            valor_string = float.to_s
            valor_string.gsub!('.', ',')
            valor_string
        end
    end
end
