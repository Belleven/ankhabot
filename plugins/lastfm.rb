class Dankie
  add_handler CommandHandler.new(:setlastfm, :setlastfm, 'Guarda tu usuario de Last.Fm (Solo necesita tu usuario)')
  add_handler CommandHandler.new(:getlastfm, :getlastfm, 'Devuelve la información registrada de Last.Fm del usuario')
  add_handler CommandHandler.new(:nowplaying, :nowplaying, 'Devuelve la canción más reciente que escucha el usuario que te pusiste')

  def setlastfm(msg)

    parsed = msg.split(" ")
    user = parsed[1].to_s

    if (user == nil)
      err_txt = "Si no me pasás un usuario, está jodida la cosa #{TROESMAS.sample}."
      @tg.send_message(chat_id: msg.chat.id,
                       reply_to_message: msg.message_id,
                       text: err_txt)
      return
    end

    user_id = msg.from.id
    @redis.set("LastFM:#{user_id}", user)
    @redis.bgsave
    txt_done = "Listo #{TROESMAS.sample}. Tu usuario de Last.fm ahora es '#{user}'."
    @tg.send_message(chat_id: msg.chat.id,
                     reply_to_message: msg.message_id,
                     text: txt_done)

  end

  def getlastfm(msg)

    user_id = msg.from.id
    user = @redis.get("LastFM:#{user_id}")
    txt_done = "Por el momento, tu usuario de Last.fm es '#{user}'."
    @tg.send_message(chat_id: msg.chat.id,
                     reply_to_message: msg.message_id,
                     text: txt_done)

  end

  def nowplaying(msg)

    user_id = msg.from.id
    user = @redis.get("LastFM:#{user_id}")
    txt_done = "WIP man. Después lo hago."
    @tg.send_message(chat_id: msg.chat.id,
                     reply_to_message: msg.message_id,
                     text: txt_done)

  end

end