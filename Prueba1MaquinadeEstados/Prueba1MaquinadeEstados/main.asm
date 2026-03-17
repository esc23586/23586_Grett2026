
/*
* Prueba1MaquinadeEstados.asm
*
* Creado: 07 de marzo 2026
* Autor : Grettel Escobedo 23586
* Descripción:						PROYECTO 1: Maquina de Estados- Reloj
*
*----
* TIMERS: se utiliza timer1 para conteo de segundos, mientras que Timer0 se utiliza para multiplexación con aproximadamente 1ms
*Se utilizará registros de roposito general para llevar la cuenta de milisegundos del Timer0 
*Cuando llegué a 500ms, ocurre el parpadeo con los dos puntitos conectados a PD7

*----
*Cada display tendrá una localidad en RAM para guardar su valor HEX que tiene que "sacar" PORTD. Cada localidad será nombrada...
;"DISPn_VALUE". Existen los Displays "0,1,2,3". En estos es que se presentan los numeros del reloj y de la Fecha.

*----- 
*Se utilizará un registro de propósito general nombrado "MODO" cuya función será guardar "flags" varias.
*Su CODIFICACIÓN es la siguiente: {00, SETUP_VALUE, BLINKSTATE, SETUP_, MODE_SELECT, MODO1, MODO0}
*"MODOn" indica si se debe MOSTRAR "Hora", "Fecha" o "Alarma"; sea en modo normal o en configuración. "00" es "Hora", "01" es "Fecha", y "10" es Alarma".
 
//Explicación de cada uno//

*"SETUP_" indica si se busca configurar algún modo de los mencionados arriba. Ello supone un parpadeo en el Display correspondiente.
* De "SETUP_VALUE" se hablará más en profundidad en la explicación de interfaz de usuario. Linea:
*"MODE_SELECT" indica si el usuario busca cambiar de modo. 
*"MODE_SELECT" y "SETUP_" no pueden estar encendidos a la vez. Ello se detallará con la interfaz del usuario.
*"BLINKSTATE" indica en qué estado deben estar los DISPS en su posible parpadeo para que sea interpretado por...
*la multiplexación en la interrupción de TIM0. Los displays deben parpadear acorde a los dos puntos.
*En general, este registro será actualizado con la interfaz del usuario, la cual es extendida más adelante.

*NOTA IMPORTANTE: se utilizará un registro de proposito regeneral para guardar el orden de multiplexación de los displays.


*-------------
*Pinchange en port C (todos los botones para la interfáz del usuario)
*-------------

*Displays y localidades de memoria 
* Se utiliza localidades de memoria para guardar minutos horas y días
* Se utilizó como en el laboratorio 3,la división de unidades y decenas para un mejor oden en los diplays 
*En la Ram igualmente esta guardado el tiempo configurado para la alarma
*-----------------


*El MAIN LOOP  se puede dividir por 5 partes escenciales:

; --> PASO UNO: Actualizar parpadeo de dos puntos y posibles displays.
; --> PASO DOS: Actualizar variables de conteo del reloj.
; --> PASO TRES: Revisar si la alarma debe sonar.
; --> PASO CUATRO: Revisar si el usuario quiere configurar algún modo del reloj.
; --> PASO CINCO: Guardar en cada localidad "DISPn_VALUE" lo que tenga que mostrar cada display según el modo establecido.


*Parte aspectos importantes sobre la ALARMA:

;La alarma tendrá su propio registro nombrado ALARM_REGISTER, cuya codificación...
;es la siguiente: {00000,ALARM_VALID,ALARM_ACTIVE,ALARM_SET}.

*"ALARM_SET" es una flag que indicará si hay alarma configurada.
*"ALARM_ACTIVE" es una flag que indica si la alarma está sonando o no.
- Está flag es importante para la interfaz del usuario, pues, cuando la alarma esté sonando,
- el botón del Encoder deberá apagar la alarma; el sistema sabrá que el botón apagará la alarma por esta flag.

*"ALARM_VALID" es una flag que indica si es correcto que en ese tiempo la alarma suene o no.
- Cuando el usuario se encuentre configurando la alarma, o se encuentre configurando hora, 
-la flag se apagará. En cualquier otro caso, la flag se mantendrá encendida.

*Por otro lado, existirá una localidad de memoria "ALARMA_SEGUNDOS", que, en caso de que haya alarma activa, 
-llevará el conteo de segundos que la alarma lleva encendida. Si ALARMA_SEGUNDOS=120, la alarma se apagará automáticamente.
- El conteo estará dado en TIM1INTERRUPT.

*La alarma, al ser apagada, conservará el tiempo en que se quiera que suene.

*-----------------
* ENCODER: {00000,PB_LAST,CAMBIO,DIRECCION}

*Se utilizará un registro de propósito general nombrado "ENCODER" que guardará si se debe INCREMENTAR o...
DECREMENTAR algún valor  Esta acción de cambio únicamente tendrá efecto si alguna...
bandera SETUP_ o MODE_SELECT en MODO se encuentra encendida. La "DIRECCION" de cambio se guardará constantemente...
en el bit 0 del registro. Si DIRECCION=0, se desea decrementar algún valor; si DIRECCION=1, se desea incrementar dicho valor.

* El bit 1 del registro será nombrado "CAMBIO", y se interpretará como una "flag" indicativa para verificar si SÍ se...
-desea realizar un cambio o no. Esta flag sería encendida en la rutina de interrupción si se activa El pushbotton , y,...
-para evitar un cambio constante, luego la flag sería apagada cuando se interprete el cambio en el LOOP.

*El bit 2 del registro será nombrado "PB_LAST_STATE", y funcionará para evitar cambios ilógicos en la rutina de interrupción.

*-------------------------
INTERFAZ: 


*/
/*****************************************************************************************************************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P

;========================================
;           Variables/registros
;========================================
.equ T1VALUE	= 0XC2F7
.equ MAX_MODES		= 7; se coloca uno extra para que en el momento en el que hace el overflow.
; este nos ayuda a definir la cantidad de estados de la maquina. 

; val timers
.equ			T1VALUE_L			= 0xDC; pa timer 1
.equ			T1VALUE_H			= 0x0B
.equ			T0VALUE				= 6; pa timer 0


; Bits característicos del registro "MODO":
.equ			SETUP_VALUE			= 5
.equ			BLINKSTATE			= 4
.equ			SETUP_				= 3
.equ			MODE_SELECT			= 2
.equ			MODO1				= 1
.equ			MODO0				= 0

; Bits característicos para mi registro "ENCODER":
.equ			PB_LAST				= 2
.equ			CAMBIO				= 1
.equ			DIRECCION			= 0


; Bits característicos del registro "ALARM_REGISTER":
; esto todavia hay que verificarm, realmente solo quiero indicar por ahora. 

.equ			ALARM_SET			= 0
.equ			ALARM_ACTIVE		= 1
.equ			ALARM_VALID			= 2


; Bits característicos de PORTC:
.equ			EN_PB				= 2
.equ			EN0					= 3
.equ			EN1					= 4
.equ			SET_SPDT			= 5 ; cambiar a SET_PB
/*************************************************************************************************************************************/

; Localidades de memoria de mis datos; mejor orden.

; Variables de conteo
.equ			MINUTOS_UNIDADES	= 0x0101
.equ			MINUTOS_DECENAS		= 0x0102
.equ			HORAS_UNIDADES		= 0x0103
.equ			HORAS_DECENAS		= 0x0104
.equ			DIAS_UNIDADES		= 0x0105
.equ			DIAS_DECENAS		= 0x0106
.equ			MESES_UNIDADES		= 0x0107
.equ			MESES_DECENAS		= 0x0108

; NOTA: hay que indicar los de la alarma posteriormente: 

.equ			ALARM_REGISTER		= 0x0111
.equ			A_MINUTOS_UNIDADES	= 0x0112
.equ			A_MINUTOS_DECENAS   = 0x0113
.equ			A_HORAS_UNIDADES	= 0x0114
.equ			A_HORAS_DECENAS		= 0x0115
.equ			ALARMA_SEGUNDOS		= 0x0117

; Variables de cada display
.equ			DISPMODE_VALUE		= 0x0109//Cambiar, puesto qeu se utilizará una diferente logica : ahora con PBs
; Puede cambiarse a LEDMODE_VALUE; pues es mas cercano al funcionamiento final del contador led.

.equ			DISP0_VALUE			= 0x010A
.equ			DISP1_VALUE			= 0x010B
.equ			DISP2_VALUE			= 0x010C
.equ			DISP3_VALUE			= 0x010D
;
; Cambio de modo indicadores:
.equ			DISPMODE_H			= 0x010E; Cambio a LEDMODE_1
.equ			DISPMODE_F			= 0x010F; Cambio a LEDMODE_2
.equ			DISPMODE_A			= 0x0110; Cambio a LEDMODE_2
.equ			DISP_GUION			= 0x0116; Cambio o eliminación según sea necesario para evitar sobreextender el codigo. 

;NOTA 2:; Días de cada mes (Solo primera localidad para apuntar con el XPointer)
.equ			DIAS_DE_MESES		= 0x0200


; =========Memoria y etiquetas para las interrupciones:==========
.cseg
.org 0x0000
	JMP SETUP
	
.org PCI1addr ;Pin Change Interrupt 1 (PORTC)
	RJMP	PINCHANGE_INTERRUPT

.org OVF1addr; rutina del timer 1
	JMP  TIM1_INTERRUPT

.org OVF0addr
	RJMP TIM0_INTERRUPT

; Para facilidades guardamos una tabla para valores de DISP7SEG
.org 0x0040
	DISP7SEG:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
/*********************************************************************************************************************************************/
; Registros de propósito general
.def			msCOUNT0				= R20 
.def			msCOUNT1				= R21
.def			sCOUNT					= R22 
.def			MODO					= R23
.def			MUX_SECUENCIA			= R24
.def			ENCODER					= R25
;***********************************************

// Configuracion MCU
SETUP:
    //disablle interruptions (clears I bit on sreg )
cli 
/************* PRESCALER ************************************************************/
//Configuración main clock prescaler 
LDI R16, (1<<CLKPS2)
STS CLKPR, R16 		;enable prescaler
LDI R16, (1<<CLKPS2)
STS CLKPR, R16 		;setear de 16 a 1MHZ


;--------Deshabilitar comunicación serial-------UART
	LDI		R16, 0x00
	STS		UCSR0B, R16

// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16

; Guardamos algunos valores en RAM

	; Días de cada mes (Se le añade +1 a c/u para hacer la lógica correctamente)
	LDI		XL, LOW(DIAS_DE_MESES)
	LDI		XH, HIGH(DIAS_DE_MESES)
	LDI		R16, 32 ;Enero: 31 días
	ST		X+, R16
	LDI		R16, 29 ;Febrero: 28 días
	ST		X+, R16
	LDI		R16, 32 ;Marzo: 31 días
	ST		X+, R16
	LDI		R16, 31 ;Abril: 30 días
	ST		X+, R16
	LDI		R16, 32 ;Mayo: 31 días
	ST		X+, R16
	LDI		R16, 31 ;Junio: 30 días
	ST		X+, R16
	LDI		R16, 32 ;Julio: 31 días
	ST		X+, R16
	LDI		R16, 32 ;Agosto: 31 días
	ST		X+, R16 
	LDI		R16, 31 ;Septiembre: 30 días
	ST		X+, R16
	LDI		R16, 32 ;Octubre: 31 días
	ST		X+, R16
	LDI		R16, 31 ;Noviembre: 30 días
	ST		X+, R16
	LDI		R16, 32 ;Diciembre: 31 días
	ST		X+, R16


/************************************************************************************************************************************************/
//CONFIGURACIÓN DE SALIDAS 
; --------------Configuración de los Pines para el puerto D-----
	;Configurar I/O PORTS
	LDI		R16, 0xFF			;0b11111111, se activaron todos, incluyendo el puntito.
	OUT		DDRD, R16			; Se les asigna a la dirección

	CLR R16					; limpio mi variable (setear a cero)
	OUT PORTD, R16				; Les mando 0 voltios para empezar. 

; PORTB: Transistores de displays y Buzzer		|		PORTB: {0,0,BUZZER,0,D3,D2,D1,D0}
	LDI		R16, 0x2F
	OUT		DDRB, R16
	LDI		R16, 0b00000000							;		¡MUX_SECUENCIA se encargará de llevar el orden!
	OUT		PORTB, R16

	
;PORTC: Entradas de interfaz de usuario de pc0-pc4		|		PORTC: {0,0,1ed modo2,led modo1,SET_SPDT,EN1,EN0,EN_PB}		(EN: Encoder)
	LDI		R16, 0
	OUT		DDRC, R16
	LDI		R16, 0x0F						;	Todos necesitan pull up, menos las  salidas. 
	OUT		PORTC, R16



/*************************************************************************************************************************/

; Establecer TIM0 en modo Normal:
	; Prescaler TIM0 = 64 
	; TCNT0 = 6
	; Activar Máscara
	; Activar Bandera de INT
	LDI		R16, (0 << CS02) |(1 << CS01) | (1 << CS00)
	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, T0VALUE
	OUT		TCNT0, R16

//CONFIGURACIÓN TIMER1;		
; Establecer TIM1 en modo Normal:
	; Prescaler TIM0 = 256,TCNT1H = 0B, TCNT1L = DC
	; Activar Máscara, luego activar Bandera de INT

	ldi		R16, (1 << CS12) |(0 << CS11) | (0 << CS10)
	STS		TCCR1B, R16
	LDI		R16, (1 << TOIE1) 
	STS		TIMSK1, R16; HABILITAR INTERRÚPCIONES.  (TIMISK1)
	ldi		R16, T1VALUE_H
	sts		TCNT1H, R16
	ldi		R16, T1VALUE_L
	STS		TCNT1L, R16

/****************************************************************************************************************************/
; Habilitamos las interrupciones de PINCHANGE de PORTC:
;Aqui es donde tengo toods mis bottoncitos., bueno la mayoria por ahora, puesto que aún debo verificar.

	LDI		R16, (1 << PCIE1)
    STS		PCICR, R16	
	LDI		R16, (1 << SET_SPDT) | (1 << EN0) | (1 << EN_PB)
	STS		PCMSK1, R16	
	
	


