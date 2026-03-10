/*
* NombreProgra.asm
*
* Creado: 24 de abril del 2026
* Autor : Grettel Escobedo 23586
* Descripción: Creación de un codigo modular para el proyecto 1 de microcontroladores. 
*/
;=======================================
;Configuraciónnes 
; Aclaraciones

; TIMER0- multiplexación
; TIMER1 - conteo de minutos y horas.


; Hay un total de 3 leds por modo general, 1 buzzer como salida del modo 5, 2 leds para las horas.
; Se trabaja con un total de 6 modos. 3 generales y 3 de configuración. 
;

;=======================================================================
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)
.dseg
DISPRAM:
	.BYTE 16; de esta manera reservo los 16 datos de mi sram

.cseg
.org 0x0000; Se incia aqui para guardar.

	rjmp SETUP

.org PCI1addr;Pueba, luego cambiar a un nombre más significativo;
	rjmp ISR_PCINT1; mi ubicación al saltar en la etiqueta. 

;Guardamos un salto a la sub-rutina "RESET_TOGGLE" (cuando el timero se desvorda salta a la etiqueta)
.org  OVF0addr
	RJMP RESET_TOGGLE

.org 0x0022
 /*****************************************************************/


 ;=====================================
; Tablita para los valores del display
;======================================
; revisar si rompe el códgio. ojalá no.

	TABLA:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
		
;========================
;       Registros
;========================

	.def	MILLIS		= R19; Variable para mi milisegundos
	.def	COUNTDECS	= R18; Variable para mis decimas
	.def	COUNTSECS	= R20; Variable de mis segundos

	.def	SECStemp	= R21
	.def	DECStemp	= R25
	.def	COUNT		= R22

	.def	PUSHBOTTON_A	=  R8;R23 B1_ MODO : HORA/FECHA/ALARMA  --- Cambiarlo a un R diferente
	.def	PUSHBOTTON_B	=  R7;R24 B2_CONFIGURACIÓN DEFEPENDIENDO DEL MODO --- Cambiarlo a un R diferente
	
	; nuevos registros 
	
	.def	MIN_UNITS	= R9; Cuanta la unidades de los minutos
	.def	MIN_TENS	= R10; Cuenta las decenas de minutos
	.def	HOUR_UNITS	= R11; Cuenta la unidades de minutos
	.def	HOUR_TENS	= R12; Cuenta las decenas de minutos
	.def	VTEMP		= R23
	; estos según yo no puede hacer el compare:
	//.def  PUSHBOTTON_C	= R13 ; B3_INC
	//.def	PUSHBOTTON_D	= R14 ; B4_DECREMENTO
	//.def  PUSHBOTTON_E	= R15 ; BOTON IZQUIERDA DURANTE CONFIGURACIÓN | APAGAR ALARMA FUERA DE CONFIGURACIÓN.

	//Registro 25 en adelante ya está recervado para el puntero. que troste. 

 /****************************************/
// Configuración de mis punteros 

