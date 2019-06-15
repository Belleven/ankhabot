require 'concurrent-ruby'

# Extension de dankie para manejar las poles
class Dankie
    add_handler MessageHandler.new(:pole)
    add_handler CommandHandler.new(:nisman, :send_pole_ranking,
                                   description: 'Muestra el ranking de Nisman')

    # TODO: Ponerle algún flag de solo test a este comando
    #add_handler CommandHandler.new(:darnisman, :_test_dar_nisman)

    def _test_dar_nisman(msg)
        id = msg.reply_to_message ? msg.reply_to_message.from.id : msg.from.id
        mensaje = msg.reply_to_message || msg

        name = if mensaje.from.first_name.empty? then msg.from.id.to_s else html_parser(mensaje.from.first_name) end

        @redis.zincrby("pole:#{msg.chat.id}", 1, id)
        @logger.info("#{name} hizo la nisman en #{msg.chat.id}")
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{name}</b> hizo la Nisman")
    end

    def pole(msg)
        return if @redis.exists("pole:#{msg.chat.id}:done")

        now = Time.now
        next_pole = @tz.utc_to_local(Time.new(now.year, now.month, now.day + 1))
        next_pole = next_pole.to_i
        msg_time = @tz.utc_to_local(Time.at(msg.date)).to_i
        @redis.setex("pole:#{msg.chat.id}:done", next_pole - msg_time, 'ok')
        @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)

        name = if msg.from.first_name.empty? then "ay no c (#{msg.from.id})" else html_parser(msg.from.first_name) end

        @logger.info("#{name} hizo la nisman en #{msg.chat.id}")
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{name}</b> hizo la Nisman")
    end

    def send_pole_ranking(msg)
        texto = "<b>Ranking de Nisman</b>"
        enviado = @tg.send_message(chat_id: msg.chat.id,
                                   parse_mode: 'html',
                                   text: texto + "\n\n<i>cargando...</i>")
        enviado = Telegram::Bot::Types::Message.new(enviado['result'])

        # en vez de esto debería tener otra lista de plugins pesados que
        # trabajen en un hilo aparte
        fork do
            edit_pole_ranking(enviado, texto)
        end
    end

    def edit_pole_ranking(enviado, texto)

        # Tomo las poles de las bases de datos y seteo los espacios para dígitos
        poles = @redis.zrevrange("pole:#{enviado.chat.id}", 0, -1, with_scores: true)
        digits = poles.first[1].to_i.digits.count
        
        # Tomo el total de poles y lo agrego al título
        nismanes = dame_nismanes(poles)
        texto << " (" + nismanes + ")\n"

        # Tomo otras variables que luego usaré
        chat_id = enviado.chat.id
        indice = 0

        poles.each do |val|
        
            # Armo la línea y el cargando... si es que no es la última línea
            linea = "\n<code>#{format("%#{digits}d", val[1].to_i)}</code> " + get_username_link(enviado.chat.id, val[0])
            cargando = if indice == poles.length - 1 then "" else "\n<i>cargando...</i>" end

            # Si el mensaje se pasa de los 4096 caracteres, mando uno nuevo
            if texto.length + linea.length + cargando.length > 4096
               
                # Primero borro el "cargando" del mensaje anterior
                @tg.edit_message_text(chat_id: chat_id, text: texto,
                                      parse_mode: 'html',
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)

                # Después mando el nuevo mensaje
                texto = linea
                enviado = @tg.send_message(chat_id: chat_id, text: texto + cargando,
                                           parse_mode: 'html',
                                           disable_web_page_preview: true,
                                           disable_notification: true)
                enviado = Telegram::Bot::Types::Message.new(enviado['result'])
            
            # Si no, edito el actual 
            else
                texto << linea
                @tg.edit_message_text(chat_id: chat_id, text: texto + cargando,
                                      parse_mode: 'html',
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)
            end

            indice += 1

        end
    end

    def dame_nismanes(poles)
        acumulador = 0
        poles.each do |iterador|
            acumulador += iterador[1].to_i
        end
        return acumulador.to_s
    end


end