/****************************************************************************************************************************/
; INICIALIZACIÓN DE CONTADORES y valores iniciales:

	; Valores iniciales de variables de conteo
	; Registros de propósito general
	LDI		msCOUNT0, 0
	LDI		msCOUNT1, 0
	LDI		sCOUNT, 0
	LDI		MODO, 0b00000000					
	LDI		MUX_SECUENCIA, 0b00000001			; ¡Un transistor debe empezar encendido!; esta es un a correción a la asignación de voltaje inciial.
	LDI		ENCODER, (1 << PB_LAST)				;PUSHBUTTON empieza no estando apachado
	; R5=0
	LDI		R16, 0
	MOV		R5, R16	


	; Localidades en RAM
	LDI		R16, 0
	STS		MINUTOS_UNIDADES, R16
	STS		MINUTOS_DECENAS, R16
	STS		HORAS_UNIDADES, R16
	STS		HORAS_DECENAS, R16
	LDI		R16, 1
	STS		DIAS_UNIDADES, R16				; ¡Días debe empezar en 01!
	LDI		R16, 0
	STS		DIAS_DECENAS, R16
	LDI		R16, 1
	STS		MESES_UNIDADES, R16				; ¡Meses debe empezar en 01! NO HAY MESES CERO :,D

	
	LDI		R16, 0
	STS		MESES_DECENAS, R16				; aqui sí aplicamos un cero
			
			;Idea para trabajar la concordancia de la alarma, verificación.

	;LDI		R16, (1 << ALARM_VALID) | (0 << ALARM_ACTIVE) | (0 << ALARM_SET)
	;STS		ALARM_REGISTER, R16

	LDI		R16, 0
	STS		A_MINUTOS_UNIDADES, R16
	STS		A_MINUTOS_DECENAS, R16
	STS		A_HORAS_UNIDADES, R16
	STS		A_HORAS_DECENAS, R16
	STS		ALARMA_SEGUNDOS, R16

	; Valor inicial del YPointer
	LDI		YL, LOW(DIAS_DE_MESES)
	LDI		YH, HIGH(DIAS_DE_MESES)

	;*******************************************************************************************************************************************

	SEI
	/****************************************/
// Loop Infinito

LOOP:

	;*******************************************************************************************************************************************
	; PRIMER PASO: Actualizar variables de conteo para parpadeo.

	PRIMER_PASO:
		REVISAR_PARPADEO:
		;CONTEXTO:
			;Se cuenta con dos variables de conteo de milisegundos.
			;Cuando msCOUNT0=250, habrán transcurrido 250 milisegundos; incrementamos msCOUNT1 y reiniciamos msCOUNT0
			;Cuando msCOUNT1=2, habrán transcurrido 500ms; reiniciamos msCOUNT1, "toggleamos" los dos puntos (PD7)...
			;sincronizamos "BLINKSTATE" con el estado de PD7 (Por si un parpadeo en los displays es necesario)...
			;y nos vamos al SEGUNDO PASO
			;Si msCOUNT0!=250, revisamos msCOUNT1
			;Si msCOUNT!=2, nos vamos al SEGUNDO PASO
			;-----------------------------------------------------------------

			CPI		msCOUNT0, 250
			BREQ	REINICIAR_msCOUNT0_E_INCREMENTAR_msCOUNT1
			REVISAR_msCOUNT1:
				CPI		msCOUNT1, 2
				BREQ	REINICIAR_msCOUNT1_TOGGLE_Y_SINCRONIZAR_BLINKSTATE
				RJMP	SEGUNDO_PASO	
			REINICIAR_msCOUNT0_E_INCREMENTAR_msCOUNT1:
				CLR		msCOUNT0
				INC		msCOUNT1
				RJMP	REVISAR_msCOUNT1
			REINICIAR_msCOUNT1_TOGGLE_Y_SINCRONIZAR_BLINKSTATE:
				CLR		msCOUNT1
				;Toggle de dos puntos:
				SBI		PIND, 7


				;Sincronizamos BLINKSTATE con los dos puntos:

				;Si PD7 está encendido, encendemos BLINKSTATE y nos vamos al SEGUNDO PASO 
				;Si PD7 está apagado, apagamos BLINKSTATE y nos vamos al SEGUNDO PASO, en este caso  pasa 
/*
				SBIS	PORTD, 7 ;EN EL Caso que la comprobación, salta en caso sea 1 el resultado. Sino ingora la siguente linea y va a RJMP ENCENDER_BLINKTATE
				RJMP	APAGAR_BLINKSTATE
				RJMP	ENCENDER_BLINKSTATE

				APAGAR_BLINKSTATE:
					;Apagamos el bit T en el SREG y lo copiamos en BLINKSTATE
					; De esta manera, la bandera de mi temporal, permite la verifiación de este posteriormente.
					CLT
					BLD		MODO, BLINKSTATE		;Copies the T bit in the SREG (Status Register) to bit b in register Rd
					RJMP	SEGUNDO_PASO
				ENCENDER_BLINKSTATE:
					;Encendemos el bit T en el SREG y lo copiamos en BLINKSTATE
					set
					BLD		MODO, BLINKSTATE ; De nuevo copia el valor de T en el sreg.
					RJMP	SEGUNDO_PASO, 
*/

; SEGUNDO PASO: Actualizar variables de conteo generales.

	SEGUNDO_PASO:
		REVISAR_sCOUNT_EN_SEGUNDO_PASO:
			;Si sCOUNT=60, habrá transcurrido un minuto; reiniciamos sCOUNT, incrementamos MINUTOS...
			;y vamos a revisar el conteo de minutos
			;Si sCOUNT=60, vamos a revisar el conteo de minutos

			CPI		sCOUNT, 60; Comparamos, si llego a 60
			BREQ	REINICIAR_sCOUNT_E_INCREMENTAR_MINUTOS_EN_SEGUNDO_PASO; si efectivamente así fue se salta a la etiqueta
			RJMP	REVISAR_MINUTOS_EN_SEGUNDO_PASO; sino, regresa hasta que sea verdadero

			REINICIAR_sCOUNT_E_INCREMENTAR_MINUTOS_EN_SEGUNDO_PASO:
				CLR		sCOUNT
				CALL	INCREMENTAR_MINUTOS_RUTINA
				RJMP	REVISAR_MINUTOS_EN_SEGUNDO_PASO

		REVISAR_MINUTOS_EN_SEGUNDO_PASO:
			;Si MINUTOS_DECENAS=6, habrá transcurrido una hora; reiniciamos MINUTOS, incrementamos HORAS...
			;y vamos a revisar el conteo de horas
			;Si MINUTOS_DECENAS!=6, vamos a revisar el conteo de horas
			LDS		R16, MINUTOS_DECENAS
			CPI		R16, 6
			BREQ	REINICIAR_MINUTOS_E_INCREMENTAR_HORAS_EN_SEGUNDO_PASO
			RJMP	REVISAR_HORAS_EN_SEGUNDO_PASO
			REINICIAR_MINUTOS_E_INCREMENTAR_HORAS_EN_SEGUNDO_PASO:
				LDI		R16, 0
				STS		MINUTOS_UNIDADES, R16
				STS		MINUTOS_DECENAS, R16
				CALL	INCREMENTAR_HORAS_RUTINA
				RJMP	REVISAR_HORAS_EN_SEGUNDO_PASO

		REVISAR_HORAS_EN_SEGUNDO_PASO:
			;Si HORAS=24, habrá transcurrido un día; reiniciamos HORAS, incrementamos DIAS...
			;y vamos a revisar el conteo de días
			;Si HORAS!=24, vamos a revisar el conteo de días
			;Para revisar si HORAS=24, sumamos HORAS_UNIDADES y HORAS_DECENAS*10
			LDS		R16, HORAS_UNIDADES
			LDS		R17, HORAS_DECENAS
			;Multiplicamos HORAS_DECENAS por 10 para sumarlo a HORAS_UNIDADES
			LDI		R18, 10								; Factor de multiplicación
			MUL		R17, R18							; El resultado se guarda en R0
			;Ahora sí: sumamos
			ADD		R16, R0
			CPI		R16, 24
			BREQ	REINICIAR_HORAS_E_INCREMENTAR_DIAS_EN_SEGUNDO_PASO
			RJMP	REVISAR_DIAS_EN_SEGUNDO_PASO
			REINICIAR_HORAS_E_INCREMENTAR_DIAS_EN_SEGUNDO_PASO:
				LDI		R16, 0
				STS		HORAS_UNIDADES, R16
				STS		HORAS_DECENAS, R16
				CALL	INCREMENTAR_DIAS_RUTINA
				RJMP	REVISAR_DIAS_EN_SEGUNDO_PASO

		REVISAR_DIAS_EN_SEGUNDO_PASO:
			;Si DIAS=DIAS_DEL_MES, habrá transcurrido el mes; reiniciamos DIAS (Al valor "01"), incrementamos MESES...
			;incrementamos YPointer, y vamos a revisar el conteo de meses
			;Si DIAS!=DIAS_DEL_MES, vamos a revisar el conteo de meses
			;Para revisar si DIAS=DIAS_DEL_MES, sumamos DIAS_UNIDADES y DIAS_DECENAS*10...
			;y lo comparamos con el valor al cual apunta YPointer según el mes en que nos encontremos

			LDS		R16, DIAS_UNIDADES
			LDS		R17, DIAS_DECENAS
			;Multiplicamos DIAS_DECENAS por 10 para sumarlo a DIAS_UNIDADES
			LDI		R18, 10								; Factor de multiplicación
			MUL		R17, R18							; El resultado se guarda en R0
			;Ahora sí: sumamos
			ADD		R16, R0
			LD		R17, Y
			CP		R16, R17
			BREQ	REINICIAR_DIAS_E_INCREMENTAR_MESES_EN_SEGUNDO_PASO
			RJMP	REVISAR_MESES_EN_SEGUNDO_PASO
			REINICIAR_DIAS_E_INCREMENTAR_MESES_EN_SEGUNDO_PASO:
				LDI		R16, 1
				STS		DIAS_UNIDADES, R16
				LDI		R16, 0
				STS		DIAS_DECENAS, R16				; ¡Días debe empezar en 01!
				CALL	INCREMENTAR_MESES_RUTINA
				RJMP	REVISAR_MESES_EN_SEGUNDO_PASO

		REVISAR_MESES_EN_SEGUNDO_PASO:
			;Si MESES=13, habrá transcurrido el año; reiniciamos MESES (Al valor "01")...
			;¡Y vamos al TERCER PASO! ¡YEY!
			;Si MESES!=13, vamos al TERCER PASO
			;Para revisar si MESES=13, sumamos MESES_UNIDADES y MESES_DECENAS*10
			LDS		R16, MESES_UNIDADES
			LDS		R17, MESES_DECENAS
			;Multiplicamos MESES_DECENAS por 10 para sumarlo a MESES_UNIDADES
			LDI		R18, 10								; Factor de multiplicación
			MUL		R17, R18							; El resultado se guarda en R0
			;Ahora sí: sumamos
			ADD		R16, R0
			CPI		R16, 13
			BREQ	REINICIAR_MESES_EN_SEGUNDO_PASO
			RJMP	TERCER_PASO
			REINICIAR_MESES_EN_SEGUNDO_PASO:
				LDI		R16, 1
				STS		MESES_UNIDADES, R16
				LDI		R16, 0
				STS		MESES_DECENAS, R16				; ¡Meses debe empezar en 01!
				RJMP	TERCER_PASO

				; TERCER PASO: Revisar si debe sonar la alarma, o si ya debe de parar de sonar.

	TERCER_PASO:
		REVISAR_SI_HAY_ALARMA:
			;Si ALARM_SET=1, revisamos si hay alarma activa. Si no, vamos a actualizar el estado del BUZZER.
			LDS		R16, ALARM_REGISTER
			SBRS	R16, ALARM_SET
			RJMP	ACTUALIZAR_BUZZER
			RJMP	REVISAR_SI_HAY_ALARMA_ACTIVA
			REVISAR_SI_HAY_ALARMA_ACTIVA:
				;Debemos revisar si ya ya hay una alarma activa, o, si no hay, si es válido que suene en caso de que ya sea hora.
				;Si ALARM_ACTIVE=1, nos vamos a revisar si ya hay que apagarla.
				;Si ALARM_ACTIVE=0, nos vamos a revisar si es válido que una posible alarma venidera suene.
				LDS		R16, ALARM_REGISTER
				SBRS	R16, ALARM_ACTIVE
				RJMP	REVISAR_SI_LA_ALARMA_ES_VALIDA
				RJMP	REVISAR_ALARMA_SEGUNDOS
				REVISAR_SI_LA_ALARMA_ES_VALIDA:
					;Si ALARM_VALID=1, revisamos si ya es tiempo de que la alarma suene. Si no, vamos a actualizar el estado del BUZZER.
					LDS		R16, ALARM_REGISTER
					SBRS	R16, ALARM_VALID
					RJMP	ACTUALIZAR_BUZZER
					RJMP	REVISAR_SI_LA_ALARMA_DEBE_SONAR
					REVISAR_SI_LA_ALARMA_DEBE_SONAR:
						;Si el tiempo configurado es el mismo que el tiempo actual, encendemos ALARM_ACTIVE. Si no...
						;vamos a actualizar el estado del BUZZER.
						REVISAR_MINUTOS_UNIDADES_EN_TERCER_PASO:
							LDS		R16, A_MINUTOS_UNIDADES
							LDS		R17, MINUTOS_UNIDADES
							CP		R16, R17
							BREQ	REVISAR_MINUTOS_DECENAS_EN_TERCER_PASO
							RJMP	ACTUALIZAR_BUZZER
							REVISAR_MINUTOS_DECENAS_EN_TERCER_PASO:
								LDS		R16, A_MINUTOS_DECENAS
								LDS		R17, MINUTOS_DECENAS
								CP		R16, R17
								BREQ	REVISAR_HORAS_UNIDADES_EN_TERCER_PASO
								RJMP	ACTUALIZAR_BUZZER
								REVISAR_HORAS_UNIDADES_EN_TERCER_PASO:
									LDS		R16, A_HORAS_UNIDADES
									LDS		R17, HORAS_UNIDADES
									CP		R16, R17
									BREQ	REVISAR_HORAS_DECENAS_EN_TERCER_PASO
									RJMP	ACTUALIZAR_BUZZER
									REVISAR_HORAS_DECENAS_EN_TERCER_PASO:
										LDS		R16, A_HORAS_DECENAS
										LDS		R17, HORAS_DECENAS
										CP		R16, R17
										BREQ	REVISAR_sCOUNT_PARA_ACTIVAR_ALARMA_EN_TERCER_PASO
										RJMP	ACTUALIZAR_BUZZER
										REVISAR_sCOUNT_PARA_ACTIVAR_ALARMA_EN_TERCER_PASO:
											;La alarma solo podrá ser activada si sCOUNT=0. Esto para evitar problemas si se apaga la alarma...
											;mientras suena
											CPI		sCOUNT, 0
											BREQ	ACTIVAR_ALARMA
											RJMP	ACTUALIZAR_BUZZER
											ACTIVAR_ALARMA:
												;Activamos la alarma, lo cual va a ser interpretado en ACTUALIZAR_BUZZER. A su vez,...
												;apagamos MODE_SELECT en caso de que estuviese encendido para permitir apagar la alarma.
												LDS		R16, ALARM_REGISTER
												SET
												BLD		R16, ALARM_ACTIVE
												STS		ALARM_REGISTER, R16
												CLT
												BLD		MODO, MODE_SELECT
												RJMP	ACTUALIZAR_BUZZER						
				REVISAR_ALARMA_SEGUNDOS:
					;Si hay alarma activa, verificamos si ALARMA_SEGUNDOS=120. Si sí, apagamos la alarma.
					;Si no, vamos a actualizar el estado del Buzzer.
					LDS		R16, ALARMA_SEGUNDOS
					CPI		R16, 120
					BREQ	APAGAR_ALARMA
					RJMP	ACTUALIZAR_BUZZER
						APAGAR_ALARMA:
							LDI		R16, (1 << ALARM_VALID) | (0 << ALARM_ACTIVE) | (1 << ALARM_SET)
							STS		ALARM_REGISTER, R16
							LDI		R16, 0
							STS		ALARMA_SEGUNDOS, R16
							RJMP	ACTUALIZAR_BUZZER
		ACTUALIZAR_BUZZER:
			;Si ALARM_VALID=1, ALARM_SET=1 Y ALARM_ACTIVE=1, encendemos PB5 (Buzzer) y vamos al CUARTO PASO
			;Si no, apagamos PB5 (Buzzer) y vamos al CUARTO PASO
			;Usamos una máscara
			LDS		R16,  ALARM_REGISTER
			LDI		R17, (1 << ALARM_VALID)| (1 << ALARM_ACTIVE) | (1 << ALARM_SET)
			AND		R17, R16
			CPI		R17, (1 << ALARM_VALID)| (1 << ALARM_ACTIVE) | (1 << ALARM_SET)
			BREQ	ENCENDER_BUZZER
			RJMP	APAGAR_BUZZER
			ENCENDER_BUZZER:
			;Tentativamente esta en portB 5
				SBI		PORTB, 5
				RJMP	CUARTO_PASO
			APAGAR_BUZZER:
				CBI		PORTB, 5
				RJMP	CUARTO_PASO