SETUP:
	cli; Desactivo las interrupciones.

	;PUNTERO Z (Unidades de segundo); quiero que vaya apuntando a mis valores, los de la tabla.
	LDI	ZL, LOW(TABLA << 1)
	LDI	ZH, HIGH(TABLA << 1)

	;Puntero x (Decenas de segundo); valores de la dispram
	LDI	XL, LOW(DISPRAM << 1)
	LDI	XH, HIGH(DISPRAM << 1)

	; logica de doble puntero. 

	;Almacenamos datos manualmente en RAM
	; No sé si hay una mejor manera.
	LDI	R16, 0x3F
	ST	X+, R16

	LDI	R16, 0x06
	ST	X+, R16

	LDI	R16, 0x5B
	ST	X+, R16

	LDI	R16, 0x4F
	ST	X+, R16

	LDI	R16, 0x66
	ST	X+, R16

	LDI	R16, 0x6D
	ST	X+, R16

	LDI	R16, 0x7D
	ST	X+, R16

	LDI	R16, 0x07
	ST	X+, R16

	LDI	R16, 0x7F
	ST	X+, R16

	LDI	R16, 0x67
	ST	X+, R16

	LDI	R16, 0x77
	ST	X+, R16

	LDI	R16, 0x7C
	ST	X+, R16

	LDI	R16, 0x39
	ST	X+, R16

	LDI	R16, 0x5E
	ST	X+, R16

	LDI	R16, 0x79
	ST	X+, R16

	LDI	R16, 0x71
	ST	X+, R16

	;Re-dirigimos el PUNTERO de x

	LDI		XL, LOW(DISPRAM << 1)
	LDI		XH, HIGH(DISPRAM << 1)

	/***************************************************/
	;--------------Configurar STACK---------
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	;---------Configurar de 16MHz a 1MHz------------------

	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16

	;Configuración para Trabajar a 1MHz
	LDI		R16, (1 << CLKPS2); esta es mi divisióni de 16/16
	STS		CLKPR, R16; la cargo al clk

	;--------Deshabilitar comunicación serial-------UART
	LDI		R16, 0x00
	STS		UCSR0B, R16

	/****************************************/
	//  ---Puertos- MCU--- Salidas y Entradas.

	; --------------Configuración de los Pines para el puerto D-----
	;Configurar I/O PORTS
	LDI		R16, 0x7F			;0b01111111, se activaron  casi todos menos el puntito.
	OUT		DDRD, R16			; Se les asigna a la dirección

	CLR R16					; limpio mi variable (setear a cero)
	OUT PORTD, R16				; Les mando 0 voltios para empezar. 

	;PORTB: BIN Out (PB0,1,2,3)
	LDI		R16, 0x0F
	OUT		DDRB, R16
	LDI		R16, 0x00
	OUT		PORTB, R16

	;PORTC: BIN In (PC0,1),               DISPSMUXOUT (PC2,3)
	LDI		R16, 0b00001100
	OUT		DDRC, R16
	LDI		R16, 0b00000111 ;Comenzamos encendiendo DISPUNIS
	OUT		PORTC, R16

	;Valores iniciales de registros importantes
	; los incializo con 0
	LDI		COUNT, 0
	LDI		MILLIS, 0x00
	LDI		COUNTSECS, 0x00
	LDI		COUNTDECS, 0x00

	
	LDI		VTEMP, 0b00000001
	mov		PUSHBOTTON_A, VTEMP

	LDI		VTEMP, 0b00000001
	mov		PUSHBOTTON_B,VTEMP
	;Estos son los nuevos contadores inicializados. 

	LDI		MIN_UNITS, 0x00
	LDI		MIN_TENS, 0x00
	LDI		HOUR_UNITS, 0x00
	LDI		HOUR_TENS, 0x00

	CLR VTEMP
	;Carga el primer valor de tabla (0) desde FLASH y lo muestra
	LPM		SECStemp, Z
	;COM		SECStemp			; Invierte los bits porqué es ánodo comúm
	OUT		PORTD, SECStemp
	LD		DECStemp, X
	;COM		DECStemp			; Invierte los bits
	OUT		PORTD, DECStemp

	;=====================================================
	;------Config. de TIMER0 en modo NORMAL e interrupciones
	;=====================================================
	; Mini cálculo: 1 MHz / 64 = 15625 Hz
	;Compare value: TCNT0 = 256-156.25 = 99.75 (10ms)

	;Configuración, el timer empieza a 100, el overf es a 256, etnonces:
	LDI		R16, (1 << CS01) | (1 << CS00)		;Prescaler 64; queda: 0,0,1 en 

	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, 100
	OUT		TCNT0, R16


/****************************************************/
	;-----------Habilitacin de Interrupciones en PORTC------------
	LDI		R16, (1 << PCIE1);Habilita interrupción grupo PCINT1.
	STS		PCICR, R16
	LDI		R16, 0x03;Activa PC0 y PC1
	STS		PCMSK1, R16
	//-------------------------------------------------------------

    SEI; Vuelvo a activar las interrupciones


/**************************************************/
// Loop Infinito
MAIN_LOOP:
	; Aqui puedo poner la parte de la multiplexación. La logica. Pues es el Timero el que dirá lo demás.
	;En cada segundo verificar si van 10, si llega a 10 reiniciamos el Display de(COUNTSECS) y aumentamos(COUNTDECS)
	;Si COUNTMILLIS = 100: Aumentar COUNTDECS, COUNTSECS y reiniciar COUNTMILLIS
	CPI		MILLIS, 100
	BREQ	COUNTSECS_UP
	RJMP	MAIN_LOOP

	COUNTSECS_UP:
		CLR		MILLIS; limpio los milis
		INC		COUNTSECS; ahora incremento mis segundos
		CPI		COUNTSECS, 10; lo compara en caso de que sea 1, entonces salta a la siguiente etiqueta
		BREQ	Limpiar; Si lo anterior fue igual a 1=> Limpia sin generar un incremento en D
		ADIW	Z, 1

		RJMP	MAIN_LOOP


	Limpiar:
		CLR		COUNTSECS; limpia los segundos y 
		LDI		ZL, LOW(TABLA << 1); se carga la primera parte de abajo de mi tabla al puntero
		LDI		ZH, HIGH(TABLA << 1); se carga la parte de arriba de esta. 
		
		INC		COUNTDECS
		CPI		COUNTDECS, 6; comparo si las decimas ya llegaron a 6
		BREQ	Limpiar2; si la co mparación es cierta, se salta a la etiquea de limpiar 2 para limpia las decimas
		ADIW	X, 1

		RJMP	MAIN_LOOP

	;Si ya van 60 segundos en el conteo, reiniciamos el Display del contador de decenas de segundo (COUNTSECS)...
	Limpiar2:
	
	clr		COUNTDECS
	LDI		XL, LOW(DISPRAM << 1)
	LDI 	XH, HIGH(DISPRAM << 1)

	;============================
	; INCREMENTAR MINUTOS
	;============================

	INC		MIN_UNITS
	ldi		VTEMP, 10
	CP		VTEMP, MIN_UNITS
	BRNE	MAIN_LOOP

	; Si llegó a 10 ? reset unidades minuto
	CLR		MIN_UNITS
	INC		MIN_TENS

	ldi		VTEMP, 6
	CP		VTEMP, MIN_TENS

	BRNE	MAIN_LOOP

	; Si llegó a 60 minutos ? reset minutos
	CLR		MIN_TENS

	;============================
	; INCREMENTAR HORAS
	;============================

	INC		HOUR_UNITS
	LDI		VTEMP, 10
	CP		VTEMP, HOUR_UNITS
	
	BRNE	CHECK_24H

	; Overflow 9 ? 0 y subir decena
	CLR		HOUR_UNITS
	INC		HOUR_TENS

