;
; Prelab0Grett23586.asm
;
; Created: 20/01/2026 12:31:47
; Author : grett
; Carne: 23586
;


;creación de un código que pueda hacer que un led parpadee según ciertos intervalos.
;En este caso se intetará hacer que vaya decrementando hasta cero.
;Cuando llegué a cero,  se activa la bandera del bit 1 de register, la bandera cero y se usa BRNE para ejecutar acciones.

.include "M328PDEF.inc"
.org 0x00

;CLC ; Para esta parte es bueno desconectar las interrupciones, de esta manera va un poco más rápido par cargar esta información.
; Una vez cargado, entonces, ya puede empezar a habilitarse las interrupciones. (C cancela este plan debido a que no es es con Timesk0)



;---------------------------------------------
;Se utilizar R16 para el pointer
;---------------------------------------------
 

;CLC desactivar interrupciones
rjmp Start;Este lo podría borrar, pues va consecutivo


Start:

    LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16
	
	
	 
    SBI DDRB, PB0 ; PB0 como salida (D8 según la guia de mi arduino chafa :3 )
    CBI PORTB, PB0; LED apagado Al inico del código.Clear Bit in I/O Register

    ; Inicializar contador
    ;clr R17; limpio el contador actualmente antes de iniciar, por si las moscas, esto esta bien
	;LDI R17, 0X10 ;Setear a 16 en hexa en este caso, es el bit 5 sino mal recuerdo
	; El ldi, also está bien pero se cambió para que fuera visible por el ojo humano



	LOOP: ;el loop para encender y apagar. --------------------------------------------

	;Encender el led
	 SBI PORTB, PB0 ; LED LUZ para mi puerto b, específicamente pb0, Set Bit in I/O Register
	 RCALL PerderTiempo ; salto, y regresa a esta linea

	; Apagar el led
	CBI PORTB, PB0  ;clear Bit in I/O Register

	RCALL PerderTiempo
	RJMP LOOP ;Regresa al loop eternamente 



	; Sub rutinas------------------
	
	;-----------------------------
	;  Prueba con ciclos anidados
	;-----------------------------
	PerderTiempo:
		LDI R17, 100	; Primero se le carga 100 al registro R17

	Delay_ext:
		LDI R18, 250	; EL Delay que engloba al interior, empieza por encender todos los bits a R18 too
	Delay_2:
		LDI R19, 250

	Delay_int:
		DEC R19		; Se decrementa el registro R19

	

		BRNE Delay_int; Cuando R18 llega a cero, entonces salta nuevamene al ciclo interno Y decrecementa R18. 
		DEC R18
		BRNE Delay_2;
		DEC R17
		BRNE Delay_ext; Cuando el registro R17 llega a cero, salta al externo.
		
		RET; REGRESA de la subrutina