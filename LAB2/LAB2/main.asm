/*
* LAB2.asm
*
* Creado: 10 de febrero 2026
* Autor : Grettel Escobedo 23586
* Descripción: Parte 2, del prelab con el laboratorio 2.
Se busca agregar un display de 7 segmentos y que este vaya contando con underflow y overflow. con el contador de los botones pc0 y pc1.
Aparte se busca mantener el funcionamiento del contador de los leds con ayuda del timer. 

*Mayores explicaciones:
Se busca agregar con el puntero z, que vaya buscando los valores de la tabla y que saque estos reflejados en el port D (donde está el display)
Se hara caso omiso de D7, osea D7. por ello será 0b01111111.
* En el post lab se busca el funcionamiento del prelab con el post lab
*/
/****************************************/

// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)
.cseg
/****************************************/


// Configuracion MCU
;========================
; Registros
;========================
.def ContadorLED   = r16
.def Contador7seg  = r20
.def Temp          = r17
.def D1            = r18
.def D2            = r19



.org 0x0000
 rjmp START
;========================

 /****************************************/
// Configuración de la pila

START:
;---- Stack ----
    ldi Temp, LOW(RAMEND)
    out SPL, Temp
    ldi Temp, HIGH(RAMEND)
    out SPH, Temp

;========================================================
; Tablita para los valores del display
;========================================================
; revisar si no me afecta el que no utilizaré letras
	Table7seg:	
		.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;============================================================
; ---Puertos- MCU--- Salidas y Entradas.
;==========================================================


;CONTADOR (PreLAB):
; Se establece como salidas puerto B salidas (LEDs)
    ldi Temp, 0b00001111
    out DDRB, Temp

; Apagar LEDs AL iniciar con el código 
    clr Temp
    out PORTB, Temp

; INC/DEC (LAB2):
; ---------PC0 y PC1 entradas con pull-up-----
; Lo hago de esta forma porque es más rapido, además me trajo complicaciones con la asignación de binario.

    cbi DDRC, PC0				; clear bit, voy a la dirección y le digo que es 0
    cbi DDRC, PC1
	; se activan los pullup
    sbi PORTC, PC0				; le asigno 1, para que se active
    sbi PORTC, PC1

; --------------Configuración de los Pines para el puerto D-----
	LDi Temp, 0xFF				;0b11111111, se activaron todos, debido a que se usará el utlimo para la alarma.
	OUT DDRD, Temp				; Se les asigna a la dirección
	CLR Temp					; limpio mi variable (setear a cero)
	OUT PORTD,Temp				; Les mando 0 voltios para empezar. 



;------------Esta es la desactivación de UART------------------
;Para la parte de desactivación para la comunicación de RX Y TX 
	LDI Temp,  0x00
	STS UCSR0B, Temp



;========================
; Timer0 : Esta es la parte del binario.
;========================
; Modo normal, prescaler = 64

    ldi Temp, (1<<CS01)|(1<<CS00)
    out TCCR0B, Temp

    clr D1						; contador de cuantos overflows van ocurriendo. 


;========================
; Inicialización para mis contadores, aqui se muestra que está en clr
;========================
    clr Contador7seg
	clr ContadorLED

    rcall MOSTRAR
;-----------------Me aseguro que r1 siempre sea 0 para la subrutina de MOSTRAR---------
	clr r1

/*********************************************************/
// Loop Infinito
MAIN_LOOP:

;========= BOTÓN INC =========
    sbic PINC, PC0				; si no esta presionado--- salta a la siguiente
    rjmp CHECK_DEC				; En caso no esta presionado dec, entonces salta

    rcall DELAY_REBOTE			; mi antirrebote

    inc Contador7seg				; se  incrementa
	; se busca que cuabndo este llegue a 16 este regrese a cero
    cpi Contador7seg, 16
    brlo INC_OK					; si es menor que 16 salta a mostrar el incremento
    clr Contador7seg				; overflow
INC_OK:
    rcall MOSTRAR; este es el reflejo en mi contador

