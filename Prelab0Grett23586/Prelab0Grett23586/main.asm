;
; Prelab0Grett23586.asm
;
; Created: 20/01/2026 12:31:47
; Author : grett
; Carne: 23586
;


;creación de un código que pueda hacer que un led parpadee según ciertos intervalos.
;En este caso se intetará hacer que vaya decrementando hace ser cero. Por ello, cuando termine de quitar en cada ciclo hasta que llegue a cero.
;Cuando llegué a cero, entonces se activa la bandera del bit 1 de register. 

.include "M328PDEF.inc"
.org 0x00

;CLC ; Para esta parte es bueno desconectar las interrupciones, de esta manera va un poco más rápido par cargar esta información.
; Una vez cargado, entonces, ya puede empezar a habilitarse las interrupciones. 



;---------------------------------------------
;.def Perder_Tiempo = R16 //se definio la función donde estará el contador, esta es una forma sana para el nano para que pueda seguir trabajando y pasar el tiempo. 
:.def Contador = R17 //En este caso, lo que se busca es ya sea incrmentar a overflow o decrementar a cero. 
; r18 será mi led (Aclaración)
;---------------------------------------------
 

;CLC desactivar interrupciones
rjmp Start//Este lo podría borrar, pues va consecutivo


Start:

    LDI R18, Low (RAMEND)
	OUT SPL, R18
	LDI R18, HIGH (RAMEND)
	OUT SPL, R18
	
	
	 
    sbi DDRB, PB0 ; PB0 como salida (D8 según la guia de mi arduino chafa :3 )
    cbi PORTB, PB0; LED apagado Al inico del código

    ; Inicializar contador
    clr R17; limpio el contador actualmente antes de iniciar, por si las moscas
	LDI R17, 0X10 ;Setear a 16 en hexa en este caso, es el bit 5 sino mal recuerdo.// pereguntar



	LOOP: ;el loop para encender y apagar. --------------------------------------------

	;Encender el led
	 ldi R18, (1<<PB0)
	 Out DDRB, R18

	 ldi R18, (1<<PB0)
	 OUT PORTB, R18

	rcall Perder_Tiempo ; salto, y regresa a esta linea
	; Apagar el led
	ldi R18, (1<<PB0)
	Out DDRB, R18

	ldi R18, 0x00
	OUT PORTB, R18


	rcall Perder_Tiempo
	RJMP LOOP ;preguntar si es rjmp o solo jump.-----------------------------------------



	; Sub rutinas------------------
	
	 Perder_Tiempo: 
	dec R17;  En este caso hacemos el decremento
	brne Perder_Tiempo
	ret
