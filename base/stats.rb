class Dankie
#    add_handler Handler::Mensaje.new(:stats_básicas)
#    add_handler Handler::Comando.new(:stats, :enviar_stats_grupo,
#                                     permitir_params: true,
#                                     chats_permitidos: %i[group supergroup],
#                                     descripción: 'Te digo cuanto me usan en el grupo 7u7')
#    add_handler Handler::Comando.new(:stats_bot, :enviar_stats_bot,
#                                     permitir_params: true)



    def stats_básicas(msj)
        # Mensajes recibidos por día
        # ejemplo: mensajes-2020-12-25
        Stats.incr('mensajes-' + Time.now.strftime("%Y-%m-%d"))

        # Chats con los que interactúa cada día, según su tipo
        # ejemplo: supergroup-2020-12-25
        Stats.redis.sadd("#{msj.chat.type}-#{Time.now.strftime "%T-%m-%d"}", msj.chat.id)

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
        texto << {día: 'el último día', semana: 'la última semana',
                  mes: 'el último mes'}[tiempo]



    


        @tg.send_message(chat_id: msj.chat.id,
                         text: texto)
    end
end