;CUARTO PASO: Revisar si se quiere configurar algún valor de los modos.

	CUARTO_PASO:
		REVISAR_CONFIGURACION:
			;Primero revisamos si SÍ se quiere configurar algo. Para ello, verificamos las "flags" SETUP_ y MODE_SELECT...
			;en el registro MODO.
			;Si sí hay algo qué configurar, revisamos el registro ENCODER para verificar si hay que INCREMENTAR...
			;o DECREMENTAR. Si no se debe configurar algo, NO REVISAMOS el registro mencionado.
			;Si no se quiere configurar nada, saltamos al QUINTO PASO.
			;Creamos una PRIMERA máscara para MODO (Aquí nos importa SETUP_VALUE y SETUP_):
			
			LDI		R16, (1 << SETUP_VALUE) | (1 << SETUP_) | (1 << MODO1) | (1 << MODO0)
			AND		R16, MODO

			REVISAR_CONFIGURACION_CERO:

			;Si SETUP_=1, SETUP_VALUE=0 y MODO1,0=00, se desea CONFIGURAR MINUTOS DE TIME_DISPLAY (DISPS0,1).
			CPI		R16, (0 << SETUP_VALUE) | (1 << SETUP_) | (0 << MODO1) | (0 << MODO0)
			BRNE	REVISAR_CONFIGURACION_UNO	
			CALL	CONFIGURAR_MINUTOS_DE_TIME_DISPLAY
			REVISAR_CONFIGURACION_UNO:
			;Si SETUP_=1, SETUP_VALUE=1 y MODO1,0=00, se desea CONFIGURAR HORAS DE TIME_DISPLAY (DISPS2,3).
			CPI		R16, (1 << SETUP_VALUE) | (1 << SETUP_) | (0 << MODO1) | (0 << MODO0)
			BRNE	REVISAR_CONFIGURACION_DOS
			CALL	CONFIGURAR_HORAS_DE_TIME_DISPLAY
			REVISAR_CONFIGURACION_DOS:
			;Si SETUP_=1, SETUP_VALUE=0 y MODO1,0=01, se desea CONFIGURAR MES DE DATE_DISPLAY (DISPS0,1).
			CPI		R16, (0 << SETUP_VALUE) | (1 << SETUP_) | (0 << MODO1) | (1 << MODO0)
			BRNE	REVISAR_CONFIGURACION_TRES
			CALL	CONFIGURAR_MES_DE_DATE_DISPLAY
			REVISAR_CONFIGURACION_TRES:
			;Si SETUP_=1, SETUP_VALUE=1 y MODO1,0=01, se desea CONFIGURAR DIAS DE DATE_DISPLAY (DISPS2,3).
			CPI		R16, (1 << SETUP_VALUE) | (1 << SETUP_) | (0 << MODO1) | (1 << MODO0)
			BRNE	REVISAR_CONFIGURACION_CUATRO
			CALL	CONFIGURAR_DIAS_DE_DATE_DISPLAY
			REVISAR_CONFIGURACION_CUATRO:
			;Si SETUP_=1, SETUP_VALUE=0 y MODO1,0=10, se desea CONFIGURAR MINUTOS DEL MODO ALARMA (DISPS0,1).
			CPI		R16, (0 << SETUP_VALUE) | (1 << SETUP_) | (1 << MODO1) | (0 << MODO0)
			BRNE	REVISAR_CONFIGURACION_CINCO
			CALL	CONFIGURAR_MINUTOS_DE_ALARM_DISPLAY
			REVISAR_CONFIGURACION_CINCO:
			;Si SETUP_=1, SETUP_VALUE=1 y MODO1,0=10, se desea CONFIGURAR HORAS DEL MODO ALARMA (DISPS2,3).
			CPI		R16, (1 << SETUP_VALUE) | (1 << SETUP_) | (1 << MODO1) | (0 << MODO0)
			BRNE	REVISAR_CONFIGURACION_SEIS
			CALL	CONFIGURAR_HORAS_DE_ALARM_DISPLAY
			REVISAR_CONFIGURACION_SEIS:
			;Creamos una SEGUNDA máscara para MODO (Aquí nos importa MODE_SELECT):
			LDI		R16, (1 << MODE_SELECT)
			AND		R16, MODO
			;Si MODE_SELECT=1 se debe CAMBIAR MODO. Se configura el valor de DISPMODE.
			CPI		R16, (1 << MODE_SELECT)
			BRNE	SALIR_DE_CONFIGURACION
			CALL	CONFIGURAR_MODO_EN_CUALQUIER_DISPLAY
			SALIR_DE_CONFIGURACION:
			;Si no se quiere configurar nada, saltamos al QUINTO PASO (Pero revisamos si podemos validar la alarma)
			LDI		R16, (1 << MODE_SELECT) | (1 << SETUP_)
			AND		R16, MODO
			CPI		R16, (0 << MODE_SELECT) | (0 << SETUP_)
			BREQ	HABILITAR_VALIDEZ_DE_ALARMA
			RJMP	QUINTO_PASO
				HABILITAR_VALIDEZ_DE_ALARMA:
					;Encendemos ALARM_VALID en ALARM_REGISTER
					LDS		R16, ALARM_REGISTER
					SET		
					BLD		R16, ALARM_VALID
					STS		ALARM_REGISTER, R16
					RJMP	QUINTO_PASO

