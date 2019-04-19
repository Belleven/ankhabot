# coding: utf-8
require 'telegram/bot'

class Dankie
    command blacklist: 'Blacklist updater in the bot'

    def blacklist(msg)
      
      if (!@blacklist_populated)
        populate_blacklist() # should get redis, etc. For now, nothing
      end

      return unless msg.is_a?(Telegram::Bot::Types::Message)
      
      cmd = parse_command(msg)

      return unless cmd && (cmd[:command] == :ignore || cmd[:command] == :unignore)

      #TODO: sólo admins ejecutan esto

      #return if !admin msg.from.id
      #NB: mantener lista de admins

      id = 0

      if (cmd[:params])
        id = msg.from.id #si no lo tiene todo mal
      else if msg&.reply_to_message
        id = msg.reply_to_messsage&.from.id
      else
        send_message(chat_id: msg.chat.id,
                     reply_to_message: msg.message_id
                     text: 'nope')
        return
      end

      return if (id == 98631116 || id == 0) #sanity check
      
      if cmd[:command] == :ignore
        ignore(id)
      else if cmd [:command] == :unignore
        unignore(id)
      end
      
    end

    def ignore(id)
      @blacklist.push(id)
    end
    
    def unignore(id)
      @blacklist.delete(id)
    end
    
    def save()
      #TODO use @redis
    end
    
    def populate_blacklist()
      #TODO: read redis and populate dankie array
      #TODO: learn redis
      @blacklist_populated = true
    end
    
end
