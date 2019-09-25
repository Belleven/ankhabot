require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:sub, :sub,
                                     permitir_params: true,
                                     descripción: 'Busco un post en el subreddit '\
                                                  'que me pidas')

    def sub(msj, subr)
        return if no_hay_subreddit(msj, subr) || sub_inválido(msj, subr)

        resultado = @redditApi.browse(subr)

        if resultado.nil? || resultado.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Perdón #{TROESMAS.sample}, pero "\
                                   'no encontré nada :(')
        else
            post = resultado.sample

            # Tomo atributos
            nombre = "<b>#{html_parser(post.title)}</b>"
            enlace_post = "redd.it/#{post.id.split('_').last}"

            puts post.media if post.url.include? 'v.redd.it'

            # Mando el sub
            enviar_post(msj, nombre, enlace_post, post.url)

        end
    end

    private

    def enviar_post(msj, nombre, enlace_post, enlace_media)
        enlace = Link.new enlace_media, :link

        mensaje_log = "Enviando link: #{enlace.link}"\
                        " del tipo: #{enlace.type}"
        @logger.info(mensaje_log, al_canal: true)

        # Al texto de acompañamiento le pongo el nombre del post
        texto = nombre

        case enlace.type
        when :image
            # Agrego link del post
            texto << "\nPost: #{enlace_post}"
            @tg.send_photo(chat_id: msj.chat.id,
                           photo: enlace.link,
                           caption: texto,
                           parse_mode: :html)
        when :link
            # Agrego link media y link post
            texto << "\n#{html_parser(enlace.link)}"\
                     "\n\nPost: #{enlace_post}"
            @tg.send_message(chat_id: msj.chat.id,
                             text: texto,
                             parse_mode: :html)
        when :gif
            # Agrego link del post
            texto << "\nPost: #{enlace_post}"
            @tg.send_animation(chat_id: msj.chat.id,
                               animation: enlace.link,
                               caption: texto,
                               parse_mode: :html)
        when :video
            # Agrego link del post
            texto << "\nPost: #{enlace_post}"
            @tg.send_video(chat_id: msj.chat.id,
                           video: enlace.link,
                           caption: texto,
                           parse_mode: :html)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /failed to get HTTP URL content/
            @logger.error('Error al mandar multimedia', al_canal: true)
        end

        # Paso el link del post o ese error si no pude conseguir el linkazo
        texto = 'Hubo un error y no pude pasar nada :(' if texto.nil?
        @tg.send_message(chat_id: msj.chat.id,
                         text: texto,
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