CONFIGURAR_MINUTOS_DE_TIME_DISPLAY:
			;Apagamos ALARM_VALID en ALARM_REGISTER
			LDS		R16, ALARM_REGISTER
			CLT		
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			;Si CAMBIO=0, salimos de la rutina sin protocolo.
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar MINUTOS
			;Si DIRECCION=1, incrementamos MINUTOS
			;Si no, decrementamos MINUTOS
			SBRS ENCODER, DIRECCION
			RJMP DECREMENTAR_MINUTOS_EN_TIME_DISPLAY
			RJMP INCREMENTAR_MINUTOS_EN TIME_DISPLAY
			INCREMENTAR_MINUTOS_EN_TIME_DISPLAY:
			
			;LLamo al incremento
			Call	INCREMENTAR_MINUTOS_RUTINA;			Se llama a mi etiqueta, para que vaya icrementando. 

				;Revisamos si MINUTOS_DECENAS=6. Si sí, reiniciamos MINUTOS a 0. Si no, salimos de la rutina con protocolo.

				LDS		R16, MINUTOS_DECENAS
				CPI		R16, 6
				BREQ	REINICIAR_MINUTOS_EN_TIME_DISPLAY;COMPARACIÓN = 0, ENTONECES SIGUIENTE LINEA,
				RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUTOS_EN_TIME_DISPLAY
				
				REINICIAR_MINUTOS_EN_TIME_DISPLAY:
				ldi  r16, 0
				sts	 MINUTOS_UNIDAES, R16
				sts  MINUTOS_DECENAS, R16
				rjmp SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUTOS_EN TIME_DISPLAY

			
			DECREMENTAR_MINUTOS_EN_TIME_DISPLAY:

				LDS		R16, MINUTOS_UNIDADES;¡Teniendo cuidado de establecer MINUTOS_UNIDADES=9 y decrementar MINUTOS_DECENAS de ser necesario!
			
				DEC		R16
				CPI		R16, 0XFF
				BREQ	ESTABLECER_MINUTOS_UNIDADES_Y_DECREMENTAR_MINUTOS_DECENAS_EN_TIME_DISPLAY

			
				;Si MINUTOS_UNIDADES!=0xFF, solo lo guardamos...
				 STS	MINUTOS_UNIDADES, R16
				 RJMP SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUTOS_EN_TIME_DISPLAY
				 ESTABLECER_MINUTOS_UNIDADES_Y_DECREMENTAR_MINUTOS_DECENAS_EN TIME_DISPLAY:
					LDI		R16, 9
					STS		MINUTOS_UNIDADES, R16
					LDS		R16, MINUTOS_DECENAS
					DEC		R16
					;SI MINUTOS_DECENAS= 0XFF,, ESTABLECEMOS  MINUTOS= 59, ESE ES EL LIMITE PA CONFIGURAR

					CPI		R16, 0xFF
					BREQ	ESTABLECER_MINUTOS_EN_TIME_DISPLAY
					; SI MINUOTS DECENAS NO ES IGUAL, entonces solo guardamos

					STS		MINUTOS_DECENAS, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUITOS_EN TIME_DISPLAY

					;Si MINUTOS_DECENAS!=0xFF, solo lo guardamos...
					;STS		MINUTOS_DECENAS, R16
					;RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUTOS_EN_TIME_DISPLAY

						ESTABLECER_MINUTOS_EN_TIME_DISPLAY:
							LDI		R16, 5 
							STS		MINUTOS_DECENAS, R16 
							LDI		R16, 9
							STS		MINUTOS_UNIDADES, R16
							RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUTOS_EN_TIME_DISPLAY

						

			SALIR_DE_INCREMENTAR_O_DECREMENTAR_MINUOTS_EN_TIME_DISPLAY:
			;SE REINCIIA TIM1  (para dener fidelidad con lo deseado por Pedro en su explicación)
			; PARA APAGAR, EL CAMBIO DE (EN CASO YA HA SIDO apagado y ejecutado)
				ldi		R16, T1VALUE_H; parte high
				STS		TCNT1H, R16
				LDI		R16, T1VALUE_L ; parte low
				STS		TCNT1L, R16
				LDI		sCOUNT, 0 ; se le carga cero
				CLT
				bld		ENCODER, CAMBIO;Copies the T bit in the SREG (Status Register) to bit b in register Rd.
				RET

				;==============================================================
		CONFIGURAR_HORAS_DE_TIME_DISPLAY:
		; se apagar el valor de verificación de la alargma, en alarm_Valid y se cambia en el registro de este, (ALARM_REGISTER)
			LDS		R16, ALARM_REGISTER ;Load Direct from Data Space
			CLT
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			; SI CAMBIO =0, Salimos de la rutina, sin protocolo.

				;==================================================================
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar HORAS
			;Si DIRECCION=1, incrementamos HORAS
			;Si no, decrementamos HORAS
			SBRS	ENCODER, DIRECCION
			RJMP	DECREMENTAR_HORAS_EN_TIME_DISPLAY
			RJMP	INCREMENTAR_HORAS_EN_TIME_DISPLAY
			INCREMENTAR_HORAS_EN_TIME_DISPLAY:
				;Llamamos a la rutina INCREMENTAR_HORAS
				CALL	INCREMENTAR_HORAS_RUTINA
				;Revisamos si HORAS=24. Si sí, reiniciamos HORAS a 0. Si no, salimos de la rutina con protocolo.
				LDS		R16, HORAS_UNIDADES
				LDS		R17, HORAS_DECENAS
				LDI		R18, 10
				MUL		R17, R18
				ADD		R16, R0
				CPI		R16, 24
				BREQ	REINICIAR_HORAS_EN_TIME_DISPLAY
				RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_HORAS_EN_TIME_DISPLAY
				REINICIAR_HORAS_EN_TIME_DISPLAY:
					LDI		R16, 0
					STS		HORAS_UNIDADES, R16
					STS		HORAS_DECENAS, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_HORAS_EN_TIME_DISPLAY
			DECREMENTAR_HORAS_EN_TIME_DISPLAY:
				;¡Teniendo cuidado de establecer HORAS_UNIDADES=9 y decrementar HORAS_DECENAS de ser necesario!
				LDS		R16, HORAS_UNIDADES
				DEC		R16
				CPI		R16, 0xFF
				BREQ	ESTABLECER_HORAS_UNIDADES_Y_DECREMENTAR_HORAS_DECENAS_EN_TIME_DISPLAY
				;Si HORAS_UNIDADES!=0xFF, solo lo guardamos y salimos con protocolo
				STS		HORAS_UNIDADES, R16
				RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_HORAS_EN_TIME_DISPLAY
				ESTABLECER_HORAS_UNIDADES_Y_DECREMENTAR_HORAS_DECENAS_EN_TIME_DISPLAY:
					LDI		R16, 9
					STS		HORAS_UNIDADES, R16
					LDS		R16, HORAS_DECENAS
					DEC		R16
					;Revisamos si HORAS_DECENAS=0xFF. Si sí, establecemos HORAS a 23. Si no, salimos de la rutina...
					;con protocolo.
					CPI		R16, 0xFF
					BREQ	ESTABLECER_HORAS_EN_TIME_DISPLAY
					;Si HORAS_DECENAS!=0xFF, solo lo guardamos y salimos con protocolo
					STS		HORAS_DECENAS, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_HORAS_EN_TIME_DISPLAY
						ESTABLECER_HORAS_EN_TIME_DISPLAY:
							LDI		R16, 2
							STS		HORAS_DECENAS, R16
							LDI		R16, 3
							STS		HORAS_UNIDADES, R16
							RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_HORAS_EN_TIME_DISPLAY
			SALIR_DE_INCREMENTAR_O_DECREMENTAR_HORAS_EN_TIME_DISPLAY:
				;APAGAMOS CAMBIO (El cambio ya fue interpretado y ejecutado)
				CLT
				BLD		ENCODER, CAMBIO
				RET

		CONFIGURAR_MES_DE_DATE_DISPLAY:
			;Encendemos ALARM_VALID en ALARM_REGISTER
			LDS		R16, ALARM_REGISTER
			SET		
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			;Antes de salir de la rutina, ¡Hay que verificar que DIAS_DEL_MES no sea menor que los DIAS guardados antes!
			;Si CAMBIO=0, salimos de la rutina sin protocolo.
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar MES
			;Si DIRECCION=1, incrementamos MES
			;Si no, decrementamos MES
			SBRS	ENCODER, DIRECCION
			RJMP	DECREMENTAR_MESES_EN_DATE_DISPLAY
			RJMP	INCREMENTAR_MESES_EN_DATE_DISPLAY
			INCREMENTAR_MESES_EN_DATE_DISPLAY:
				;Llamamos a la rutina INCREMENTAR_MESES
				CALL	INCREMENTAR_MESES_RUTINA
				;Revisamos si MESES=13. Si sí, reiniciamos MESES a 01. Si no, salimos de la rutina con protocolo.
				LDS		R16, MESES_UNIDADES
				LDS		R17, MESES_DECENAS
				LDI		R18, 10
				MUL		R17, R18
				ADD		R16, R0
				CPI		R16, 13
				BREQ	REINICIAR_MESES_EN_DATE_DISPLAY
				RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MESES_EN_DATE_DISPLAY
				REINICIAR_MESES_EN_DATE_DISPLAY:
					LDI		R16, 1
					STS		MESES_UNIDADES, R16
					LDI		R16, 0
					STS		MESES_DECENAS, R16
					;Reiniciamos YPointer
					LDI		YL, LOW(DIAS_DE_MESES)
					LDI		YH, HIGH(DIAS_DE_MESES)
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MESES_EN_DATE_DISPLAY
			DECREMENTAR_MESES_EN_DATE_DISPLAY:
				;¡Teniendo cuidado de establecer MESES_UNIDADES=9 y decrementar MESES_DECENAS de ser necesario!
				;Decrementamos YPointer
				;Primero revisamos si MESES_UNIDADES=1 y si MESES_DECENAS=0. Si sí, colocamos MESES=12. Si no...
				;seguimos con la rutina normal
				LDS		R16, MESES_UNIDADES
				CPI		R16, 1
				BREQ	REVISAR_MESES_DECENAS_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY
				;Si no, seguimos con la rutina normal
				RJMP	RUTINA_NORMAL_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY
				RUTINA_NORMAL_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY:
				SBIW	Y, 1
				LDS		R16, MESES_UNIDADES
				DEC		R16
				;Revisamos si MESES_UNIDADES=0xFF. Si sí, establecemos MESES_UNIDADES=9 y decrementamos...
				;MESES_DECENAS
				CPI		R16, 0xFF
				BREQ	ESTABLECER_MESES_UNIDADES_Y_DECREMENTAR_MESES_DECENAS_EN_DATE_DISPLAY
				;Si MESES_UNIDADES!=0xFF, solo lo guardamos y salimos de la rutina con protocolo
				STS		MESES_UNIDADES, R16
				RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MESES_EN_DATE_DISPLAY
				REVISAR_MESES_DECENAS_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY:
					;Si MESES_DECENAS=0, establecemos MESES=12 y re-colocamos YPointer
					;Si MESES_DECENAS!=0, seguimos con la rutina normal
					LDS		R16, MESES_DECENAS
					CPI		R16, 0
					BREQ	ESTABLECER_MESES_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY
					RJMP	RUTINA_NORMAL_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY
						ESTABLECER_MESES_EN_DECREMENTAR_MESES_EN_DATE_DISPLAY:
							LDI		R16, 1
							STS		MESES_DECENAS, R16
							LDI		R16, 2
							STS		MESES_UNIDADES, R16
							;Re-colocamos YPointer
							LDI		YL, LOW(DIAS_DE_MESES)
							LDI		YH, HIGH(DIAS_DE_MESES)
							ADIW	Y, 11
							RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MESES_EN_DATE_DISPLAY
				ESTABLECER_MESES_UNIDADES_Y_DECREMENTAR_MESES_DECENAS_EN_DATE_DISPLAY:
					LDI		R16, 9
					STS		MESES_UNIDADES, R16
					LDS		R16, MESES_DECENAS
					DEC		R16
					STS		MESES_DECENAS, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MESES_EN_DATE_DISPLAY
			SALIR_DE_INCREMENTAR_O_DECREMENTAR_MESES_EN_DATE_DISPLAY:
				;APAGAMOS CAMBIO (El cambio ya fue interpretado y ejecutado)
				CLT
				BLD		ENCODER, CAMBIO
				;Revisamos si DIAS es mayor que DIAS_DEL_MES. Si sí, Guardamos en DIAS el valor del YPointer. Si no...
				;nos salimos de la rutina
				;Para comparar, hacemos una resta. Si DIAS_DEL_MES - DIAS < 0, se enciende la flag de carry.
				LDS		R16, DIAS_UNIDADES
				LDS		R17, DIAS_DECENAS
				LDI		R18, 10
				MUL		R17, R18
				ADD		R16, R0
				LD		R18, Y
				SUB		R18, R16
				BRCS	CORREGIR_DIAS_EN_DATE_DISPLAY
				RET
				CORREGIR_DIAS_EN_DATE_DISPLAY:
					;Debemos separar las decenas y las unidades del valor del YPointer.
					;Hacemos un loop de restas -10. Cuando haya carry, el número resulta siendo menor que 10, y dejamos
					;de restar.
					;Guardaremos decenas en R17, y unidades en R16.
					LD		R16, Y
					;Decrementamos, porque DIAS_DEL_MES tiene un día más por lógica del código... jeje.
					DEC		R16
					CLR		R17
					LOOP_DE_RESTA_EN_CORREGIR_DIAS_EN_DATE_DISPLAY:
						SUBI		R16, 10
						BRCS		GUARDAR_DIAS_EN_CORREGIR_DIAS_EN_DATE_DISPLAY
						INC			R17
						RJMP		LOOP_DE_RESTA_EN_CORREGIR_DIAS_EN_DATE_DISPLAY
					GUARDAR_DIAS_EN_CORREGIR_DIAS_EN_DATE_DISPLAY:
						;Restauramos las unidades luego del loop de restas
						LDI		R18, 10
						ADD		R16, R18
						;Guardamos en DIAS_UNIDADES y DIAS_DECENAS respectivamente
						STS		DIAS_UNIDADES, R16
						STS		DIAS_DECENAS, R17
						;Y nos salimos de la rutina
						RET

		CONFIGURAR_DIAS_DE_DATE_DISPLAY:
			;Encendemos ALARM_VALID en ALARM_REGISTER
			LDS		R16, ALARM_REGISTER
			SET	
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			;Si CAMBIO=0, salimos de la rutina sin protocolo.
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar DIAS
			;Si DIRECCION=1, incrementamos DIAS
			;Si no, decrementamos DIAS
			SBRS	ENCODER, DIRECCION
			RJMP	DECREMENTAR_DIAS_EN_DATE_DISPLAY
			RJMP	INCREMENTAR_DIAS_EN_DATE_DISPLAY
			INCREMENTAR_DIAS_EN_DATE_DISPLAY:
				;Llamamos a la rutina INCREMENTAR_DIAS
				CALL	INCREMENTAR_DIAS_RUTINA
				;Revisamos si DIAS=DIAS_DEL_MES. Si sí, reiniciamos DIAS a 01. Si no, vamos al CUARTO PASO.
				LDS		R16, DIAS_UNIDADES
				LDS		R17, DIAS_DECENAS
				LDI		R18, 10
				MUL		R17, R18
				ADD		R16, R0
				LD		R17, Y
				CP		R16, R17
				BREQ	REINICIAR_DIAS_EN_DATE_DISPLAY
				RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_DIAS_EN_DATE_DISPLAY
				REINICIAR_DIAS_EN_DATE_DISPLAY:
					LDI		R16, 1
					STS		DIAS_UNIDADES, R16
					LDI		R16, 0
					STS		DIAS_DECENAS, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_DIAS_EN_DATE_DISPLAY
			DECREMENTAR_DIAS_EN_DATE_DISPLAY:
				;¡Teniendo cuidado de establecer DIAS_UNIDADES=9 y decrementar DIAS_DECENAS de ser necesario!
				;Primero revisamos si DIAS=01. Si sí, establecemos DIAS=DIAS_DEL_MES.
				;Si no, seguimos la rutina normal
				LDS		R16, DIAS_UNIDADES
				CPI		R16, 1
				BREQ	REVISAR_DIAS_DECENAS_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY
				RJMP	RUTINA_NORMAL_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY
				RUTINA_NORMAL_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY:
					LDS		R16, DIAS_UNIDADES
					DEC		R16
					;Si DIAS_UNIDADES=0xFF, establecemos DIAS_UNIDADES=9 y decrementamos MESES_DECENAS
					CPI		R16, 0xFF
					BREQ	ESTABLECER_DIAS_UNIDADES_Y_DECREMENTAR_DIAS_DECENAS_EN_DATE_DISPLAY
					;Si DIAS_UNIDADES!=0xFF Y DIAS!=0, solo lo guardamos y salimos con protocolo
					STS		DIAS_UNIDADES, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_DIAS_EN_DATE_DISPLAY
				ESTABLECER_DIAS_UNIDADES_Y_DECREMENTAR_DIAS_DECENAS_EN_DATE_DISPLAY:
					LDI		R16, 9
					STS		DIAS_UNIDADES, R16
					LDS		R16, DIAS_DECENAS
					DEC		R16
					STS		DIAS_DECENAS, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_DIAS_EN_DATE_DISPLAY
				REVISAR_DIAS_DECENAS_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY:
					;Si DIAS_DECENAS=0, establecemos DIAS=DIAS_DEL_MES
					;Si DIAS_DECENAS!=0, seguimos la rutina normal
					LDS		R16, DIAS_DECENAS
					CPI		R16, 0
					BREQ	ESTABLECER_DIAS_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY
					RJMP	RUTINA_NORMAL_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY
					ESTABLECER_DIAS_EN_DECREMENTAR_DIAS_EN_DATE_DISPLAY:
						;Debemos separar las decenas y las unidades del valor del YPointer.
						;Hacemos un loop de restas -10. Cuando haya carry, el número resulta siendo menor que 10, y dejamos
						;de restar.
						;Guardaremos decenas en R17, y unidades en R16.
						LD		R16, Y
						;Decrementamos, porque DIAS_DEL_MES tiene un día más por lógica del código... jeje.
						DEC		R16
						CLR		R17
						LOOP_DE_RESTA_EN_ESTABLECER_DIAS_EN_DATE_DISPLAY:
							SUBI		R16, 10
							BRCS		GUARDAR_DIAS_EN_ESTABLECER_DIAS_EN_DATE_DISPLAY
							INC			R17
							RJMP		LOOP_DE_RESTA_EN_ESTABLECER_DIAS_EN_DATE_DISPLAY
						GUARDAR_DIAS_EN_ESTABLECER_DIAS_EN_DATE_DISPLAY:
							;Restauramos las unidades luego del loop de restas
							LDI		R18, 10
							ADD		R16, R18
							;Guardamos en DIAS_UNIDADES y DIAS_DECENAS respectivamente
							STS		DIAS_UNIDADES, R16
							STS		DIAS_DECENAS, R17
							RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_DIAS_EN_DATE_DISPLAY
			SALIR_DE_INCREMENTAR_O_DECREMENTAR_DIAS_EN_DATE_DISPLAY:
				;APAGAMOS CAMBIO (El cambio ya fue interpretado y ejecutado)
				CLT
				BLD		ENCODER, CAMBIO
				RET

		CONFIGURAR_MINUTOS_DE_ALARM_DISPLAY:
			;Apagamos ALARM_VALID en ALARM_REGISTER
			LDS		R16, ALARM_REGISTER
			CLT		
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			;Si CAMBIO=0, salimos de la rutina sin protocolo.
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar A_MINUTOS
			;Si DIRECCION=1, incrementamos A_MINUTOS
			;Si no, decrementamos A_MINUTOS
			SBRS	ENCODER, DIRECCION
			RJMP	DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
			RJMP	INCREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
			INCREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY:
				;Habilitamos o deshabilitamos ALARM_REGISTER en caso de ser necesario.
				;Verificamos si ALARM_REGISTER está habilitada primero. Si no, la habilitamos y ajustamos A_MINUTOS...
				;y A_HORAS
				LDS		R16, ALARM_REGISTER
				SBRS	R16, ALARM_SET
				RJMP	ENCENDER_ALARM_SET_Y_CERO_EN_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_MINUTOS_EN_ALARM_DISPLAY
				RJMP	SUMAR_UNO_EN_A_MINUTOS_EN_ALARM_DISPLAY
				ENCENDER_ALARM_SET_Y_CERO_EN_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_MINUTOS_EN_ALARM_DISPLAY:
					;Encendemos ALARM_SET
					LDS		R16, ALARM_REGISTER
					SET
					BLD		R16, ALARM_SET
					STS		ALARM_REGISTER, R16
					;Guardamos "00" en "A_MINUTOS" y "A_HORAS"
					LDI		R16, 0
					STS		A_MINUTOS_UNIDADES, R16
					STS		A_MINUTOS_DECENAS, R16
					STS		A_HORAS_UNIDADES, R16
					STS		A_HORAS_DECENAS, R16
					;Salimos con protocolo
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
				SUMAR_UNO_EN_A_MINUTOS_EN_ALARM_DISPLAY:
					;¡Teniendo cuidado de reiniciar MINUTOS_UNIDADES e incrementar MINUTOS_DECENAS de ser necesario!
					LDS		R16, A_MINUTOS_UNIDADES
					INC		R16
					CPI		R16, 10
					BREQ	REINICIAR_A_MINUTOS_UNIDADES_E_INCREMENTAR_MINUTOS_DECENAS_EN_ALARM_DISPLAY
					;Si A_MINUTOS_UNIDADES!=10, solo lo guardamos y salimos con protocolo
					STS		A_MINUTOS_UNIDADES, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
					REINICIAR_A_MINUTOS_UNIDADES_E_INCREMENTAR_MINUTOS_DECENAS_EN_ALARM_DISPLAY:
						LDI		R16, 0
						STS		A_MINUTOS_UNIDADES, R16
						LDS		R16, A_MINUTOS_DECENAS
						INC		R16
						;Revisamos si A_MINUTOS_DECENAS=6. Si sí, y A_HORAS!=0 reiniciamos MINUTOS a 0 y salimos...
						;de la rutina con protocolo. Si A_HORAS=0, apagamos ALARM_SET y salimos de la rutina con...
						;protocolo. A_MINUTOS_DECENAS!=6, salimos de la rutina con protocolo.
						CPI		R16, 6
						BREQ	REVISAR_A_HORAS_EN_INCREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
						STS		A_MINUTOS_DECENAS, R16
						RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
						REVISAR_A_HORAS_EN_INCREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY:
							;Revisamos si A_HORAS=0.
							LDS		R16, A_HORAS_UNIDADES
							LDS		R17, A_HORAS_DECENAS
							;Si A_HORAS_UNIDADES=A_HORAS_DECENAS=0, apagamos SET_ALARM y guardamos 0 en A_MINUTOS y...
							;A_HORAS. Si A_HORAS!=0, reiniciamos minutos
							ADD		R16, R17
							BREQ	APAGAR_ALARM_SET_Y_GUARDAR_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_A_MINUTOS_EN_ALARM_DISPLAY
							RJMP	REINICIAR_MINUTOS_EN_ALARM_DISPLAY
							APAGAR_ALARM_SET_Y_GUARDAR_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_A_MINUTOS_EN_ALARM_DISPLAY:
								;Apagamos ALARM_SET
								LDS		R16, ALARM_REGISTER
								CLT
								BLD		R16, ALARM_SET
								STS		ALARM_REGISTER, R16
								;Guardamos 0 en A_MINUTOS y A_HORAS
								LDI		R16, 0
								STS		A_MINUTOS_UNIDADES, R16
								STS		A_MINUTOS_DECENAS, R16
								STS		A_HORAS_UNIDADES, R16
								STS		A_HORAS_DECENAS, R16
								RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
							REINICIAR_MINUTOS_EN_ALARM_DISPLAY:
								;Guardamos 0 en A_MINUTOS y A_HORAS
								LDI		R16, 0
								STS		A_MINUTOS_UNIDADES, R16
								STS		A_MINUTOS_DECENAS, R16
								RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
			DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY:
				;Habilitamos o deshabilitamos ALARM_REGISTER en caso de ser necesario.
				;Verificamos si ALARM_REGISTER está habilitada primero. Si no, la habilitamos y ajustamos A_MINUTOS...
				;y A_HORAS
				LDS		R16, ALARM_REGISTER
				SBRS	R16, ALARM_SET
				RJMP	ENCENDER_ALARM_SET_AJUSTAR_A_MINUTOS_Y_CERO_EN_A_HORAS_EN_ALARM_DISPLAY
				RJMP	RESTAR_UNO_EN_A_MINUTOS_EN_ALARM_DISPLAY
				ENCENDER_ALARM_SET_AJUSTAR_A_MINUTOS_Y_CERO_EN_A_HORAS_EN_ALARM_DISPLAY:
					;Encendemos ALARM_SET
					LDS		R16, ALARM_REGISTER
					SET
					BLD		R16, ALARM_SET
					STS		ALARM_REGISTER, R16
					;Ajustamos A_HORAS y A_MINUTOS
					LDI		R16, 0
					STS		A_HORAS_UNIDADES, R16
					STS		A_HORAS_DECENAS, R16
					LDI		R16, 5
					STS		A_MINUTOS_DECENAS, R16
					LDI		R16, 9
					STS		A_MINUTOS_UNIDADES, R16
					;Y salimos con protocolo
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
				RESTAR_UNO_EN_A_MINUTOS_EN_ALARM_DISPLAY:
					;¡Teniendo cuidado de establecer MINUTOS_UNIDADES=9 y decrementar MINUTOS_DECENAS de ser necesario!
					LDS		R16, A_MINUTOS_UNIDADES
					DEC		R16
					CPI		R16, 0xFF
					BREQ	ESTABLECER_A_MINUTOS_UNIDADES_Y_DECREMENTAR_A_MINUTOS_DECENAS_EN_ALARM_DISPLAY
					;Si A_MINUTOS_UNIDADES!=0xFF, solo lo guardamos y salimos con protocolo
					STS		A_MINUTOS_UNIDADES, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
					ESTABLECER_A_MINUTOS_UNIDADES_Y_DECREMENTAR_A_MINUTOS_DECENAS_EN_ALARM_DISPLAY:
						LDI		R16, 9
						STS		A_MINUTOS_UNIDADES, R16
						LDS		R16, A_MINUTOS_DECENAS
						DEC		R16
						;Revisamos si A_MINUTOS_DECENAS=0xFF. Si A_MINUTOS_DECENAS=0xFF y A_HORAS=0, apagamos ALARM_SET. Si...
						;A_MINUTOS_DECENAS=0xFF y A_HORAS!=0, establecemos A_MINUTOS=59. Si A_MINUTOS_DECENAS!=0xFF...
						;solo guardamos y salimos con protocolo
						CPI		R16, 0xFF
						BREQ	REVISAR_A_HORAS_EN_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
						STS		A_MINUTOS_DECENAS, R16
						RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
						REVISAR_A_HORAS_EN_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY:
							;Si A_HORAS_UNIDADES=A_HORAS_DECENAS=0, apagamos SET_ALARM y guardamos 0 en A_MINUTOS y...
							;A_HORAS. Si A_HORAS!=0, establecemos minutos
							LDS		R16, A_HORAS_UNIDADES
							LDS		R17, A_HORAS_DECENAS
							ADD		R16, R17
							;¡Ya existe la rutina!
							BRNE	ESTABLECER_MINUTOS_EN_ALARM_DISPLAY
							RJMP	APAGAR_ALARM_SET_Y_GUARDAR_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_A_MINUTOS_EN_ALARM_DISPLAY
							ESTABLECER_MINUTOS_EN_ALARM_DISPLAY:
								LDI		R16, 5
								STS		A_MINUTOS_DECENAS, R16
								LDI		R16, 9
								STS		A_MINUTOS_UNIDADES, R16
								RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY
			SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_MINUTOS_EN_ALARM_DISPLAY:
				;APAGAMOS CAMBIO (El cambio ya fue interpretado y ejecutado)
				CLT
				BLD		ENCODER, CAMBIO
				RET

		CONFIGURAR_HORAS_DE_ALARM_DISPLAY:
			;Apagamos ALARM_VALID en ALARM_REGISTER
			LDS		R16, ALARM_REGISTER
			CLT		
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			;Si CAMBIO=0, salimos de la rutina sin protocolo.
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar A_HORAS
			;Si DIRECCION=1, incrementamos A_HORAS
			;Si no, decrementamos A_HORAS
			SBRS	ENCODER, DIRECCION
			RJMP	DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
			RJMP	INCREMENTAR_A_HORAS_EN_ALARM_DISPLAY
			INCREMENTAR_A_HORAS_EN_ALARM_DISPLAY:
				;Habilitamos o deshabilitamos ALARM_REGISTER en caso de ser necesario.
				;Verificamos si ALARM_REGISTER está habilitada primero. Si no, la habilitamos y ajustamos A_MINUTOS...
				;y A_HORAS
				LDS		R16, ALARM_REGISTER
				SBRS	R16, ALARM_SET
				RJMP	ENCENDER_ALARM_SET_Y_CERO_EN_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_HORAS_EN_ALARM_DISPLAY
				RJMP	SUMAR_UNO_EN_A_HORAS_EN_ALARM_DISPLAY
				ENCENDER_ALARM_SET_Y_CERO_EN_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_HORAS_EN_ALARM_DISPLAY:
					;Encendemos ALARM_SET
					LDS		R16, ALARM_REGISTER
					SET
					BLD		R16, ALARM_SET
					STS		ALARM_REGISTER, R16
					;Guardamos "00" en "A_MINUTOS" y "A_HORAS"
					LDI		R16, 0
					STS		A_MINUTOS_UNIDADES, R16
					STS		A_MINUTOS_DECENAS, R16
					STS		A_HORAS_UNIDADES, R16
					STS		A_HORAS_DECENAS, R16
					;Salimos con protocolo
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
				SUMAR_UNO_EN_A_HORAS_EN_ALARM_DISPLAY:
					;¡Teniendo cuidado de reiniciar HORAS_UNIDADES e incrementar HORAS_DECENAS de ser necesario!
					LDS		R16, A_HORAS_UNIDADES
					INC		R16
					CPI		R16, 10
					BREQ	REINICIAR_A_HORAS_UNIDADES_E_INCREMENTAR_A_HORAS_DECENAS_EN_ALARM_DISPLAY
					;Si A_HORAS_UNIDADES!=10, revisamos si A_HORAS=24. Si sí, y A_MINUTOS!=0 reiniciamos HORAS...
					;a 0 y salimos de la rutina con protocolo. Si A_MINUTOS=0, apagamos ALARM_SET y salimos de la...
					;rutina con protocolo. A_HORAS!=24, salimos de la rutina con protocolo.
					STS		A_HORAS_UNIDADES, R16
					LDS		R17, A_HORAS_DECENAS
					LDI		R18, 10
					MUL		R17, R18
					ADD		R16, R0
					CPI		R16, 24
					BREQ	REVISAR_A_MINUTOS_EN_INCREMENTAR_A_HORAS_EN_ALARM_DISPLAY
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
					REINICIAR_A_HORAS_UNIDADES_E_INCREMENTAR_A_HORAS_DECENAS_EN_ALARM_DISPLAY:
						LDI		R16, 0
						STS		A_HORAS_UNIDADES, R16
						LDS		R16, A_HORAS_DECENAS
						INC		R16
						STS		A_HORAS_DECENAS, R16
						RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
					REVISAR_A_MINUTOS_EN_INCREMENTAR_A_HORAS_EN_ALARM_DISPLAY:
						;Si A_MINUTOS_UNIDADES=A_MINUTOS_DECENAS=0, apagamos SET_ALARM y guardamos 0 en A_MINUTOS y...
						;A_HORAS. Si A_MINUTOS!=0, reiniciamos HORAS
						LDS		R16, A_MINUTOS_UNIDADES
						LDS		R17, A_MINUTOS_DECENAS
						ADD		R16, R17
						BREQ	APAGAR_ALARM_SET_Y_GUARDAR_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_HORAS_EN_ALARM_DISPLAY
						RJMP	REINICIAR_HORAS_EN_ALARM_DISPLAY
						APAGAR_ALARM_SET_Y_GUARDAR_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_HORAS_EN_ALARM_DISPLAY:
							;Apagamos ALARM_SET
							LDS		R16, ALARM_REGISTER
							CLT
							BLD		R16, ALARM_SET
							STS		ALARM_REGISTER, R16
							;Guardamos 0 en A_MINUTOS y A_HORAS
							LDI		R16, 0
							STS		A_MINUTOS_UNIDADES, R16
							STS		A_MINUTOS_DECENAS, R16
							STS		A_HORAS_UNIDADES, R16
							STS		A_HORAS_DECENAS, R16
							RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
						REINICIAR_HORAS_EN_ALARM_DISPLAY:
							LDI		R16, 0
							STS		A_HORAS_UNIDADES, R16
							STS		A_HORAS_DECENAS, R16
							RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
			DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY:
				;Habilitamos o deshabilitamos ALARM_REGISTER en caso de ser necesario.
				;Verificamos si ALARM_REGISTER está habilitada primero. Si no, la habilitamos y ajustamos A_MINUTOS...
				;y A_HORAS
				LDS		R16, ALARM_REGISTER
				SBRS	R16, ALARM_SET
				RJMP	ENCENDER_ALARM_SET_AJUSTAR_A_HORAS_Y_CERO_EN_A_MINUTOS_EN_ALARM_DISPLAY
				RJMP	RESTAR_UNO_EN_A_HORAS_EN_ALARM_DISPLAY
				ENCENDER_ALARM_SET_AJUSTAR_A_HORAS_Y_CERO_EN_A_MINUTOS_EN_ALARM_DISPLAY:
					;Encendemos ALARM_SET
					LDS		R16, ALARM_REGISTER
					SET
					BLD		R16, ALARM_SET
					STS		ALARM_REGISTER, R16
					;Ajustamos A_HORAS y A_MINUTOS
					LDI		R16, 0
					STS		A_MINUTOS_UNIDADES, R16
					STS		A_MINUTOS_DECENAS, R16
					LDI		R16, 2
					STS		A_HORAS_DECENAS, R16
					LDI		R16, 3
					STS		A_HORAS_UNIDADES, R16
					;Y salimos con protocolo
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
				RESTAR_UNO_EN_A_HORAS_EN_ALARM_DISPLAY:
					;¡Teniendo cuidado de establecer HORAS_UNIDADES=9 y decrementar HORAS_DECENAS de ser necesario!
					LDS		R16, A_HORAS_UNIDADES
					DEC		R16
					CPI		R16, 0xFF
					BREQ	ESTABLECER_A_HORAS_UNIDADES_Y_DECREMENTAR_A_HORAS_DECENAS_EN_ALARM_DISPLAY
					;Si A_HORAS_UNIDADES!=0xFF, solo lo guardamos y salimos con protocolo
					STS		A_HORAS_UNIDADES, R16
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
					ESTABLECER_A_HORAS_UNIDADES_Y_DECREMENTAR_A_HORAS_DECENAS_EN_ALARM_DISPLAY:
						LDI		R16, 9
						STS		A_HORAS_UNIDADES, R16
						LDS		R16, A_HORAS_DECENAS
						DEC		R16
						;Revisamos si A_HORAS_DECENAS=0xFF. Si A_HORAS_DECENAS=0xFF y A_MINUTOS=0, apagamos ALARM_SET. Si...
						;A_HORAS_DECENAS=0xFF y A_MINUTOS!=0, establecemos A_HORAS=23. Si A_HORAS_DECENAS!=0xFF...
						;solo guardamos y salimos con protocolo
						CPI		R16, 0xFF
						BREQ	REVISAR_A_MINUTOS_EN_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
						STS		A_HORAS_DECENAS, R16
						RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
						REVISAR_A_MINUTOS_EN_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY:
							;Si A_MINUTOS_UNIDADES=A_MINUTOS_DECENAS=0, apagamos SET_ALARM y guardamos 0 en A_MINUTOS y...
							;A_HORAS. Si A_MINUTOS!=0, establecemos HORAS
							LDS		R16, A_MINUTOS_UNIDADES
							LDS		R17, A_MINUTOS_DECENAS
							ADD		R16, R17
							;¡Ya existe la rutina!
							BRNE	ESTABLECER_HORAS_EN_ALARM_DISPLAY	
							RJMP	APAGAR_ALARM_SET_Y_GUARDAR_A_MINUTOS_Y_A_HORAS_EN_CONFIGURAR_HORAS_EN_ALARM_DISPLAY
							ESTABLECER_HORAS_EN_ALARM_DISPLAY:
								LDI		R16, 3
								STS		A_HORAS_UNIDADES, R16
								LDI		R16, 2
								STS		A_HORAS_DECENAS, R16
								RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY
			SALIR_DE_INCREMENTAR_O_DECREMENTAR_A_HORAS_EN_ALARM_DISPLAY:
				;APAGAMOS CAMBIO (El cambio ya fue interpretado y ejecutado)
				CLT
				BLD		ENCODER, CAMBIO
				RET

		CONFIGURAR_MODO_EN_CUALQUIER_DISPLAY:
			;Encendemos ALARM_VALID en ALARM_REGISTER
			LDS		R16, ALARM_REGISTER
			SET		
			BLD		R16, ALARM_VALID
			STS		ALARM_REGISTER, R16
			;Si CAMBIO=0, salimos sin protocolo
			SBRS	ENCODER, CAMBIO
			RET
			;Si CAMBIO=1, revisamos si debemos incrementar o decrementar MODO
			;Si DIRECCION=1, incrementamos MODO
			;Si no, decrementamos MODO
			SBRS	ENCODER, DIRECCION
			RJMP	DECREMENTAR_MODO_NUEVO_EN_CUALQUIER_DISPLAY
			RJMP	INCREMENTAR_MODO_NUEVO_EN_CUALQUIER_DISPLAY
			INCREMENTAR_MODO_NUEVO_EN_CUALQUIER_DISPLAY:
				;Leemos MODO_NUEVO con una máscara
				;Si MODO=00, escribimos MODO=01
				;Si MODO=01, escribimos MODO=10
				;Si MODO=10, escribimos MODO=00
				LDI		R16, (1 << MODO1) | (1 << MODO0)
				AND		R16, MODO
				CPI		R16, (0 << MODO1) | (0 << MODO0)
				BREQ	ESCRIBIR_MODO_CERO_UNO
				CPI		R16, (0 << MODO1) | (1 << MODO0)
				BREQ	ESCRIBIR_MODO_UNO_CERO
				CPI		R16, (1 << MODO1) | (0 << MODO0)
				BREQ	ESCRIBIR_MODO_CERO_CERO
				ESCRIBIR_MODO_CERO_UNO:
					CLT
					BLD		MODO, MODO1
					SET
					BLD		MODO, MODO0
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MODO_EN_CUALQUIER_DISPLAY
				ESCRIBIR_MODO_UNO_CERO:
					SET
					BLD		MODO, MODO1
					CLT
					BLD		MODO, MODO0
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MODO_EN_CUALQUIER_DISPLAY
				ESCRIBIR_MODO_CERO_CERO:
					CLT
					BLD		MODO, MODO1
					CLT
					BLD		MODO, MODO0
					RJMP	SALIR_DE_INCREMENTAR_O_DECREMENTAR_MODO_EN_CUALQUIER_DISPLAY
			DECREMENTAR_MODO_NUEVO_EN_CUALQUIER_DISPLAY:
				;Leemos MODO_NUEVO con una máscara
				;Si MODO=00, escribimos MODO=10
				;Si MODO=01, escribimos MODO=00
				;Si MODO=10, escribimos MODO=01
				;¡Las rutinas ya están creadas!
				LDI		R16, (1 << MODO1) | (1 << MODO0)
				AND		R16, MODO
				CPI		R16, (0 << MODO1) | (0 << MODO0)
				BREQ	ESCRIBIR_MODO_UNO_CERO
				CPI		R16, (0 << MODO1) | (1 << MODO0)
				BREQ	ESCRIBIR_MODO_CERO_CERO
				CPI		R16, (1 << MODO1) | (0 << MODO0)
				BREQ	ESCRIBIR_MODO_CERO_UNO
			SALIR_DE_INCREMENTAR_O_DECREMENTAR_MODO_EN_CUALQUIER_DISPLAY:
				;APAGAMOS CAMBIO (El cambio ya fue interpretado y ejecutado)
				CLT
				BLD		ENCODER, CAMBIO
				RET
