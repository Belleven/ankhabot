class Dankie
    add_handler NuevosMiembros.new(:nuevos_miembros)

    def nuevos_miembros(msj)
        if msj.new_chat_members.size == 1
            saludo = ['Bienvenido ', 'Hola ', 'Buenas ', 'Que onda '].sample
            nombre = primer_nombre(msj.new_chat_members[0])
            extra = [', pasá y sentate al fondo.', ', ponete cómodo.', ', querés bizcochitos?', ', qué te trae por acá?'].sample
            @tg.send_message(chat_id: msj.chat.id, text: saludo + nombre + extra)

        else
            texto = ['Bienvenidos ', 'Hola ', 'Buenas ', 'Que onda '].sample

            msj.new_chat_members.each do |nuevo_miembro, índice|
                texto << primer_nombre(nuevo_miembro)

                texto << if índice == msj.new_chat_members.size - 1
                             ' y '
                         else
                             ', '
                         end
            end

            extra = [', pasen y siéntense al fondo.', ', pónganse cómodos.', ', quieren bizcochitos?', ', qué los trae por acá?'].sample
            @tg.send_message(chat_id: msj.chat.id, text: texto + extra)
        end
    end

    def primer_nombre(usuario)
        if usuario.first_name.nil?
            "ay no c (#{usuario.id})"
        else
            usuario.first_name
        end
    end
end
