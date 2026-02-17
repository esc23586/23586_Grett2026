
; ClaseInterrupciones.asm
/*
* Creado: 
* Autor : PEDROO
* Descripción: 
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)


.cseg
.org 0x0000
	JMP START
.org PCI2addr ;En esta localidad, ponme la siguiente instrucción
	JMP ISR_PCINT2; Esta instrución

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

	//cONFIGURAR ISR_PCINT2-------------------------------------------------------------
	LDI R16, (1<<PCIE2)
	STS PCICR, R16
	LDI R16, (1<<PCINT18); PCINT18 ES LA VARIABEL 2 PARA EL PUERTO B.
	OUT PCMSK2, R16 ; HABILITAMOS EL PD2

	SEI
/****************************************/
// Loop Infinito
MAIN_LOOP:

    RJMP    MAIN_LOOP
/****************************************/
// NON-Interrupt subroutines
/****************************************/
// Interrupt routines
 ISR_PCINT2:
 ; pq dejamos esto habilitado ? push: 
 ;pop: 
	PUSH R16 ; sTORE CONTENTS OF R16 IN STACK, basicamtne me guarda la cuenta que ya llevo en r16, a la pila, 20 digamos
	IN	R16, SREG; r16 ahora tiene los bits encendidos en el status register ANTES DE ENTRAR A LA INSTRUCCIÓN
	PUSH R16; store content of r16 in stack
	
	; PARA VERIFICAR SI EL BOTON ESTA PRECIONADO : Esto solo espara un botón. 
	; si quiciera cambiar si fue soltado es con sbic. //pd: aqui no hay logica inversa pq hay pull up fisico.
	SBIS PIND, PIND2
	SBI PINB, PB5; TOGGLE PB5
	SBIS PIND, PIND2
	SBI PINB, PB0

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