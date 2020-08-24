class Dankie
    add_handler Handler::EventoDeChat.new(:nuevos_miembros,
                                          chats_permitidos: %i[group supergroup],
                                          tipos: [:new_chat_members])

SALUDO_VARIOS_MIEMBROS =  ['Bienvenidos ', 'Hola ', 'Buenas ', 'Que onda ']
SALUDO_UN_MIEMBRO =       ['Bienvenido ', 'Hola ', 'Buenas ', 'Que onda ']
EXTRA_UN_MIEMBRO  =       [', pasá y sentate al fondo.', ', ponete cómodo.',
                                ', querés bizcochitos?', ', qué te trae por acá?']
EXTRA_VARIOS_MIEMBROS =   [', pasen y siéntense al fondo.', ', pónganse cómodos.',
                            ', quieren bizcochitos?', ', qué los trae por acá?']                               



    def nuevos_miembros(msj)

        cantidad_miembros = msj.new_chat_members.size

        if msj.new_chat_members.any? { |miembro| miembro.id == @user.id }

            nombre_bot = primer_nombre(@user)
            saludo = "yoroshikune soy #{nombre_bot} nwn arigato x meterme al grupete"
            

        elsif cantidad_miembros == 1
    
            nombre = primer_nombre(msj.new_chat_members[0])
            saludo = SALUDO_UN_MIEMBRO.sample + nombre + EXTRA_UN_MIEMBRO.sample

          
        elsif cantidad_miembros >= 2
            
            texto = concatenarSaludos(msj, SALUDO_VARIOS_MIEMBROS.sample)
            saludo = texto + EXTRA_VARIOS_MIEMBROS.sample
           
        end

        @tg.send_message(chat_id: msj.chat.id,
                                text: saludo,
                                reply_to_message_id: msj.message_id)
    end


    def concatenarSaludos(msj, texto)

         índice = 0
         cantidad_miembros = msj.new_chat_members.size
                #Saluda a varios usuarios nuevas
                msj.new_chat_members.each do |nuevo_miembro|
                    texto << primer_nombre(nuevo_miembro)

                    if índice < cantidad_miembros - 2
                        texto << ', '
                    elsif índice == cantidad_miembros - 2
                        texto << ' y '
                    end
                    índice += 1
                end
        return texto
    end            
end    