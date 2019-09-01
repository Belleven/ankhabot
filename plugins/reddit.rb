require 'telegram/bot'

class Dankie

    add_handler Handler::Comando.new(:sub, :sub,
                                     permitir_params: true,
                                     descripción: 'Busco un post en el subreddit que me pidas')

    def sub(msj,subr)
        return if no_hay_subreddit(msj, subr)
        return if verificar_link(msj, subr)
        result = @redditApi.browse(subr)

        if result.is_a? Array and result != []
            a = result.sample

            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: a.url)
            return
        end

            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Perdón #{TROESMAS.sample}, pero ese sub es privado o no existe.")

    end

    def no_hay_subreddit(msj, sub)
        if (hay = sub.nil? || sub.empty?)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'Si no me pasás un subreddit,'\
                                    "está jodida la cosa #{TROESMAS.sample}.")
        end
        hay
    end

    def verificar_link(msj, sub)
        if (inválido = sub =~ /\W/ || sub.size > 21)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Ese nombre de subreddit es inválido, #{TROESMAS.sample}.")
        end
        return inválido
    end

end
