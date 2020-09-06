require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(
        :sub,
        :sub,
        permitir_params: true,
        descripción: 'Busco un post en el subreddit que me pidas'
    )

    def sub(msj, subr)
        return if no_hay_subreddit(msj, subr) || sub_inválido(msj, subr)

        resultado = @redditApi.browse(subr)

        if !resultado || resultado.empty?
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Perdón #{TROESMAS.sample}, pero "\
                                   'no encontré nada :('
            )
        else
            # Tomo post
            post = resultado.sample
            # Tomo atributos
            título = "<b>#{post.title}</b>"
            id_post = post.id.split('_').last

            # Separo según el tipo de resultado
            case post.kind
            # t3 => Link
            when 't3'
                # Mando el post
                mandar_post(msj, post, título, id_post)
            # t5 => Subreddit
            when 't5'
                # Mando el sub
                mandar_sub(msj, post, título)
            # Otros
            else
                # Mando otro
                mandar_otro(msj, post, título, id_post, subr)
            end
        end
    end

    private

    def mandar_post(msj, post, título, id_post)
        enlace_post = "redd.it/#{id_post}"
        # Si es un posteo de texto, lo mando así
        if post.selftext && !post.selftext.empty?
            @logger.info("Mandando post texto: #{post.url}", al_canal: false)

            # Me fijo que el mensaje supere los 4096 cracteres (y si lo hace, lo corto)
            longitud_otros = título.length + enlace_post.length + 17
            # Si el texto parseado + título + post + otros caracteres que voy a poner
            # para acomodar el texto (como <i> o </i> o \n, etc) supera los 4096
            # caracteres, corto el post para que no lo haga y le agrego tres puntos
            # para que se sepa que continúa
            texto_post = if post.selftext.length + longitud_otros > 4096
                             "#{post.selftext[0..(4092 - longitud_otros)]}..."
                         else
                             post.selftext
                         end

            texto = "#{título}\n\n"\
                    "<i>#{texto_post}</i> <b>[</b>"\
                    "<a href=\"#{enlace_post}\">post</a><b>]</b>"

            @tg.send_message(
                chat_id: msj.chat.id,
                text: texto,
                parse_mode: :html,
                disable_web_page_preview: true
            )

        # Si es un video de reddit, lo acomodo
        elsif post.url.include?('v.redd.it/') && post.media &&
              post.media['reddit_video'] &&
              post.media['reddit_video']['fallback_url']

            # Tomo link
            enlace = post.media['reddit_video']['fallback_url']
            # Armo el texto de acompañamiento
            texto = "#{título} <b>[</b><a href=\"#{enlace_post}\">post</a><b>]</b>"

            # Depende si es gif o video, cómo lo mando
            if post.media['reddit_video']['is_gif']
                @logger.info("Mandando gif: #{enlace}", al_canal: false)
                @tg.send_animation(
                    chat_id: msj.chat.id,
                    animation: enlace,
                    caption: texto,
                    parse_mode: :html
                )
            else
                # TODO: en un futuro descargar el archivo de video y resubirlo
                @logger.info("Mandando video: #{enlace}", al_canal: false)
                enviar_multimedia(msj, título, enlace_post, post.url)
                # @tg.send_video(chat_id: msj.chat.id,
                #               video: enlace,
                #               caption: texto,
                #               parse_mode: :html)
            end

        # Si no, mando la multimedia/link
        else
            enviar_multimedia(msj, título, enlace_post, post.url)
        end
    end

    def mandar_sub(msj, post, título)
        # Loggeo
        @logger.info("La búsqueda devolvió otro sub: #{post.url}",
                     al_canal: false)
        # Armo el textazo
        texto = 'El sub que me pasaste redirige a este:'\
                "\n\n#{título}\nhttps://www.reddit.com#{post.url}"
        # Mando respuesta
        @tg.send_message(
            chat_id: msj.chat.id,
            text: texto,
            parse_mode: :html
        )
    end

    def mandar_otro(msj, post, título, id_post, subr)
        # Loggeo lo que me haya devuelto esto
        tipos_de_resultados = { 't1' => 'COMENTARIO', 't2' => 'CUENTA',
                                't4' => 'MENSAJE', 't6' => 'PREMIO' }
        error = "La búsqueda de '#{subr}' me devolvió un/a "\
                "#{tipos_de_resultados[post.kind]} que no se cómo manejar"
        @logger.error(error, al_canal: true)
        # Mando igual un linkazo
        enlace_post = "redd.it/#{id_post}"
        mandar_link_error(
            msj,
            "#{título} <b>[</b><a href=\"#{enlace_post}\">post</a><b>]</b>"
        )
    end

    def enviar_multimedia(msj, título, enlace_post, enlace_media)
        enlace = Link.new enlace_media, :link

        mensaje_log = "Enviando link: #{enlace.link}"\
                        " del tipo: #{enlace.type}"
        @logger.info(mensaje_log, al_canal: false)

        # Al texto de acompañamiento le pongo el título del post
        texto = título

        case enlace.type
        when :image
            # Agrego link del post
            texto << " <b>[</b><a href=\"#{enlace_post}\">post</a><b>]</b>"
            @tg.send_photo(
                chat_id: msj.chat.id,
                photo: enlace.link,
                caption: texto,
                parse_mode: :html
            )
        when :link
            # Agrego link media y link post
            texto << "\n#{html_parser enlace.link}"\
                     " <b>[</b><a href=\"#{enlace_post}\">post</a><b>]</b>"
            @tg.send_message(
                chat_id: msj.chat.id,
                text: texto,
                parse_mode: :html
            )
        when :gif
            # Agrego link del post
            texto << " <b>[</b><a href=\"#{enlace_post}\">post</a><b>]</b>"
            @tg.send_animation(
                chat_id: msj.chat.id,
                animation: enlace.link,
                caption: texto,
                parse_mode: :html
            )
        when :video
            # Agrego link del post
            texto << " <b>[</b><a href=\"#{enlace_post}\">post</a><b>]</b>"
            @tg.send_video(
                chat_id: msj.chat.id,
                video: enlace.link,
                caption: texto,
                parse_mode: :html
            )
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.to_s.include? 'failed to get HTTP URL content'
            error = 'Error de telegram con el link al querer mandar multimedia'
            @logger.error(error, al_canal: true)
        else
            @logger.error("Error al querer mandar el linkazo: #{e}", al_canal: true)
        end
        # Si hay error mando el texto que me quedó
        mandar_link_error(msj, texto)
    end

    def no_hay_subreddit(msj, sub)
        if (hay = sub.nil? || sub.empty?)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Si no me pasás un subreddit, '\
                                    "está jodida la cosa #{TROESMAS.sample}."
            )
        end
        hay
    end

    def sub_inválido(msj, sub)
        if (inválido = sub.match?(/\W/) || sub.size > 21)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Ese título de subreddit es '\
                                   "inválido, #{TROESMAS.sample}."
            )
        end
        inválido
    end

    def mandar_link_error(msj, texto)
        # Paso el link del post o ese error si no pude conseguir el linkazo
        texto = 'Hubo un error y no pude pasar nada :(' if texto.nil?
        @tg.send_message(
            chat_id: msj.chat.id,
            text: texto,
            parse_mode: :html
        )
    end
end
