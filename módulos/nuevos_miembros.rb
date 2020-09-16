class Dankie
    add_handler Handler::EventoDeChat.new(:nuevos_miembros,
                                          chats_permitidos: %i[group supergroup],
                                          tipos: [:new_chat_members])

    def nuevos_miembros(msj)
        cantidad_miembros = msj.new_chat_members.size

        if msj.new_chat_members.any? { |miembro| miembro.id == @user.id }

            nombre_bot = primer_nombre(@user)
            saludo = "yoroshikune soy #{nombre_bot} nwn arigato x meterme al grupete"

        elsif cantidad_miembros == 1

            saludo_un_miembro = ['Bienvenido ', 'Hola ', 'Buenas ', 'Que onda ']
            extra_un_miembro  = [', pasá y sentate al fondo.', ', ponete cómodo.',
                                 ', querés bizcochitos?', ', qué te trae por acá?']

            nombre = primer_nombre(msj.new_chat_members[0])
            saludo = saludo_un_miembro.sample + nombre + extra_un_miembro.sample

        elsif cantidad_miembros >= 2

            saludo_varios_miembros =  ['Bienvenidos ', 'Hola ', 'Buenas ', 'Que onda ']
            extra_varios_miembros =   [', pónganse cómodos.', ', quieren bizcochitos?',
                                       ', qué los trae por acá?',
                                       ', pasen y siéntense al fondo.']

            texto = concatenar_saludos(msj, saludo_varios_miembros.sample)
            saludo = texto + extra_varios_miembros.sample

        end

        @tg.send_message(chat_id: msj.chat.id,
                         text: saludo,
                         reply_to_message_id: msj.message_id)
    end

    def concatenar_saludos(msj, texto)
        cantidad_miembros = msj.new_chat_members.size
        # Saluda a varios usuarios nuevas
        msj.new_chat_members.each_with_index do |nuevo_miembro, índice|
            texto << primer_nombre(nuevo_miembro)
            if índice < cantidad_miembros - 2
                texto << ', '
            elsif índice == cantidad_miembros - 2
                texto << ' y '
            end
        end

        texto
    end
end
