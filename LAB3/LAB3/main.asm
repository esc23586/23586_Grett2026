/*
* PRELAB3.asm
*
* Creado: 17 de feb 
* Autor : Grettel Escobedo 23586
* Descripción: Implemente un contador binario de 4 bits, con lógica on-change y pullups internos.

*Parte del laboratorio: Implementar un contador en hexa de 4 bits utilizando una interrupción del TMR0. 
*La interrupción del TMR0 deberá ser entre 5 y 20ms, pero el contador deberá cambiar cada 1000ms. 
*Muestre el contador con el TMR0 en un display de 7 segmentos, de manera que se muestre el conteo en segundos.
*Se espera que la vuelta del overflow sea. De esta manera se dara una cada segundo.

; Según la logica del prescaler que utilizo, en teoria da 61 overflows de hecho
; Utilicé lógica de 2 punteros, pq me odio mucho
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)
.dseg
DISPRAM:
	.BYTE 16; de esta manera reservo los 16
.cseg
.org 0x0000; Se incia aqui para guardar.

	rjmp SETUP

.org PCI1addr;Pueba, luego cambiar a un nombre más significativo;
	rjmp ISR_PCINT1; mi ubicación al saltar en la etiqueta. 

; Parte del Laboratorio:
/*
.org 0x001A      ; Dirección TIMER0_OVF según el datasheet
	rjmp ISR_TIMER0
*/

;Guardamos un salto a la sub-rutina "RESET_TOGGLE"
.org  OVF0addr
	RJMP RESET_TOGGLE

.org 0x0022
 /****************************************/
 ;========================================================
; Tablita para los valores del display
;========================================================
; revisar si rompe el códgio. ojalá no.

	Table7seg:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
		
;========================
; Registros
;========================

	.def	MILLIS		= R19
	.def	COUNTDECS	= R18
	.def	COUNTSECS	= R20
	.def	SECStemp	= R21
	.def	DECStemp	= R25
	.def	COUNT		= R22
	.def	PUSHBOTTON_A	= R23
	.def	PUSHBOTTON_B	= R24

 /****************************************/
// Configuración de la pila
SETUP:
	cli; Desactivo las interrupciones.

	;PUNTERO Z (Unidades de segundo); quiero que vaya apuntando a mis valores
	LDI	ZL, LOW(TABLA << 1)
	LDI	ZH, HIGH(TABLA << 1)

	;Puntero x (Decenas de segundo)
	LDI	XL, LOW(DISPRAM << 1)
	LDI	XH, HIGH(DISPRAM << 1)



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

	LDI		R16, (1 << CLKPS2)
	STS		CLKPR, R16

	;--------Deshabilitar comunicación serial-------UART
	LDI		R16, 0x00
	STS		UCSR0B, R16

	; --------------Configuración de los Pines para el puerto D-----
	;Configurar I/O PORTS
	LDI		R16, 0x7F			;0b01111111, se activaron  casi todos menos el puntito.
	OUT		DDRD, R16			; Se les asigna a la dirección

	CLR R16					; limpio mi variable (setear a cero)
	OUT PORTD, R16				; Les mando 0 voltios para empezar. 

	/****************************************/