WAIT_INC: ; aqui meramente solo espero a que se deje de presionar el botón para volver a leer.
    sbis PINC, PC0
    rjmp WAIT_INC
    rcall DELAY_REBOTE
    rjmp MAIN_LOOP

;========= BOTÓN DEC =========
; Misma logica que siempreee :D
CHECK_DEC:
    sbic PINC, PC1
    rjmp TIMER_CHECK			; si no fue preisonado; salto a etiqueta.

    rcall DELAY_REBOTE			; en caso sí fue presionado

    tst Contador7seg				;Stores one byte from a Register to the data space
    brne DEC_OK					
    ldi Contador7seg, 15			 ; underflow
    rjmp DEC_DONE				;
DEC_OK:
    dec Contador7seg
DEC_DONE:
    rcall MOSTRAR

WAIT_DEC:
    sbis PINC, PC1
    rjmp WAIT_DEC
    rcall DELAY_REBOTE
    rjmp MAIN_LOOP


/****************************************/
// NON-Interrupt subroutines

;========= TIMER0 =========
TIMER_CHECK:
    in Temp, TIFR0 ; revisa si ocurrio over, sino este sigue de largo
    sbrs Temp, TOV0
    rjmp MAIN_LOOP

    ; limpiar flag overflow
    ldi Temp, (1<<TOV0)
    out TIFR0, Temp

    inc D1
						;Esto era del lab: cpi D1, 98
	cpi D1, 10			; ahora cuenta 10 bloques de 100ms = 1s
    brlo MAIN_LOOP		; si es menor salta

    clr D1				; En teoria ya paso 1 segundo, al ser 1000ms
    inc ContadorLED
    cpi ContadorLED, 16

	/* ESTA ERA PARTE DEL LAB:
    brlo TIMER_OK
    clr ContadorLED				  ; overflow
TIMER_OK:
    rcall MOSTRAR
    rjmp MAIN_LOOP
	*/

	brlo NO_OVERFLOW
	clr ContadorLED

NO_OVERFLOW:

	; ==============================
	; --- SECCIÓN DE ALARMA ---
	; ==============================

	; Si display está en 0 ? no hay alarma
	tst Contador7seg
	breq ALARMA_OFF

	; Comparar contadores
	cp ContadorLED, Contador7seg
	brne ALARMA_OFF

	; === SON IGUALES ===
	clr D1						; reinicia mi contador base
	clr D2						; si estás usando segundos acumulados
	sbi PORTD, 7				; enciende PD7 (donde tengo mi buzzer jsjs)
	rjmp FIN_ALARMA

	ALARMA_OFF:
	cbi PORTD, 7        ; apaga PD7

	FIN_ALARMA:

	rcall MOSTRAR
	rjmp MAIN_LOOP

/****************************************/
// -------Interrupt routines-----

/*MOSTRAR:
    mov Temp, Contador
    andi Temp, 0x0F
    out PORTB, Temp
    ret
	
MOSTRAR:; 
    ; ---- LEDs ---- Ver si no da problemas
    mov Temp, ContadorLED
    andi Temp, 0x0F				 ; Revisar si la tabla sigue siendo la correcta, 
    out PORTB, Temp

    ; ---- Display 7 segmentos ----
    ldi ZH, HIGH(Table7seg<<1)
    ldi ZL, LOW(Table7seg<<1)
    add ZL, Temp
    adc ZH, r1        ; r1 = 0
    lpm Temp, Z
    out PORTD, Temp; se muestra en el puerto D. 
    ret
	*/

MOSTRAR:

    ; ---- LEDs (PORTB) ----
    mov Temp, ContadorLED
    andi Temp, 0x0F
    out PORTB, Temp

    ; ---- 7 segmentos (PORTD) ----
    mov Temp, Contador7seg
    andi Temp, 0x0F

    ldi ZH, HIGH(Table7seg<<1)
    ldi ZL, LOW(Table7seg<<1)
    add ZL, Temp
    adc ZH, r1
    lpm Temp, Z
    out PORTD, Temp

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

/****************************************/