; QUINTO PASO: Actualizar valores HEX para displays (Funciones TIME_DISPLAY, DATE_DISPLAY, y ALARM_DISPLAY).

	QUINTO_PASO:
/*
	ACTUALIZAR_DISPLAYS:
		;Primero, revisamos MODOn en el registro MODO. Dependiendo de su configuración,...
		;decidimos qué sacar en los displays
		LDI		R17, (1 << MODO1) | (1 << MODO0)
		AND		R17, MODO
		;Si MODO=00, sacamos H en DISPMODE y TIME_DISPLAY
		CPI		R17, (0 << MODO1) | (0 << MODO0)
		BREQ	H_EN_DISPMODE_Y_TIME_DISPLAY
		;Si MODO=01, sacamos F en DISPMODE y DATE_DISPLAY
		CPI		R17, (0 << MODO1) | (1 << MODO0)
		BREQ	F_EN_DISPMODE_Y_DATE_DISPLAY
		;Si MODO=10, sacamos A en DISPMODE y ALARM_DISPLAY
		CPI		R17, (1 << MODO1) | (0 << MODO0)
		BREQ	A_EN_DISPMODE_Y_ALARM_DISPLAY

		H_EN_DISPMODE_Y_TIME_DISPLAY:
			CALL	H_EN_DISPMODE
			CALL	TIME_DISPLAY
			;¡Reiniciamos el LOOP!
			JMP		LOOP

		F_EN_DISPMODE_Y_DATE_DISPLAY:
			CALL	F_EN_DISPMODE
			CALL	DATE_DISPLAY
			;¡Reiniciamos el LOOP!
			JMP		LOOP
			
		A_EN_DISPMODE_Y_ALARM_DISPLAY:
			CALL	A_EN_DISPMODE
			CALL	ALARM_DISPLAY
			;¡Reiniciamos el LOOP!
			JMP		LOOP
*/

	;*******************************************************************************************************************************************

	;*******************************************************************************************************************************************
		;¡Sub-rutinas del QUINTO PASO!
