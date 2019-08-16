class Dankie
    add_handler Handler::EventoDeChat.new(:nuevos_miembros, tipos: [:new_chat_members])

    def nuevos_miembros(msj)
        if msj.new_chat_members.any? { |miembro| miembro.id == @user.id }
            nombre_bot = @user.first_name.nil? ? @user.id.to_s : @user.first_name
            saludo = "hyoroskune soy #{nombre_bot} nwn arigato x meterme al grupete"
            @tg.send_message(chat_id: msj.chat.id, text: saludo)

        elsif msj.new_chat_members.size == 1
            saludo = ['Bienvenido ', 'Hola ', 'Buenas ', 'Que onda '].sample
            nombre = primer_nombre(msj.new_chat_members[0])
            extra = [', pasá y sentate al fondo.', ', ponete cómodo.',
                     ', querés bizcochitos?', ', qué te trae por acá?'].sample
            @tg.send_message(chat_id: msj.chat.id, text: saludo + nombre + extra)

        elsif msj.new_chat_members.size >= 2
            texto = ['Bienvenidos ', 'Hola ', 'Buenas ', 'Que onda '].sample

            índice = 0
            msj.new_chat_members.each do |nuevo_miembro|
                texto << primer_nombre(nuevo_miembro)

                if índice < msj.new_chat_members.size - 2
                    texto << ', '
                elsif índice == msj.new_chat_members.size - 2
                    texto << ' y '
                end
                índice += 1
            end

            extra = [', pasen y siéntense al fondo.', ', pónganse cómodos.',
                     ', quieren bizcochitos?', ', qué los trae por acá?'].sample
            @tg.send_message(chat_id: msj.chat.id, text: texto + extra)
        end
    end
end
