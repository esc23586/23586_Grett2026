/*
* NombreProgra.asm
*
* Creado: 
* Autor :Pedro xd
* Descripción: 
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.equ TIM
.equ MAX_MODES = 3
.def MODE = R20
.def COUNTER = R21
.def ACTION = R22

.cseg
.org 0x0000
;-----------------------------------------
.ORG 
	JMP ISR_Timer1
.ORG PCIN2addr
	JMP ; vector, puerto D pinchange 2 

.org OVFR1
	jmp; primero poner lo delos botones, luego reloj, orden ascendente creo.

START: 
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
;PD2 Y PD3, Botones
; LEDS EN PB0 Y 1 
;LEDS AMARILLOS EN PC0,1,2,3

SETUP:
    CLI 
	/*****************************/
	;CONFIGURAR PRESCALER A  1MHz
	ldi 
	sts 
	ldi 
	sts
//Configurar entradas y salidas. 
; Configuración del puerto B
	sbi		DDRB, 
	SBI 
	CBI PORTB, 
; Configuración del puerto C
	sbi 
	sbi 
	cbi
//Configuración de entradas, con pullup habilitado. 
	CBI
	CBI
	SBI 
	SBI 
//Configurar el TIMER------------------

SBI 
CALL intl_tNQ 
//
//TIMER1
; MASCARA, HABILITAR EL T1E1
LDI r16, (1<<TOTE1)
//INICIALIZAR VARIABLES O REGISTROS 
CLR MODE 
CLR COUNTER 
CLR ACTION
; Contar con tiempo
; Hay que habilitar interrupciones de botón. 
// Int_botones
ldi  
sts 
;Pinchange- mascara 2, encender banderas 18 y 19( estos serán lo sunicos que pueden interrumpir)
ldi	
sts	
ldi	
sts	

SEI
/****************************************/
// Loop Infinito
MAIN_LOOP:
out portc, counter
out portb, mode
CPI 
BREQ
; VERIFICA en qué modo estoy, contar según si se apachó el boton. 

inc_mode:
;comparo si acción es 
	cpi 
	brne 
	inc COUNTER
	andi counter, 0x0F;mascara

    RJMP    MAIN_LOOP

dec_mode
; si esta en el mo do 2 y 3, entonces, se incrementa automaticamente. 
; limpiar la bander, siempre, sin ocontara muy rapido, eso puede dar el aspecto de que está contando muy rapido. 
; aqui se porbo que funcionara bien independientemente del modo, en este caso cuenta par amodo 2 y 3. 





/****************************************/
// NON-Interrupt subroutines
int_timer1:
ldi R16, 
sts TCINT1
Ldi R16, (1<<CSI0)|(1<<CSS0)
STS  
ldi 
sts 
; EL QUE LLEVA EL CONTEO EL STNT
ret
/****************************************/
// Interrupt routines
; SETUP PRINCIPAL, NO POR CALLS
PIN_ISR:; leeme el pind, especificamente el pd2, slata si esta bajo, apachado. Si es cero, se salta la linea. 
; si si está apachado, inc mode.
	push 
	in 
	push
	sbic pinb, pinb2
	rjmp exit pind,

	inc mode
	; compara con el nuemro maximo de modos, si son iguales se reinicia
	cpi 
	brne CONTINUAR 
	CLR MODE ;SI SI SON IGUALES ME LO REGRESA A CERO
CONTINUAR:
CPI MODE,0 
BREQ INCMODE_ISR
CPI MODE, 2
BREQ autoinc_mode_ISR
RJMP EXIT: INB_IRS

 INCMODE_ISR:
 RJMP WIT:PIIN
 ; SALTA A LA SALIDA DESPUES DE REVISAR. 

 ; Jess, va muy rapido.  max mode lo cambio a 4. par que despues del dos no lo baje a cero de un solo despues del 2. 

	exit pind:

	pop
	out
	pop 

	RETI

TMR1_ISR:; tiene que reiniciar, ahi. Para que vaya contando. 
	INC COUNTER 
	ANDI COUNER, 0X0f
	LDI R16, 
	STS t
	ldi 
	sts
	 

	RETI

EXTI_TIN_ISR
 POP
 OUT 
 POP
RETI
/****************************************/