//  ---Puertos- MCU--- Salidas y Entradas.

	;PORTB: BIN Out (PB0,1,2,3)
	LDI		R16, 0x0F
	OUT		DDRB, R16
	LDI		R16, 0x00
	OUT		PORTB, R16

	;PORTC: BIN In (PC0,1), DISPSMUXOUT (PC2,3)
	LDI		R16, 0b00001100
	OUT		DDRC, R16
	LDI		R16, 0b00000111 ;Comenzamos encendiendo DISPUNIS
	OUT		PORTC, R16

	;Valores iniciales de registros importantes
	LDI		COUNT, 0
	LDI		MILLIS, 0x00
	LDI		COUNTSECS, 0x00
	LDI		COUNTDECS, 0x00
	LDI		PUSHBOTTON_A, 0b00000001
	LDI		PUSHBOTTON_B, 0b00000001
	LPM		SECStemp, Z
	;COM		SECStemp  ; Invierte los bits porqué es ánodo comúm
	OUT		PORTD, SECStemp
	LD		DECStemp, X
	;COM		DECStemp  ; Invierte los bits
	OUT		PORTD, DECStemp


	;Config. de TIMER0 en modo NORMAL e interrupciones
	; Mini cálculo: 
	;Compare value: TCNT0 = 256-156.25 = 99.75 (10ms)

	LDI		R16, (1 << CS01) | (1 << CS00)		;Prescaler 64

	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, 100
	OUT		TCNT0, R16

	;-----------Habilitacin de Interrupciones en PORTC------------
	LDI		R16, (1 << PCIE1)
	STS		PCICR, R16
	LDI		R16, 0x03
	STS		PCMSK1, R16
	//-------------------------------------------------------------

    SEI; Vuelvo a activar las interrupciones


/**************************************************/
// Loop Infinito
MAIN_LOOP:
	; Aqui puedo poner la parte de la multiplexación. La logica. Pues es el Timero el que dirá lo demás.
	;En cada segundo verificar si van 10, si llega a 10 reiniciamos el Display de(COUNTSECS) y aumentamos(COUNTDECS)
	COUNTSECS_UP:
		CLR		MILLIS; limpio los milis
		INC		COUNTSECS; ahora incremento mis segundos
		CPI		COUNTSECS, 10; lo compara en caso de que sea 1, entonces salta a la siguiente etiqueta
		BREQ	Limpiar; Si lo anterior fue igual a 1=> Limpia sin generar un incremento en D
		ADIW	Z, 1

		RJMP	LOOP


	Limpiar:
		CLR		COUNTSECS; limpia los segundos y 
		LDI		ZL, LOW(TABLA << 1); se carga la primera parte de abajo de mi tabla al puntero
		LDI		ZH, HIGH(TABLA << 1); se carga la parte de arriba de esta. 
		
		INC		COUNTDECS
		CPI		COUNTDECS, 6; comparo si las decimas ya llegaron a 6
		BREQ	Limpiar2; si la co mparación es cierta, se salta a la etiquea de limpiar 2 para limpia las decimas
		ADIW	X, 1

		RJMP	LOOP

	;Si ya van 60 segundos en el conteo, reiniciamos el Display del contador de decenas de segundo (COUNTSECS)...
	Limpiar2:
		clr		COUNTDECS; se vuelkve a cero nuevamente. 
		LDI		XL, LOW(DISPRAM << 1)
		ldi 	XH, HIGH(DISPRAM << 1)

    RJMP    MAIN_LOOP
/*********************************************************/
// NON-Interrupt subroutines


/******************************************************/

// Interrupt routines:
;========================
; ISR Del prelab
;========================
ISR_PCINT1:

    in temp, PINC

;----- Botón PC0 (Incrementar) -----
    sbrs temp, 0      ; Si bit 0 = 1 lo salta
    rcall ANTIRREBOTE_INC

;----- Botón PC1 (Decrementar) -----
    sbrs temp, 1
    rcall ANTIRREBOTE_DEC

    reti

;==========================================
; ISR_TIMER0- Del LAB
;===========================================
ISR_TIMER0:

    inc TimerCount;  Incremento mi contador
	;---16,000,000 / 1024 = 15625 Hz
	;15625 / 256 ? 61

    cpi TimerCount, 61; Compare with Immediate. En caso sean iguales. digase 1, entonces salta a la siguiente etiqueta.
    brne TIMER_EXIT

    clr TimerCount; Limpio el contador.

    ; Incrementar contador principal
    inc ContadorLED
    cpi ContadorLED, 16; Cuando sea 16 => da a 1. Salta a la siguente. 

    brlo CONTINUE_TIMER
    clr ContadorLED; Limpio mi contador.

CONTINUE_TIMER:
    rcall CONVERTIR_BCD; 

TIMER_EXIT:
	reti
	

/****************************************/