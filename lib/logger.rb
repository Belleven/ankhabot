require 'telegram/bot'

class DankieLogger
    attr_reader :client
    attr_accessor :logger

    def initialize(logger, canal_logging, cliente)
        @logger = logger
        @canal_logging = canal_logging
        @client = cliente
    end

    def debug(texto, al_canal: false, backtrace: nil)
        log(Logger::DEBUG, texto, al_canal: al_canal, backtrace: backtrace)
    end

    def warn(texto, al_canal: false, backtrace: nil)
        log(Logger::WARN, texto, al_canal: al_canal, backtrace: backtrace)
    end

    def info(texto, al_canal: false, backtrace: nil)
        log(Logger::INFO, texto, al_canal: al_canal, backtrace: backtrace)
    end

    def error(texto, al_canal: false, backtrace: nil)
        log(Logger::ERROR, texto, al_canal: al_canal, backtrace: backtrace)
    end

    def fatal(texto, al_canal: false, backtrace: nil)
        log(Logger::FATAL, texto, al_canal: al_canal, backtrace: backtrace)
    end

    def unknown(texto, al_canal: false, backtrace: nil)
        log(Logger::UNKNOWN, texto, al_canal: al_canal, backtrace: backtrace)
    end

    def excepcion_texto(excepcion)
        texto_excepcion = excepcion.to_s
        texto = if !(texto_excepcion.nil? || texto_excepcion.empty?)
                    '(' + excepcion.class.to_s + ') ' + texto_excepcion
                else
                    'EXCEPCIÓN SIN NOMBRE'
                end

        if excepcion.backtrace.nil?
            return texto, nil
        else
            # La regex turbina esa es para no doxxearnos a los que usamos linux
            # / es para "/" => /home/ es para "/home/"
            # [^/]+ es para que detecte todos los caracteres que no sean "/" =>
            # /home/user/dankie/... queda como /dankie/...
            return texto, excepcion.backtrace.join("\n").gsub(%r{/home/[^/]+}, '~')
        end
    end

    private

    def log(nivel, texto, al_canal: false, backtrace: nil)
        texto = 'LOG SIN NOMBRE' if texto.nil? || texto.empty?

        if backtrace.nil?
            @logger.log(nivel, texto)
        else
            @logger.log(nivel, texto + "\n" + backtrace)
        end

        return unless al_canal

        unless backtrace.nil?
            lineas = '<pre>' + ('-' * 30) + "</pre>\n"
            texto << "\n#{lineas}#{lineas} Rastreo de la excepción:\n#{lineas}"
            texto << "<pre>#{html_parser(backtrace)}</pre>"
        end

        nivel = case nivel
                when Logger::DEBUG
                    'DEBUG'
                when Logger::INFO
                    'INFO'
                when Logger::WARN
                    'WARN'
                when Logger::ERROR
                    'ERROR'
                when Logger::FATAL
                    'FATAL'
                when Logger::UNKNOWN
                    'UNKNOWN'
                end

        horario = Time.now.strftime('%FT%T.%6N')
        lineas = '<pre>' + '-' * (8 + horario.length + nivel.length) + "</pre>\n"

        enviar = "<pre>[#{horario}] -- #{nivel} :</pre>\n" + lineas + texto
        @client.api.send_message(chat_id: @canal_logging, text: enviar,
                                 parse_mode: :html, disable_web_page_preview: true)
    rescue StandardError => e
        begin
            mensaje = if backtrace.nil? || backtrace.empty?
                      then "\nMientras se loggeaba surgió una excepción:\n"
                      else "#{backtrace}\n\n\nMientras se manejaba una excepción"\
                           " surgió otra:\n"
                      end

            lineas = ('-' * 30) + "\n"
            texto_excepcion = lineas + mensaje

            excepcion = e.to_s
            texto_excepcion << if !(excepcion.nil? || excepcion.empty?)
                                   excepcion
                               else
                                   'ERROR SIN NOMBRE'
                               end

            texto_excepcion << "\n#{lineas}#{lineas}#{e.backtrace.join("\n")}\n"\
                               "#{lineas}#{lineas}\n"
            @logger.fatal(texto_excepcion)
        rescue StandardError
            puts "\nFATAL, múltiples excepciones.\n"
        end
    end

    def html_parser(texto)
        html_dicc = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;' }
        texto.gsub(/&|<|>|\"/, html_dicc)
    end
end