/*
		H_EN_DISPMODE:
			LDI		XL, LOW(DISPMODE_H)
			LDI		XH, HIGH(DISPMODE_H)
			LD		R16, X
			STS		DISPMODE_VALUE, R16
			RET

		F_EN_DISPMODE:
			LDI		XL, LOW(DISPMODE_F)
			LDI		XH, HIGH(DISPMODE_F)
			LD		R16, X
			STS		DISPMODE_VALUE, R16
			RET

		A_EN_DISPMODE:
			LDI		XL, LOW(DISPMODE_A)
			LDI		XH, HIGH(DISPMODE_A)
			LD		R16, X
			STS		DISPMODE_VALUE, R16
			RET
*/
		TIME_DISPLAY:
			;Guardamos DISPS 0&1 con los HEX de MINUTOS_UNIDADES y MINUTOS_DECENAS respectivamente (Ajustamos el ZPointer)
			;MINUTOS_UNIDADES en DISP0:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MINUTOS_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP0_VALUE, R16
			;MINUTOS_DECENAS en DISP1:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MINUTOS_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP1_VALUE, R16
			;Guardamos DISPS 2&3 con los HEX de HORAS_UNIDADES y HORAS_DECENAS respectivamente (Ajustamos el ZPointer)
			;HORAS_UNIDADES en DISP2:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, HORAS_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP2_VALUE, R16
			;HORAS_DECENAS en DISP3:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, HORAS_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP3_VALUE, R16
			;Nos salimos
			RET

		DATE_DISPLAY:
			;Guardamos DISPS 0&1 con los HEX de MESES_UNIDADES y MESES_DECENAS respectivamente (Ajustamos el ZPointer)
			;MESES_UNIDADES en DISP0:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MESES_UNIDADES
			ADD		ZL, R16 
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP0_VALUE, R16
			;MESES_DECENAS en DISP1:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, MESES_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP1_VALUE, R16
			;Guardamos DISPS 2&3 con los HEX de DIAS_UNIDADES y DIAS_DECENAS respectivamente (Ajustamos el ZPointer)
			;DIAS_UNIDADES en DISP2:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, DIAS_UNIDADES
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP2_VALUE, R16
			;DIAS_DECENAS en DISP3:
			LDI		ZL, LOW(DISP7SEG << 1)
			LDI		ZH, HIGH(DISP7SEG << 1)
			LDS		R16, DIAS_DECENAS
			ADD		ZL, R16
			ADC		ZH, R5									; R5=0
			LPM		R16, Z
			STS		DISP3_VALUE, R16
			;Nos salimos
			RET

		ALARM_DISPLAY:
			;Primero revisamos si ALARM_SET=1 en ALARM_REGISTER. Si sí, sacamos en DISPS los valores guardados en...
			;A_MINUTOS y A_HORAS. Si no, sacamos "-" en  los DISPS.
			LDS		R16, ALARM_REGISTER
			SBRC	R16, ALARM_SET
			RJMP	NUMEROS_EN_ALARM_DISPLAY
			RJMP	GUIONES_EN_ALARM_DISPLAY
			GUIONES_EN_ALARM_DISPLAY:
				LDS		R16, DISP_GUION
				STS		DISP0_VALUE, R16
				STS		DISP1_VALUE, R16
				STS		DISP2_VALUE, R16
				STS		DISP3_VALUE, R16
				RJMP	SALIR_DE_ALARM_DISPLAY
			NUMEROS_EN_ALARM_DISPLAY:
				;A_MINUTOS_UNIDADES en DISP0:
				LDI		ZL, LOW(DISP7SEG << 1)
				LDI		ZH, HIGH(DISP7SEG << 1)
				LDS		R16, A_MINUTOS_UNIDADES
				ADD		ZL, R16
				ADC		ZH, R5									; R5=0
				LPM		R16, Z
				STS		DISP0_VALUE, R16
				;A_MINUTOS_DECENAS en DISP1:
				LDI		ZL, LOW(DISP7SEG << 1)
				LDI		ZH, HIGH(DISP7SEG << 1)
				LDS		R16, A_MINUTOS_DECENAS
				ADD		ZL, R16
				ADC		ZH, R5									; R5=0
				LPM		R16, Z
				STS		DISP1_VALUE, R16
				;Guardamos DISPS 2&3 con los HEX de A_HORAS_UNIDADES y A_HORAS_DECENAS respectivamente (Ajustamos el ZPointer)
				;A_HORAS_UNIDADES en DISP2:
				LDI		ZL, LOW(DISP7SEG << 1)
				LDI		ZH, HIGH(DISP7SEG << 1)
				LDS		R16, A_HORAS_UNIDADES
				ADD		ZL, R16
				ADC		ZH, R5									; R5=0
				LPM		R16, Z
				STS		DISP2_VALUE, R16
				;A_HORAS_DECENAS en DISP3:
				LDI		ZL, LOW(DISP7SEG << 1)
				LDI		ZH, HIGH(DISP7SEG << 1)
				LDS		R16, A_HORAS_DECENAS
				ADD		ZL, R16
				ADC		ZH, R5									; R5=0
				LPM		R16, Z
				STS		DISP3_VALUE, R16
				RJMP	SALIR_DE_ALARM_DISPLAY
			SALIR_DE_ALARM_DISPLAY:
				;Nos salimos
				RET
/*****************************************************************************************************************************************************/

// NON-Interrupt subroutines
; ¡Rutinas generales NO de interrupción!

