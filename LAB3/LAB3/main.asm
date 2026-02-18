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
/*
	.def ContadorLED   = r16
	.def Temp          = r17
	.def D1            = r18
	.def D2            = r19
	;Parte del  Lab y Post:

	.def TimerCount = r20
	.def BCD_Unidad = r21
	.def BCD_Decena = r22
	*/
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




/****************************************/
//  ---Puertos- MCU--- Salidas y Entradas.

;CONTADOR (PreLAB):
; Se establece como salidas puerto B salidas (LEDs)
    ldi Temp, 0b00001111; 0x0F
    out DDRB, Temp

; Apagar LEDs AL iniciar con el código 
    clr Temp
    out PORTB, Temp


; ---------PC0 y PC1 entradas con pull-up-----
; Lo hago de esta forma porque es más rapido, además me trajo complicaciones con la asignación de binario.

    cbi DDRC, PC0				; clear bit, voy a la dirección y le digo que es 0
    cbi DDRC, PC1
	; Se activan los pullup
    sbi PORTC, PC0				; le asigno 1, para que se active
    sbi PORTC, PC1

;--------------------------------
; Habilitar Pin Change Interrupt
;--------------------------------
    ldi temp, (1<<PCIE1)
    sts PCICR, temp

    ldi temp, (1<<PCINT8)|(1<<PCINT9)
    sts PCMSK1, temp

; --------------Configuración de los Pines para el puerto D-----
	LDi Temp, 0x7F				;0b01111111, se activaron  casi todos menos el puntito. 
	OUT DDRD, Temp				; Se les asigna a la dirección
	; Setear a cero para empezar
	CLR Temp					; limpio mi variable (setear a cero)
	OUT PORTD,Temp				; Les mando 0 voltios para empezar. 

;-------------------------
; Timer0: Para el conteo.
;-----------------------
	ldi Temp, 0
    out TCCR0A, Temp        ; Modo normal

    ldi Temp, (1<<CS02)|(1<<CS00)   ; Prescaler 1024 aproximadamente. 
	; Esta parte solo es para probar la lógica.
    out TCCR0B, Temp

	ldi Temp, 100           ; Precarga para ~10ms
    out TCNT0, Temp

    ldi Temp, (1<<TOIE0)            ; Habilitar overflow
    sts TIMSK0, Temp

    clr TimerCount


;--------------------------------
; Inicializar contador
;--------------------------------
    clr ContadorLED
    out PORTB, ContadorLED

	/*clr TimerCount
	out PORTD, TimerCount; verificar si da el reflejo al iniciar el programa.

	clr BCD_Unidad
	clr BCD_Decena
*/
    SEI; Vuelvo a activar las interrupciones


/**************************************************/
// Loop Infinito
MAIN_LOOP:
	; Aqui puedo poner la parte de la multiplexación. La logica. Pues es el Timero el que dirá lo demás.

	; Mostrar unidades
    mov Temp, BCD_Unidad
    out PORTD, Temp
							; activar display unidades
							; (ejemplo: sbi PORTB, 4)
    rcall DELAY_REBOTE		; Mi delay

    ; Mostrar decenas
    mov Temp, BCD_Decena
    out PORTD, Temp
							; activar display decenas
							; (ejemplo: sbi PORTB, 5)
    rcall DELAY_REBOTE		; Mi delay

    RJMP    MAIN_LOOP
/*********************************************************/
// NON-Interrupt subroutines

;--------------------------
 ; CONVERTIR_BCD
;---------------------------
; Se busca	que en el momento en el que llega a 10 comprueba y en ese momento las unidades tiene que pasar a cero
CONVERTIR_BCD:

    mov Temp, ContadorLED; 
    clr BCD_Decena		; Se limpia mis mini contadores.
    clr BCD_Unidad		; Limpieza mi ni contadores.

    cpi Temp, 10		; Compara si llego a 10
    brlo SOLO_UNIDAD	;	Entonces al comparar si es menor salta a la etiqueta. EN el momento que sea mayor Continua

    ldi BCD_Decena, 1	; Se carga 1 a la parte de las decentas, que hasta ahroa era cer.
    subi Temp, 10		; Se hace la Subtract Immediate

SOLO_UNIDAD:
    mov BCD_Unidad, Temp ;

    ret

;--------------------------
;   ANTIRREBOTE_INC
;-----------------------------
ANTIRREBOTE_INC:
    rcall DELAY_REBOTE      ; Esperar a que pase el rebote

    in temp, PINC           ; Leer otra vez el pin
    sbrs temp, 0            ; Si sigue en 0 ? botón realmente presionado
    rcall INCREMENTAR

    ret
;------------------------------
;   ANTIRREBOTE_DEC
;------------------------------

ANTIRREBOTE_DEC:
    rcall DELAY_REBOTE

    in temp, PINC
    sbrs temp, 1
    rcall DECREMENTAR

    ret

;========================
; INCREMENTAR
;========================
INCREMENTAR:
    inc ContadorLED
    andi ContadorLED, 0x0F   ; Limitar a 4 bits
    out PORTB, ContadorLED
    ret

;========================
; DECREMENTAR
;========================
DECREMENTAR:
    dec ContadorLED
    andi ContadorLED, 0x0F
    out PORTB, ContadorLED
    ret

;==============================
; SUBRUTINA ANTIRREBOTE:
;==============================
DELAY_REBOTE:
    ldi D1, 100
DLY1:
    ldi D2, 100
DLY2:
    dec D2
    brne DLY2
    dec D1
    brne DLY1
    ret


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