CHECK_24H:
	; Si horas = 23 ? reset todo
	ldi		VTEMP, 2
	CP		VTEMP, HOUR_TENS
	
	BRNE	MAIN_LOOP

	LDI		VTEMP, 4
	CP		VTEMP, HOUR_UNITS
	BRNE	MAIN_LOOP

	; Si llegó a 24 ? reset total
	CLR		HOUR_TENS; se limpia horas decenas
	CLR		HOUR_UNITS; se limpia horas unidades
	;CLR	MIN_UNITS
	;CLR	MIN_TENS	
	;CLR	HOUR_UNIT
	;CLR	HOUR_TENS


	/*
		clr		COUNTDECS; se vuelkve a cero nuevamente. 
		LDI		XL, LOW(DISPRAM << 1)
		ldi 	XH, HIGH(DISPRAM << 1)
	*/
    RJMP    MAIN_LOOP
/*********************************************************/
// NON-Interrupt subroutines
;parte de incremento y decremento:

COUNTUP_SEG:
	BST		PUSHBOTTON_A, 0; en caso el boton para incrementar fue presionado 
	; bst: Bit Store from Register to T flag. Lo que hace es fuardar en la Tflag del sreg
	; Basicaente es la memoria del bit como estado anterior. 

	BRTC	RETURN_UP; Branch if T Cleared, En caso T=0
	CALL	COUNTUP; LLama a la subrutina para contar 
	LDI		PUSHBOTTON_A,	0b00000000; y ya no volverá a incrementar hasta que se vuelva a dar una interrupcióin genuina . 
	; Esto puesto que en T se copiaria el valor 0, por eso no incrementa.

	RJMP		RETURN_UP

COUNTUP:
	INC		COUNT
	SBRS	COUNT, 4 ;Skip if Bit in Register Set, Si el bit 4 de COUNT = 1 , entonces no se salta
	CLR		COUNT
	OUT		PORTB, COUNT
	RET	

COUNTDWN_SEG:
	bst		PUSHBOTTON_B, 0
	BRTC	RETURN_DWN
	call	COUNTDWN
	ldi		PUSHBOTTON_B,	0b00000000
	rjmp	RETURN_DWN

COUNTDWN:
	DEC		COUNT
	SBRS	COUNT, 7
	ldi		COUNT, 0x0F
	out		PORTB, COUNT
	ret

/******************************************************/

;==========================================
; Parte del Lab
;===========================================
RESET_TOGGLE:		
	;Rutina para reiniciar Timer0 luego de 10ms...
	;y para "togglear" qu  display se muestra (Unidades de segundo o decenas de segundo)
	;Reiniciamos TIMER0 e incrementamos COUNTMILLIS

	INC		MILLIS
	LDI		R16, 100
	OUT		TCNT0, R16
	SBI		PINC, 2		;Toggleamos el bit del transistor de DISPUNIS
	SBI		PINC, 3		;Toggleamos el bit del transistor de DISPDECS
	;Si el bit del transistor DISPUNIS est  encendido up DISPUNIS en PORTD y si está apagado en PORTD
	SBIS	PORTC, 2
	RJMP	COUNTDECS_SET
	LPM		SECStemp, Z
	OUT		PORTD, SECStemp

	TIMER_RETURN:
	RETI

	COUNTDECS_SET:
		LD		DECStemp, X
		OUT		PORTD, DECStemp
		RJMP	TIMER_RETURN


ISR_PCINT1:
	SEI		; Habilitamos interrupciones anidadas

	;Reviso cambio en COUNTUP_BUTTON, si fue presionado, ver estado anterior, si todo bien incrementar el contador 
	;Si no fue presionado, su estado será no presionado y revisamos COUNTDWN_BUTTON

	SBIS		PINC, 1
	RJMP		COUNTUP_SEG
	LDI			PUSHBOTTON_B, 0b00000001

	;Si countDWN_BUTTON se encuentra presionado, nos vamos a revisar su estado anterior para verificar si es correcto decrementar el valor de COUNT
	; si el bot n NO se encuentra presionado, regresamos al main

	RETURN_UP:
		SBIS		PINC, 0
		RJMP		COUNTDWN_SEG
		LDI			PUSHBOTTON_B, 0b00000001
	RETURN_DWN:
		RETI
	