INCREMENTAR_MINUTOS_RUTINA:
	;¡Teniendo cuidado de reiniciar MINUTOS_UNIDADES e incrementar MINUTOS_DECENAS de ser necesario!
	;Si MINUTOS_DECENAS=6, depende del paso en que nos encontremos el determinar qué hacer con ello
	LDS		R16, MINUTOS_UNIDADES
	INC		R16
	CPI		R16, 10
	BREQ	REINICIAR_MINUTOS_UNIDADES_E_INCREMENTAR_MINUTOS_DECENAS_RUTINA
	;Si MINUTOS_UNIDADES!=10, solo lo guardamos...
	STS		MINUTOS_UNIDADES, R16
	RJMP	SALIR_DE_INCREMENTAR_MINUTOS_RUTINA
	REINICIAR_MINUTOS_UNIDADES_E_INCREMENTAR_MINUTOS_DECENAS_RUTINA:
		LDI		R16, 0
		STS		MINUTOS_UNIDADES, R16
		LDS		R16, MINUTOS_DECENAS
		INC		R16
		STS		MINUTOS_DECENAS, R16
		RJMP	SALIR_DE_INCREMENTAR_MINUTOS_RUTINA
	SALIR_DE_INCREMENTAR_MINUTOS_RUTINA:
		RET

INCREMENTAR_HORAS_RUTINA:
	;¡Teniendo cuidado de reiniciar HORAS_UNIDADES e incrementar HORAS_DECENAS de ser necesario!
	;Si HORAS=24, depende del paso en que nos encontremos el determinar qué hacer con ello
	LDS		R16, HORAS_UNIDADES
	INC		R16
	CPI		R16, 10
	BREQ	REINICIAR_HORAS_UNIDADES_E_INCREMENTAR_HORAS_DECENAS_RUTINA
	;Si HORAS_UNIDADES!=10, solo lo guardamos...
	STS		HORAS_UNIDADES, R16
	RJMP	SALIR_DE_INCREMENTAR_HORAS_RUTINA
	REINICIAR_HORAS_UNIDADES_E_INCREMENTAR_HORAS_DECENAS_RUTINA:	
		LDI		R16, 0
		STS		HORAS_UNIDADES, R16
		LDS		R16, HORAS_DECENAS
		INC		R16
		STS		HORAS_DECENAS, R16
		RJMP	SALIR_DE_INCREMENTAR_HORAS_RUTINA
	SALIR_DE_INCREMENTAR_HORAS_RUTINA:
		RET

INCREMENTAR_DIAS_RUTINA:
	;¡Teniendo cuidado de reiniciar DIAS_UNIDADES e incrementar DIAS_DECENAS de ser necesario!
	;Si DIAS=DIAS_DEL_MES, depende del paso en que nos encontremos el determinar qué hacer con ello
	LDS		R16, DIAS_UNIDADES
	INC		R16
	CPI		R16, 10
	BREQ	REINICIAR_DIAS_UNIDADES_E_INCREMENTAR_DIAS_DECENAS_RUTINA
	;Si DIAS_UNIDADES!=10, solo lo guardamos...
	STS		DIAS_UNIDADES, R16
	RJMP	SALIR_DE_INCREMENTAR_DIAS_RUTINA
	REINICIAR_DIAS_UNIDADES_E_INCREMENTAR_DIAS_DECENAS_RUTINA:
		LDI		R16, 0
		STS		DIAS_UNIDADES, R16
		LDS		R16, DIAS_DECENAS
		INC		R16
		STS		DIAS_DECENAS, R16
		RJMP	SALIR_DE_INCREMENTAR_DIAS_RUTINA
	SALIR_DE_INCREMENTAR_DIAS_RUTINA:
		RET

INCREMENTAR_MESES_RUTINA:
	;¡Teniendo cuidado de reiniciar MESES_UNIDADES e incrementar MESES_DECENAS de ser necesario!
	;Si MESES=13, depende del paso en que nos encontremos el determinar qué hacer con ello
	;Incrementamos YPointer
	ADIW	Y, 1							
	LDS		R16, MESES_UNIDADES
	INC		R16
	CPI		R16, 10
	BREQ	REINICIAR_MESES_UNIDADES_E_INCREMENTAR_MESES_DECENAS_RUTINA
	;Si MESES_UNIDADES!=10, solo lo guardamos...
	STS		MESES_UNIDADES, R16
	RJMP	SALIR_DE_INCREMENTAR_MESES_RUTINA
	REINICIAR_MESES_UNIDADES_E_INCREMENTAR_MESES_DECENAS_RUTINA:
		LDI		R16, 0
		STS		MESES_UNIDADES, R16
		LDS		R16, MESES_DECENAS
		INC		R16
		STS		MESES_DECENAS, R16
		RJMP	SALIR_DE_INCREMENTAR_MESES_RUTINA
	SALIR_DE_INCREMENTAR_MESES_RUTINA:
		RET
;***********************************************************************************************************************************************

// Interrupt routines
TIM1_INTERRUPT:
	;Empujamos registros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	PUSH	R17
	PUSH	R18
	;Reseteamos TIM1
	LDI		R16, T1VALUE_H
	STS		TCNT1H, R16
	LDI		R16, T1VALUE_L
	STS		TCNT1L, R16	
	;Incrementamos el contador de segundos
	INC		sCOUNT
	;Verificamos si hay alarma activa. Si sí, incrementamos ALARMA_SEGUNDOS. Si no, nos salimos
	LDS		R16, ALARM_REGISTER
	SBRS	R16, ALARM_ACTIVE
	RJMP	TIM1_EXIT
	RJMP	INCREMENTAR_ALARMA_SEGUNDOS
	INCREMENTAR_ALARMA_SEGUNDOS:
		LDS		R16, ALARMA_SEGUNDOS
		INC		R16
		STS		ALARMA_SEGUNDOS, R16
		RJMP	TIM1_EXIT
	TIM1_EXIT:
		;Sacamos registros del STACK
		POP		R18
		POP		R17
		POP		R16
		OUT		SREG, R16
		POP		R16
		RETI

TIM0_INTERRUPT:	
	;Empujamos registros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	PUSH	R17
	PUSH	R18
	;Habilitamos interrupciones anidadas (Solo para TIM1, así que se desactiva PCIE)
	SEI
	LDI		R16, (0 << PCIE1)
    STS		PCICR, R16
	;Reseteamos TIM0
	LDI		R16, T0VALUE
	OUT		TCNT0, R16
	;Incrementamos el contador de milisegundos
	INC		msCOUNT0
	;Revisamos MODO(SETUP_) y MODO(MODE_SELECT) para ver si existe algún parpadeo:
	;Si MODO(MODE_SELECT)=1, debe parpadear DISPMODE
	;Si MODO(SETUP_)=1, y SETUP_VALUE=0 deben parpadear DISPS0,1
	;Si MODO(SETUP_)=1, y SETUP_VALUE=1 deben parpadear DISPS2,3
	;Si ninguno, SETUP_ ni MODE_SELECT, está encendido, realizamos una multiplexación normal
	SBRC	MODO, MODE_SELECT
	RJMP	PARPADEO_EN_DISPMODE
	;Creamos una máscara 
	LDI		R17, (1 << SETUP_) | (1 << SETUP_VALUE) 
	AND		R17, MODO
	REV_TIM_CERO:
	CPI		R17, (1 << SETUP_) | (0 << SETUP_VALUE) 
	BRNE	REV_TIM_UNO
	RJMP	PARPADEO_EN_DISPS_CERO_Y_UNO
	REV_TIM_UNO:
	CPI		R17, (1 << SETUP_) | (1 << SETUP_VALUE) 
	BRNE	REV_TIM_DOS
	RJMP	PARPADEO_EN_DISPS_DOS_Y_TRES
	REV_TIM_DOS:
	RJMP	MUX_NORMAL
	MUX_NORMAL:
		;Rutina para multiplexar displays..."D(n)" se refiere a "Display(n)":
		;Nos guiamos con, y actualizamos "MUX_SECUENCIA"
		;Si el bit D(n) en MUX_SECUENCIA está apagado, el bit no estaba encendiendo un transistor, entonces...
		;no le damos importancia
		;Por el contrario, si el bit D(n) en MUX_SECUENCIA está encendido, el bit estaba encendiendo un...
		;transistor, así que apagamos el PIN D(n) y encendemos el PIN D(n+1)
		;En cada apagado y/o encendido, actualizamos "MUX_SECUENCIA" para que, en caso de un posible próximo parpadeo...
		;sepamos cómo iba la secuencia.
		SBRC	MUX_SECUENCIA, 0
		RJMP	ENCENDER_D1_Y_APAGAR_D0
		SBRC	MUX_SECUENCIA, 1
		RJMP	ENCENDER_D2_Y_APAGAR_D1
		SBRC	MUX_SECUENCIA, 2
		RJMP	ENCENDER_D3_Y_APAGAR_D2
		SBRC	MUX_SECUENCIA, 3
		RJMP	ENCENDER_D4_Y_APAGAR_D3
		SBRC	MUX_SECUENCIA, 4
		RJMP	ENCENDER_D0_Y_APAGAR_D4
		RJMP	TIM0_EXIT
			ENCENDER_D1_Y_APAGAR_D0:
				;Primero apagamos D0 (Evitamos "ghosting")
				CBI		PORTB, 0
				;Cargamos el valor de DISP1 a R16
				LDS		R16, DISP1_VALUE
				;Para verificar si se deben encender o apagar los dos puntos, revisamos el estado actual de PORTD
				;El valor de PD7 varía por el PRIMER PASO del LOOP
				;Entonces, cargamos PD7 a un registro vacío (R18), y, como los valores HEX guardados SIEMPRE tienen a PD7...
				;apagado, hacemos un OR entre el valor de DISP1 y el registro con el valor de PD7 (R16 OR R18)
				IN		R17, PORTD
				BST		R17, 7
				LDI		R18, 0
				BLD		R18, 7
				OR		R16, R18
				;Subimos el valor resultante a PORTD
				OUT		PORTD, R16
				;Encendemos D1
				SBI		PORTB, 1
				;Y actualizamos MUX_SECUENCIA
				LDI		MUX_SECUENCIA, 0b00000010
				RJMP	TIM0_EXIT
			ENCENDER_D2_Y_APAGAR_D1:
				;Primero apagamos D1 (Evitamos "ghosting")
				CBI		PORTB, 1
				;Cargamos el valor de DISP2 a R16
				LDS		R16, DISP2_VALUE
				;Verificamos el valor de los dos puntos...
				IN		R17, PORTD
				BST		R17, 7
				LDI		R18, 0
				BLD		R18, 7
				OR		R16, R18
				;Subimos el valor resultante a PORTD
				OUT		PORTD, R16
				;Encendemos D2
				SBI		PORTB, 2
				;Y actualizamos MUX_SECUENCIA
				LDI		MUX_SECUENCIA, 0b00000100
				RJMP	TIM0_EXIT
			ENCENDER_D3_Y_APAGAR_D2:
				;Primero apagamos D2 (Evitamos "ghosting")
				CBI		PORTB, 2
				;Cargamos el valor de DISP3 a R16
				LDS		R16, DISP3_VALUE
				;Verificamos el valor de los dos puntos...
				IN		R17, PORTD
				BST		R17, 7
				LDI		R18, 0
				BLD		R18, 7
				OR		R16, R18
				;Subimos el valor resultante a PORTD
				OUT		PORTD, R16
				;Encendemos D3
				SBI		PORTB, 3
				;Y actualizamos MUX_SECUENCIA
				LDI		MUX_SECUENCIA, 0b00001000
				RJMP	TIM0_EXIT
			ENCENDER_D4_Y_APAGAR_D3:
				;Primero apagamos D3 (Evitamos "ghosting")
				CBI		PORTB, 3
				;Cargamos el valor de DISPMODE (Ojo) a R16
				LDS		R16, DISPMODE_VALUE
				;Verificamos el valor de los dos puntos...
				IN		R17, PORTD
				BST		R17, 7
				LDI		R18, 0
				BLD		R18, 7
				OR		R16, R18
				;Subimos el valor resultante a PORTD
				OUT		PORTD, R16
				;Encendemos D4
				SBI		PORTB, 4
				;Y actualizamos MUX_SECUENCIA
				LDI		MUX_SECUENCIA, 0b00010000
				RJMP	TIM0_EXIT
			ENCENDER_D0_Y_APAGAR_D4:
				;Primero apagamos D4 (Evitamos "ghosting")
				CBI		PORTB, 4
				;Cargamos el valor de DISP0 a R16
				LDS		R16, DISP0_VALUE
				;Verificamos el valor de los dos puntos...
				IN		R17, PORTD
				BST		R17, 7
				LDI		R18, 0
				BLD		R18, 7
				OR		R16, R18
				;Subimos el valor resultante a PORTD
				OUT		PORTD, R16
				;Encendemos D0
				SBI		PORTB, 0
				;Y actualizamos MUX_SECUENCIA
				LDI		MUX_SECUENCIA, 0b00000001
				RJMP	TIM0_EXIT
	PARPADEO_EN_DISPMODE:
		;Revisamos si BLINKSTATE=1. Si sí, realizamos la rutina convencional de muxeo "MUX_NORMAL". Si no...
		;únicamente revisamos DISPS1,2,3, y dejamos apagado DISPMODE... ¡PERO ACTUALIZAMOS MUX_SECUENCIA!
		;Nos guiamos con, y actualizamos "MUX_SECUENCIA"
		SBRC	MODO, BLINKSTATE
		RJMP	MUX_NORMAL
		;Si BLINKSTATE=0...
		;Disps0,1,2,3 mantienen las mismas rutinas que MUX_NORMAL
		;Pero creamos una nueva para DISPMODE
		SBRC	MUX_SECUENCIA, 0
		RJMP	ENCENDER_D1_Y_APAGAR_D0
		SBRC	MUX_SECUENCIA, 1
		RJMP	ENCENDER_D2_Y_APAGAR_D1
		SBRC	MUX_SECUENCIA, 2
		RJMP	ENCENDER_D3_Y_APAGAR_D2
		SBRC	MUX_SECUENCIA, 3
		RJMP	APAGAR_D4_Y_APAGAR_D3
		SBRC	MUX_SECUENCIA, 4
		RJMP	ENCENDER_D0_Y_APAGAR_D4
		RJMP	TIM0_EXIT
			APAGAR_D4_Y_APAGAR_D3:
				;Como sabemos que el parpadeo de los dos puntos y el de los displays va en sincronía...
				;¡Solo subimos "0" a PORTD y PORTB!
				;PERO actualizamos MUX_SECUENCIA
				LDI		R16, 0
				OUT		PORTD, R16
				OUT		PORTB, R16
				LDI		MUX_SECUENCIA, 0b00010000
				RJMP	TIM0_EXIT
	PARPADEO_EN_DISPS_CERO_Y_UNO:
		;Revisamos si BLINKSTATE=1. Si sí, realizamos la rutina convencional de muxeo "MUX_NORMAL". Si no...
		;únicamente revisamos DISPMODE, y dejamos apagados DISPS0,1... ¡PERO ACTUALIZAMOS MUX_SECUENCIA!
		;Nos guiamos con, y actualizamos "MUX_SECUENCIA"
		SBRC	MODO, BLINKSTATE
		RJMP	MUX_NORMAL
		;Si BLINKSTATE=0...
		;DISPMODE y DISPS2,3 mantienen las misma rutina que MUX_NORMAL
		;Pero creamos unas nuevas para DISPS0,1
		SBRC	MUX_SECUENCIA, 0
		RJMP	APAGAR_D1_Y_APAGAR_D0
		SBRC	MUX_SECUENCIA, 1
		RJMP	ENCENDER_D2_Y_APAGAR_D1
		SBRC	MUX_SECUENCIA, 2
		RJMP	ENCENDER_D3_Y_APAGAR_D2
		SBRC	MUX_SECUENCIA, 3
		RJMP	ENCENDER_D4_Y_APAGAR_D3
		SBRC	MUX_SECUENCIA, 4
		RJMP	APAGAR_D0_Y_APAGAR_D4
		RJMP	TIM0_EXIT
		APAGAR_D1_Y_APAGAR_D0:
			;Como sabemos que el parpadeo de los dos puntos y el de los displays va en sincronía...
			;¡Solo subimos "0" a PORTD y PORTB!
			;PERO actualizamos MUX_SECUENCIA
			LDI		R16, 0
			OUT		PORTD, R16
			OUT		PORTB, R16
			LDI		MUX_SECUENCIA, 0b00000010
			RJMP	TIM0_EXIT
		APAGAR_D0_Y_APAGAR_D4:
			;Como sabemos que el parpadeo de los dos puntos y el de los displays va en sincronía...
			;¡Solo subimos "0" a PORTD y PORTB!
			;PERO actualizamos MUX_SECUENCIA
			LDI		R16, 0
			OUT		PORTD, R16
			OUT		PORTB, R16
			LDI		MUX_SECUENCIA, 0b00000001
			RJMP	TIM0_EXIT
	PARPADEO_EN_DISPS_DOS_Y_TRES:
		;Revisamos si BLINKSTATE=1. Si sí, realizamos la rutina convencional de muxeo "MUX_NORMAL". Si no...
		;únicamente revisamos DISPMODE, y dejamos apagados DISPS2,3... ¡PERO ACTUALIZAMOS MUX_SECUENCIA!
		;Nos guiamos con, y actualizamos "MUX_SECUENCIA"
		SBRC	MODO, BLINKSTATE
		RJMP	MUX_NORMAL
		;Si BLINKSTATE=0...
		;DISPMODE y DISPS0,1 mantienen las misma rutina que MUX_NORMAL
		;Pero creamos unas nuevas para DISPS0,1
		SBRC	MUX_SECUENCIA, 0
		RJMP	ENCENDER_D1_Y_APAGAR_D0
		SBRC	MUX_SECUENCIA, 1
		RJMP	APAGAR_D2_Y_APAGAR_D1
		SBRC	MUX_SECUENCIA, 2
		RJMP	APAGAR_D3_Y_APAGAR_D2
		SBRC	MUX_SECUENCIA, 3
		RJMP	ENCENDER_D4_Y_APAGAR_D3
		SBRC	MUX_SECUENCIA, 4
		RJMP	ENCENDER_D0_Y_APAGAR_D4
		RJMP	TIM0_EXIT
		APAGAR_D2_Y_APAGAR_D1:
			;Como sabemos que el parpadeo de los dos puntos y el de los displays va en sincronía...
			;¡Solo subimos "0" a PORTD y PORTB!
			;PERO actualizamos MUX_SECUENCIA
			LDI		R16, 0
			OUT		PORTD, R16
			OUT		PORTB, R16
			LDI		MUX_SECUENCIA, 0b00000100
			RJMP	TIM0_EXIT
		APAGAR_D3_Y_APAGAR_D2:
			;Como sabemos que el parpadeo de los dos puntos y el de los displays va en sincronía...
			;¡Solo subimos "0" a PORTD y PORTB!
			;PERO actualizamos MUX_SECUENCIA
			LDI		R16, 0
			OUT		PORTD, R16
			OUT		PORTB, R16
			LDI		MUX_SECUENCIA, 0b00001000
			RJMP	TIM0_EXIT
	TIM0_EXIT:
		;Rehabilitamos PCIE
		LDI		R16, (1 << PCIE1)
		STS		PCICR, R16
		;Y sacamos registros del STACK
		POP		R18
		POP		R17
		POP		R16
		OUT		SREG, R16
		POP		R16
		RETI

