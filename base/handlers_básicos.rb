class Dankie
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')
    add_handler Handler::Mensaje.new(:actualizar_nombres_usuarios)


end

