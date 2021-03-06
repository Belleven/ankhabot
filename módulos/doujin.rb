require 'nhentai-api'

class Dankie
    add_handler Handler::Mensaje.new(
        :nhentai_mensaje,
        permitir_editados: false,
        ignorar_comandos: true,
        tipos: [:text]
    )
    add_handler Handler::Comando.new(
        :nhentai,
        :nhentai_comando,
        permitir_params: true
    )
    add_handler Handler::CallbackQuery.new(
        :doujin_nsfw,
        'doujin_nsfw'
    )

    def nhentai_mensaje(msj)
        return unless msj.text.match?(/\A\d{6}\z/)

        doujin = Doujinshi.new msj.text
        return unless doujin.exists?

        enviar_doujin(doujin, msj.chat.id, msj.from.id)
    end

    def nhentai_comando(msj, params)
        if params.nil? || params.match?(/\D/) || (num = params.to_i).zero?
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "Pasame un natural, #{TROESMAS.sample}.")
            return
        end

        doujin = Doujinshi.new(num)

        unless doujin&.exists?
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'No encontré ese doujin.')
            return
        end

        enviar_doujin(doujin, msj.chat.id, msj.from.id)
    end

    def doujin_nsfw(callback)
        match = callback.data.match(/doujin_nsfw:(?<id_usuario>\d+):(?<acción>\w+)/)

        id_usuario = match[:id_usuario].to_i
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id

        if id_usuario != callback.from.id
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Vos no podés hacer eso, '\
                                            "#{TROESMAS.sample}.")
            return
        end

        clave = "botonera:#{id_chat}:#{id_mensaje}"
        return if botonera_expirada(id_chat, id_mensaje, callback.id, clave)

        case match[:acción]
        when 'Borrar'
            borrar_claves_y_msj_doujin(callback, id_chat, id_mensaje, clave)
        when 'Mostrar'
            botones = armar_botonera(
                0,
                obtener_tamaño_lista(id_chat, id_mensaje),
                id_usuario
            )

            @redis.del "activo_nsfw:#{id_chat}:#{id_mensaje}"

            # Si esto explota acá y no se puede editar el msj, la próxima vez que
            # alguien apriete un botón se va a borrar la botonera, así que sale
            # dejar que termine bien el método usando ignorar_excepciones_telegram
            # total la excepción será loggeada igual
            @tg.edit_message_media(
                callback: callback,
                chat_id: id_chat,
                reply_markup: botones,
                message_id: id_mensaje,
                media: {
                    type: 'photo',
                    media: obtener_elemento_lista(id_chat, id_mensaje, 0)
                }.to_json,
                ignorar_excepciones_telegram: true
            )
        end
    end

    private

    def botonera_expirada(id_chat, id_mensaje, id_callback, clave)
        unless @redis.exists?("activo_nsfw:#{id_chat}:#{id_mensaje}") &&
               @redis.exists?(clave) && @redis.exists?("#{clave}:metadatos")

            @tg.answer_callback_query(
                callback_query_id: id_callback,
                text: 'Este porno chino ya expiró, pedite otro'
            )
            borrar_claves_y_msj_doujin(id_chat, id_mensaje, clave)
            return true
        end

        false
    end

    def borrar_claves_y_msj_doujin(callback, id_chat, id_mensaje, clave)
        @redis.del clave
        @redis.del "#{clave}:metadatos"
        @redis.del "activo_nsfw:#{id_chat}:#{id_mensaje}"
        # Para los casos en los que se llama a borrar_claves_y_msj_doujin no importa
        # si revienta delete_message
        @tg.delete_message(chat_id: id_chat, message_id: id_mensaje, callback: callback)
    end

    def enviar_doujin(doujin, id_chat, id_usuario)
        id_mensaje = preguntar_nsfw(id_chat, id_usuario, 'doujin_nsfw')
        return unless id_mensaje

        armar_lista(id_chat, id_mensaje, [doujin.cover, *doujin.pages], 'photo')
        @redis.set "activo_nsfw:#{id_chat}:#{id_mensaje}", 1
    end
end