PINCHANGE_INTERRUPT:
	;Empujamos registros al STACK
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	PUSH	R17
	PUSH	R18
	;Habilitamos interrupciones anidadas (Solo para TIM1, así que se desactiva TIMSK0)
	SEI
	LDI		R16, (0 << TOIE0)
    STS		TIMSK0, R16
	;Hora de revisar todas las posibles interrupciones. Revisaremos EN_PB, EN0, y SET_SPDT. De EN_PB y EN0 SOLO nos...
	;importan los flancos de bajada. De SET_SPDT sí importa averigüar si es flanco positivo o negativo.
	;Entonces, revisamos:
	;Si EN_PB está encendido, no importa; lo saltamos y establecemos PB_LAST=1
	SBIS	PINC, EN_PB
	RJMP	REVISAR_EN_PB
	;Si EN_PB=1...
	SET
	BLD		ENCODER, PB_LAST
	;Si EN0  está encendido, no importa; lo saltamos.
	SBIS	PINC, EN0
	RJMP	REVISAR_EN_CERO
	;Si MODO(SETUP_)!=SET_SPDT, nos vamos a revisar SET_SPDT.
	;Creamos una máscara para comparar.
	LDI		R16, (1 << SETUP_)
	AND		R16, MODO
	LSL		R16
	LSL		R16
	IN		R17, PINC
	LDI		R18, (1 << SET_SPDT)
	AND		R18, R17
	CP		R18, R16
	BREQ	SALIR_DE_REVISION
	RJMP	REVISAR_SET_SPDT
	SALIR_DE_REVISION:
		;Si nada se cumple, salimos
		RJMP	PINCHANGE_EXIT
	REVISAR_EN_PB:
		;Primero verificamos si PB_LAST=EN_PB. Si sí, no hacemos nada.
		;Entonces, si PB_LAST=0, no hacemos nada. Si PB_LAST=1, cambiamos PB_LAST y seguimos la rutina
		SBRS	ENCODER, PB_LAST
		RJMP	PINCHANGE_EXIT
		;Si PB_LAST=1...
		CLT
		BLD		ENCODER, PB_LAST
		;Existen variedad de casos.
		;Ante todo, si ALARM_ACTIVE=1 en ALARM_REGISTER, APAGAMOS ALARM_ACTIVE, y resetamos ALARM_TIME
		LDS		R16, ALARM_REGISTER
		SBRS	R16, ALARM_ACTIVE
		RJMP	REVISION_NORMAL_DE_EN_PB
		RJMP	APAGAR_ALARMA_CON_EN_PB
		APAGAR_ALARMA_CON_EN_PB:
			LDI		R16, (1 << ALARM_VALID) | (0 << ALARM_ACTIVE) | (1 << ALARM_SET)
			STS		ALARM_REGISTER, R16
			LDI		R16, 0
			STS		ALARMA_SEGUNDOS, R16
			RJMP	PINCHANGE_EXIT
		REVISION_NORMAL_DE_EN_PB:

			;Si MODE_SELECT=0 y SETUP_=1, debemos "togglear" SETUP_VALUE.
			;Si MODE_SELECT=0 y SETUP_=0, debemos encender MODE_SELECT.
			;Si MODE_SELECT=1 y SETUP_=0, debemos apagar MODE_SELECT.
			;Creamos una máscara para evaluar

			LDI		R16, (1 << SETUP_) | (1 << MODE_SELECT)
			AND		R16, MODO
			CPI		R16, (1 << SETUP_) | (0 << MODE_SELECT)
			BREQ	TOGGLE_SETUP_VALUE
			CPI		R16, (0 << SETUP_) | (0 << MODE_SELECT)
			BREQ	ENCENDER_MODE_SELECT
			CPI		R16, (0 << SETUP_) | (1 << MODE_SELECT)
			BREQ	APAGAR_MODE_SELECT
			TOGGLE_SETUP_VALUE:
				;Si SETUP_VALUE=1, apagamos SETUP_VALUE
				;Si SETUP_VALUE=0, encendemos SETUP_VALUE
				SBRC	MODO, SETUP_VALUE
				RJMP	APAGAR_SETUP_VALUE
				RJMP	ENCENDER_SETUP_VALUE
				ENCENDER_SETUP_VALUE:
					SET
					BLD		MODO, SETUP_VALUE
					RJMP	PINCHANGE_EXIT
				APAGAR_SETUP_VALUE:
					CLT
					BLD		MODO, SETUP_VALUE
					RJMP	PINCHANGE_EXIT
			ENCENDER_MODE_SELECT:
				SET
				BLD		MODO, MODE_SELECT
				RJMP	PINCHANGE_EXIT
			APAGAR_MODE_SELECT:
				CLT
				BLD		MODO, MODE_SELECT
				RJMP	PINCHANGE_EXIT

	REVISAR_EN_CERO:
		;Revisamos primero si es CLOCKWISE o COUNTER-CW
		;Si PINC2 está encendido, es CLOCKWISE
		;Si PINC2 está apagado, es COUNTER-CW



		SBIS	PINC, EN1
		RJMP	GIRO_CLOCKWISE
		RJMP	GIRO_COUNTER_CLOCKWISE
		GIRO_CLOCKWISE:

			;Existen variedad de casos.
			;Si SETUP_=0, y MODE_SELECT=0, apagamos CAMBIO
			;Si SETUP_=0, y MODE_SELECT=1, encendemos ENCODER(CAMBIO) y establecemos ENCODER(DIRECCION)=1
			;Si SETUP_=1, y MODE_SELECT=0, encendemos ENCODER(CAMBIO) y establecemos ENCODER(DIRECCION)=1
			;Creamos una máscara para comparar


			LDI		R16, (1 << SETUP_) | (1 << MODE_SELECT)
			AND		R16, MODO
			CPI		R16, (0 << SETUP_) | (0 << MODE_SELECT)
			BREQ	APAGAR_CAMBIO
			CPI		R16, (0 << SETUP_) | (1 << MODE_SELECT)
			BREQ	ENCENDER_CAMBIO_Y_DIRECCION_UNO
			CPI		R16, (1 << SETUP_) | (0 << MODE_SELECT)
			BREQ	ENCENDER_CAMBIO_Y_DIRECCION_UNO
			APAGAR_CAMBIO:
				RJMP	PINCHANGE_EXIT
			ENCENDER_CAMBIO_Y_DIRECCION_UNO:
				SET
				BLD		ENCODER, CAMBIO
				SET
				BLD		ENCODER, DIRECCION
				RJMP	PINCHANGE_EXIT
		GIRO_COUNTER_CLOCKWISE:

			;Existen variedad de casos.
			;Si SETUP_=0, y MODE_SELECT=0, apagamos CAMBIO
			;Si SETUP_=0, y MODE_SELECT=1, encendemos ENCODER(CAMBIO) y establecemos ENCODER(DIRECCION)=0
			;Si SETUP_=1, y MODE_SELECT=0, encendemos ENCODER(CAMBIO) y establecemos ENCODER(DIRECCION)=0
			;Creamos una máscara para comparar

			LDI		R16, (1 << SETUP_) | (1 << MODE_SELECT)
			AND		R16, MODO
			CPI		R16, (0 << SETUP_) | (0 << MODE_SELECT)
			BREQ	APAGAR_CAMBIO
			CPI		R16, (0 << SETUP_) | (1 << MODE_SELECT)
			BREQ	ENCENDER_CAMBIO_Y_DIRECCION_CERO
			CPI		R16, (1 << SETUP_) | (0 << MODE_SELECT)
			BREQ	ENCENDER_CAMBIO_Y_DIRECCION_CERO
			ENCENDER_CAMBIO_Y_DIRECCION_CERO:
				SET
				BLD		ENCODER, CAMBIO
				CLT
				BLD		ENCODER, DIRECCION
				RJMP	PINCHANGE_EXIT
	REVISAR_SET_SPDT:
		;Revisamos primero si SETUP_SPDT está encendido o está apagado, y, cualsea su valor, se copia a SETUP_ en MODO.
		IN		R16, PINC
		LDI		R17, (1 << SET_SPDT)
		AND		R17, R16
		CPI		R17, (1 << SET_SPDT)
		BREQ	ENCENDER_SETUP_
		CPI		R17, (0 << SET_SPDT)
		BREQ	APAGAR_SETUP_
		ENCENDER_SETUP_:
			;Si encendemos SETUP_, debemos apagar MODE_SELECT (Sea que ya esté apagado, o sea que esté encendido)
			CLT
			BLD		MODO, MODE_SELECT
			SET
			BLD		ENCODER, CAMBIO
			;Ahora sí, encendemos SETUP_
			SET
			BLD		MODO, SETUP_
			RJMP	PINCHANGE_EXIT
		APAGAR_SETUP_:
			;Aquí no importa MODE_SELECT
			CLT
			BLD		MODO, SETUP_
			RJMP	PINCHANGE_EXIT
	PINCHANGE_EXIT:
		;Rehabilitamos TIMSK0
		LDI		R16, (1 << TOIE0)
		STS		TIMSK0, R16
		;Y sacamos registros del STACK
		POP		R18
		POP		R17
		POP		R16
		OUT		SREG, R16
		POP		R16
	reti
/****************************************/

