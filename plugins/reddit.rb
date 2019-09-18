require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:sub, :sub,
                                     permitir_params: true,
                                     descripción: 'Busco un post en el subreddit '\
                                                  'que me pidas')

    def sub(msj, subr)
        return if no_hay_subreddit(msj, subr) || sub_inválido(msj, subr)

        resultado = @redditApi.browse(subr)

        if resultado && !resultado.empty?
            post = resultado.sample

            # Tomo atributos
            nombre = "<b>#{html_parser(post.title)}</b>"
            url = post.url
            enlace_post = "https://www.reddit.com#{post.permalink}"
            # Creo texto
            texto = "#{nombre}\n#{enlace_post}"

            # Si no es nil => es gif o video
            if post.media
                if post.media['reddit_video']

                    media = post.media['reddit_video']['fallback_url']
                    alto = post.media['reddit_video']['height']
                    ancho = post.media['reddit_video']['width']

                    # Si es gif
                    if post.media['reddit_video']['is_gif']
                        @tg.send_animation(chat_id: msj.chat.id,
                                           reply_to_message_id: msj.message_id,
                                           animation: media,
                                           width: ancho,
                                           height: alto,
                                           caption: texto,
                                           parse_mode: :html)
                    # Si no asumo video
                    else
                        @tg.send_video(chat_id: msj.chat.id,
                                       reply_to_message_id: msj.message_id,
                                       video: media,
                                       width: ancho,
                                       height: alto,
                                       caption: texto,
                                       parse_mode: :html)
                    end
                elsif post.media['type']
                    if post.media['type'] == 'gfycat.com'
                        enviar_url(msj, texto, post.media['oembed']['thumbnail_url'])
                    elsif post.media['type'] == 'youtube.com'
                        enviar_url(msj, texto, post.media['oembed']['source'])
                    else
                        json_no_reconocido(msj, post)
                    end
                else
                    json_no_reconocido(msj, post)
                end
            # Si no, puede ser texto o imagen
            else
                enviar_url(msj, texto, url)
            end
        else
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Perdón #{TROESMAS.sample}, pero "\
                                   'no encontré nada :(')
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /failed to get HTTP URL content/
            @logger.error('Error al mandar multimedia', al_canal: true)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'Hubo un error y no pude pasar nada :(',
                             parse_mode: :html)
        end
    end

    private

    def enviar_url(msj, texto, url)
        enlace = Link.new url

        mensaje_log = "Enviando link: #{enlace.link}"\
                        " del tipo: #{enlace.type}"
        @logger.info(mensaje_log, al_canal: true)

        case enlace.type
        when :image
            @tg.send_photo(chat_id: msj.chat.id,
                           reply_to_message_id: msj.message_id,
                           photo: enlace.link,
                           caption: texto,
                           parse_mode: :html)
        when :link
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: texto,
                             parse_mode: :html)
        when :gif
            @tg.send_animation(chat_id: msj.chat.id,
                               reply_to_message_id: msj.message_id,
                               animation: enlace.link,
                               caption: texto,
                               parse_mode: :html)
        when :video
            @tg.send_video(chat_id: msj.chat.id,
                           reply_to_message_id: msj.message_id,
                           video: enlace.link,
                           caption: texto,
                           parse_mode: :html)
        else
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No pude encontrar algo bueno '\
                               "para pasar #{TROESMAS.sample}",
                             parse_mode: :html)
        end
    end

    def json_no_reconocido(msj, post)
        mensaje_log = "JSON todavía no validado:\n#{post.media}"
        @logger.info(mensaje_log, al_canal: true)
        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: 'Hubo un error y no pude pasar nada :(',
                         parse_mode: :html)
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

    def sub_inválido(msj, sub)
        if (inválido = sub =~ /\W/ || sub.size > 21)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'Ese nombre de subreddit es '\
                                   "inválido, #{TROESMAS.sample}.")
        end
        inválido
    end
end
