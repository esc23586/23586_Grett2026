;
; ClaseInterrupciones.asm
/*
* Creado: 
* Autor : 
* Descripción: 
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)


.cseg
.org 0x0000
	JMP START
.org INT0addr ;En esta localidad, ponme la siguiente instrucción
	JMP ISR_INT0; Esta instrución

.org 

; Las primeras 26 son instrcciones. Primero cambiamos los org. 
;NOTESE que los datos se guardan en las direcicoines. Todo tiene que tener su orden. el jmp start indica,
; dónde empieza el código, basicamente donde lo encontre. 
; Por eso hay que ponerlo en orden para caerle encima.

 /****************************************/
// Configuración de la pila
START:
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
	CLI
//COnfiguración del clck prescaler
    LDI  R16,(1<< CLKPCE)
	STS CLKPR, R16 //ENABLE PRESCALER
	LDI R16, (1<<CLKPS2) ;0B000000100
	STS CLKPR, R16

	// CONFIGURAR ENTRADAS Y SALIDAS
	CBI DDRD, DDD2
	SBI PORTD, PORTD2; AQUI LA HABILITÉ 
	sbi DDRB, DDB0
	sbi DDRB , DDB5
	; ALT SHIFT
	CBI PORTB, PORTB0
	CBI PORTB, PORTB5

	; SI YO QUICIERA QUE FUERA FLANCO DE SUBIDA. PARA PONER LOS DOS BITS EN 1

	//cONFIGURAR INT0--------------------------------------------------------------
	LDI R16, (1<<ISC01) | (1<<SC00) ;0B0000011 -- se busca en el extgernar interrupt para los nombres, bit0, bit 1, etc
	; bASCIAMENTE AL NUMERO QUE TENGO EN LA ETIQUETA DLE BIT ISC01 LO QUIERRO CORRER 1. ESTO CON EL (1<<1), ANTES: 0001, AHORAA: 0010
	; OJO LA ETIQUETA, DEL ISC ES LA CANTIDAD DE MOVIMIENTOS QUE PUEDE TENER. 
	;bASICAMENTE SE PUEDE HACER UN OR DE EMBOS, basicamente se encuenten los dos bits al mismo tiempo

	; si quiereo que sea al soltar se quita el segundo y el primero se deja 
	; si quiero que sea pinchange, se hace LDI R16, (1<<ISC00)

	STS EICRA, R16; DEBO USAR STS
	;pd: si es 0b0000001 - 7 bits, la notación formal. 


	; pUSE 11 Y LA MASCARA, PARA ABILITAR, 01
	LDI R16, (1<<INTT0)
	OUT EIMSK, R16 ; HABILITAMOS EL PD2

	SEI
/****************************************/
// Loop Infinito
MAIN_LOOP:

	inc r16
	cpi r16, 50
	brne main_loop
	sbi

    RJMP    MAIN_LOOP
/****************************************/
// NON-Interrupt subroutines
/****************************************/
// Interrupt routines
 ISR_INT0:
 ; pq dejamos esto habilitado ? push: 
 ;pop: 
	PUSH R16 ; sTORE CONTENTS OF R16 IN STACK, basicamtne me guarda la cuenta que ya llevo en r16, a la pila, 20 digamos
	IN	R16, SREG; r16 ahora tiene los bits encendidos en el status register ANTES DE ENTRAR A LA INSTRUCCIÓN
	PUSH R16; 

	LDI R16, 100; AHORA TIENE 100 MI VARIABLE
	OUT TCNT0, R16

	 SBI PINB, PINB0; TOGGLE PB5
	 SBI PINB, PINB5

	 POP R16; ES EL STATUS REGISTER ANTES DE LA INTERRUUIPCIÓN Y LO SACA DE LA PILA
	 OUT SREG, R16; SE LE CARGA A SREG SU ESTADO ANTERIOR, GRACIAS A R16
	 POP R16 ; //GER CONTENT FROM STACK AND STORE, INTO R16. Basicmaente si tengo un contador
	 ; esto evita que mi contador despues cambie su contenido al regresar de la interrupicón 

	 RETI ; cUANDO SE APACHA NO PASA NADA, CUANDO SE SUELTA SI PASA.

/****************************************/
; tools options, tooll, toollsides
; mask de true a false, para poder debuggear.

/*ORDEN DE COMO USAR PUSH
PUSH  R16
PUSH R17
PUSH R18

POP R18
POP R17
POP R16


*/