class Dankie
    add_handler CommandHandler.new(:salir, :salir)

    def salir(msj)
        if validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id)
            @tg.leave_chat(chat_id: msj.chat.id)
        end
    end
end
