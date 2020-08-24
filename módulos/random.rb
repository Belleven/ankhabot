require 'telegram/bot'

$indice = 8

class Dankie
	 add_handler Handler::Comando.new(:tirada, :tirada,
                                     descripción: 'Tiro un dado de dragones y mazmorras')

		
#Comprueba que sea un texto valido
	def comprobar_dado(texto)
		return texto.match(/[1-9]*d(4|6|8|10|12|20)(\+[1-9])?/)
	end	

	def enviar_mensaje_error(error_code)
		if error_code == "caras"
			dado_texto = "Mira kpo/a, vos te pensas que te voy a tirar tantas veces el dado? Hasta 666 te lo hago sin problemas, pero ubicate"
		elsif error_code == "modificador"
			dado_texto = "Por que queres un modificador tan alto??? Hasta 999 te acepto pero sino es mucho trabajo"
		end	
		return dado_texto
	end		
					

#A partir del texto, consigue la informacion de la cantidad de tiradas que se necesita
#Solo se permiten hasta 666 tiradas
	def get_cantidad_dados(texto)
		contador = 0
		#Si lo primero que aparece es un d, entonces significa que esta implicito que la cantidad de tiradas es una sola		
		if texto[$indice] == "d"
			cantidad_dados = "1"
		else 
			cantidad_dados = ""	
			while texto[$indice] != "d" and contador < 3 do
				cantidad_dados = cantidad_dados + texto[$indice]
				contador = contador + 1
				$indice = $indice + 1
			end
		end
		#Si contador es 3, significa que el numero tiene 4 digitos con lo cual se paso del limite
		#o la cantidad es mayor a 666, devuelve -1 indicando que se produzco un error
		if contador == 3 or cantidad_dados.to_i > 666
			cantidad_dados = "-1"
		end
		return cantidad_dados
	end		
		

			
#Devuelve la cantidad de caras de un texto
	def get_cantidad_caras(texto)
		$indice = $indice + 1
		cantidad_caras = ""
		while texto[$indice] != "+" and texto[$indice] != "." do
			cantidad_caras = cantidad_caras + texto[$indice]
			$indice = $indice + 1
		end
		return cantidad_caras	
	end		

	def get_modificador(texto)
		$indice = $indice + 1
		contador = 0
		modificador = ""
		while texto[$indice] != "." and contador < 4 do
			modificador = modificador + texto[$indice]
			contador = contador + 1
			$indice = $indice + 1
		end
		if contador == 4
			modificador = "-1"
		end	
		return modificador
	end		
	

	def conseguir_valor_dado(cantidad_caras = 6, cantidad_dados = 1, modificador = "")
		dado = Dado.new(cantidad_caras.to_i)
		dado_texto = ""
		i = 0
		while i < cantidad_dados.to_i do 
			valor_dado = dado.tirar_dado()
			if modificador == ""
				dado_texto << (valor_dado.to_s + " ")
			else	
				dado_texto << (valor_dado.to_s + "+" + modificador + " ")
			end	
			i = i + 1
		end
		return dado_texto
	
	end	



#Funcion que tira varias veces un dado con modificadores
	def tirada(msj)
		
		texto = msj&.text + "."


		if comprobar_dado(texto)
			cantidad_dados = get_cantidad_dados(texto)

			#Si es -1, indica que se quizo tirar mas veces de lo permitido
			if cantidad_dados == "-1"
				error_code = "caras"
				error_flag = 1
				dado_texto = enviar_mensaje_error(error_code)
			else	

				number_string  = get_cantidad_caras(texto)
				modificador = ""
				#El texto puede no tener modificadores, por eso hay que comprobarlo
				if texto[$indice] == "+"
					modificador    = get_modificador(texto)
				end	

				#Si se produce un modificador mas alto de lo aceptado
				if (modificador == "-1")
					error_code = "modificador"
					error_flag = 1
					dado_texto = enviar_mensaje_error(error_code)

				else
					dado_completo = dado_completo_string(texto)
					dado_texto = conseguir_valor_dado(number_string, cantidad_dados,  modificador)
					dado_texto = dado_completo + "\n" + dado_texto
					
				end
			end
		else
			dado_texto = "Kpo, no sabes jugar D&D? El comando es /tirada <NdR+M> donde N es el numero de tiradas y R son las caras usadas que solo pueden ser 4, 6, 8, 10, 12, 20. Si solo esta el rango, devuelve una sola tirada. M es un modificador que aumenta el valor de tus tiros, puede no estar"	
		end			
		$indice = 8


		@tg.send_message(chat_id: msj.chat.id, text:dado_texto)


	end

	def dado_completo_string(texto)
		dado_completo = ""
		$indice = 8
		while texto[$indice] != "." do
			dado_completo = dado_completo + texto[$indice]
			$indice = $indice + 1
		end	
		return dado_completo
	end		

end	

class Dado
	def initialize(cantidad_caras)
		@caras = cantidad_caras - 1
	end	
	def tirar_dado()
		@valor_tirada = Random.rand @caras
		return @valor_tirada + 1
	end	

end	

