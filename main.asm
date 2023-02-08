;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
; Z.Becker, Haley Turner, EELE 465, Project 02
; I2C "Bit Banging" (Master Read/Write)
;
; Feb 2023
;
; R8 - Buffer offset
; R10 - Data Memory pointer for saving bytes
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer


;-------------------------------------------------------------------------------
; Init
;-------------------------------------------------------------------------------
init:

	bic.w #0001h, &PM5CTL0 				; disable high-z mode

	bis.b	#BIT0, &P1DIR				; Set LED1 as an output
	bic.b	#BIT0, &P1OUT				; Start LED1 off

	bis.b	#BIT6, &P6DIR				; Set LED2 as an output
	bic.b	#BIT6, &P6OUT				; Start LED2 off

	bis.b	#BIT3, &P1DIR				; Set P1.3 = SCL as an output
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to start HIGH

	bis.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an output
	bis.b	#BIT2, &P1OUT           	; Set P1.2 = SDA to start HIGH

	bic.b	#LOCKLPM5, &PM5CTL0			; Enable digital I/O


;-------------------------------------------------------------------------------
; Main
;-------------------------------------------------------------------------------
main:
 	bis.b	#BIT0, &P1OUT				; Turn on LED1
 	mov.w	#512, R5					; Initialize R5 to be the outer delay loop counter
 	call	#Delay						; Delay subroutine

	mov.w	#Var0, R10					; set memory pointer for saving bytes
	mov.b	#3, R11

	call 	#RTCreadSecsMinsHoursTemp

  	jmp		main




;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2Creceive:
	bic.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an INPUT
	call	#I2CsetupDelay

	mov.b	#8, R6						; Set bit count (R6) to 8
	call	#ReceiveBit
	bis.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an OUTPUT
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2CsetupDelay:
	mov.w	ConstSetupDelay,R5
	call	#Delay
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2CsetupDelayOld:
	NOP
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2CbitDelay:
	mov.w	ConstSCLdelay,R5
	call	#Delay
	;NOP
	;NOP
	;NOP
	;NOP
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
ReceiveBit:
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH
	call 	#I2CbitDelay
	mov.b	P1IN, R9
	bit.b	#00000100b, R9				; Is bit 2 a 1?
	jz		I2CreceivedLow
	jmp		I2CreceivedHigh
I2CcheckReceivedBit:
	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	call 	#I2CbitDelay
	dec 	R6
	jnz		ReceiveBit
	call	#SaveByte

	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2CreceivedHigh:
	rla.w	R7
	bis.b	#00000001b, R7
	jmp		I2CcheckReceivedBit
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2CreceivedLow:
	rla.w	R7
	bic.b	#00000001b, R7
	jmp		I2CcheckReceivedBit
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
SaveByte:
	mov.b	R7, 0(R10)
	inc		R10
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
I2CsetAddr:
 	call	#I2Cstart					; I2Cstart subroutine

	mov.b   #8, R6						; Set buffer for 7bit-addr + RW
	mov.b	ConstSlaveAddr, R7			; Hex Address of Slave
	mov.w	#9, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
 	call 	#CheckAck

 	mov.b   #8, R6						; Set buffer 8bit data
	mov.b	R12, R7						; load address
	mov.w	#8, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
 	call 	#CheckAck

 	call 	#I2Cstop
 	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
Delay:
	mov.w 	ConstInnerDelay, R4			; Initialize R4 to be the inner delay loop counter
InnerDelay:
	dec.w 	R4					; Decrement R4, the inner delay loop
	jnz 	InnerDelay			; Iterate inner delay loop until R4 holds a value of 0
	dec.w	R5					; Decrement R5, the outer delay loop
	jnz		Delay				; Reiterate inner loop until R5 holds a value of 0
 	ret


;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2Cstart
;-------------------------------------------------------------------------------
I2Cstart:
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH -- Already done in init
	bis.b	#BIT2, &P1OUT				; Set P1.2 = SDA to HIGH

	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	call	#I2CbitDelay
	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	call	#I2CbitDelay

	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2Cstop
;-------------------------------------------------------------------------------
I2Cstop:
	bis.b	#BIT3, &P1OUT				; Set P1.2 = SCL to HIGH
	call	#I2CbitDelay
	bis.b	#BIT2, &P1OUT				; Set P1.3 = SDA to HIGH
	call	#I2CbitDelay

	ret
;----------------------------- END I2Cstart ------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2Csend
;-------------------------------------------------------------------------------
I2Csend:
	call	#TransmitByte					; I2CtxByte subroutine
	ret
;----------------------------- END I2Csend -------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: TransmitByte
;-------------------------------------------------------------------------------
TransmitByte:
	call 	#TransmitBit
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: PrepareBuffer
;-------------------------------------------------------------------------------
PrepareBuffer:
	rla.w 	R7
	dec 	R8
	jnz		PrepareBuffer
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: TransmitBit
;-------------------------------------------------------------------------------
TransmitBit:
	rla.w	R7							; Rotate next bit into carry bit
	jc		SetSDA
	jnc 	ResetSDA
TransmitBitMid:
	call	#I2CsetupDelay
	call	#I2CcycleSCL
	DEC 	R6
	jnz  	TransmitBit
	ret
	jmp 	main
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: ReadWriteBit
;-------------------------------------------------------------------------------
ReadWriteBit:
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW for WRITE
	call	#I2CcycleSCL
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: CheckAck
;
; TODO: need to actually check for Ack and produce error if applicable
;
;-------------------------------------------------------------------------------
CheckAck:
	bic.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an INPUT
	call	#I2CsetupDelay
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH
	call 	#I2CbitDelay
	mov.b	P1IN, R9
	;bit.b	#00000001b,
	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	bis.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an OUTPUT
	call 	#I2CbitDelay

	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: SendAck
;-------------------------------------------------------------------------------
SendAck:
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	call	#I2CsetupDelay
	call	#I2CcycleSCL
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: SendNack
;-------------------------------------------------------------------------------
SendNack:
	bis.b	#BIT2, &P1OUT				; Set P1.2 = SDA to HIGH
	call	#I2CsetupDelay
	call	#I2CcycleSCL
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	call 	#I2CbitDelay
	ret
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: SetSDA
;-------------------------------------------------------------------------------
SetSDA:
	bis.b	#BIT2, &P1OUT				; Set P1.2 = SDA to HIGH
	jmp 	TransmitBitMid
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: ResetSDA
;-------------------------------------------------------------------------------
ResetSDA:
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	jmp 	TransmitBitMid
;----------------------------- END Delay ---------------------------------------



;-------------------------------------------------------------------------------
; Subroutine: I2CcycleSCL
;-------------------------------------------------------------------------------
I2CcycleSCL:
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH
	call 	#I2CbitDelay						; Delay subroutine
	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	call 	#I2CbitDelay						; Delay subroutine
	ret
;----------------------------- END I2CcycleSCL ---------------------------------

;-------------------------------------------------------------------------------
; Subroutine: RTCreadSecsMinsHoursTemp
;-------------------------------------------------------------------------------
RTCreadSecsMinsHoursTemp:
	mov.b	#00000000b, R12				; Slave counter address for "minutes"
	call	#I2CsetAddr					; Call subroutine to set I2C Slave counter address

 	call	#I2Cstart					; I2Cstart subroutine

	mov.b   #8, R6						; Set buffer for 7bit-addr + R
 	mov.b	ConstSlaveAddr, R7					; Hex Address of Slave
 	rla.w	R7
 	or.b	#00000001b, R7
	mov.w	#8, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
  	call 	#CheckAck

  	call 	#I2Creceive					; Request "seconds"
 	call	#SendAck

  	call 	#I2Creceive					; Request "minutes"
 	call	#SendAck

 	call 	#I2Creceive					; Request "hours"
 	call	#SendNack
 	call 	#I2Cstop

	call 	#RTCreadTemp				; Run subroutine to obtain "temperature"

 	dec		R11
 	jnz		RTCreadSecsMinsHoursTemp

 	ret
;----------------------------- END RTCreadSecsMinsHoursTemp --------------------


;-------------------------------------------------------------------------------
; Subroutine: RTCreadTemp
;-------------------------------------------------------------------------------
RTCreadTemp:
	mov.b	#0011h, R12					; Slave counter address (11h) for "temperature (integer part)"
	call	#I2CsetAddr					; Call subroutine to set I2C Slave counter address
 	call	#I2Cstart					; I2Cstart subroutine

	mov.b   #8, R6						; Set buffer for 7bit-addr + R
	mov.b	ConstSlaveAddr, R7			; Hex Address of Slave
 	rla.w	R7
 	or.b	#00000001b, R7
	mov.w	#8, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
  	call 	#CheckAck

  	call 	#I2Creceive					; Request "temp (integer part)"
 	call	#SendAck

  	call 	#I2Creceive					; Request "temp (fractional part)"
 	call	#SendNack

 	call 	#I2Cstop
 	ret
;----------------------------- END RTCreadTemp ---------------------------------


;-------------------------------------------------------------------------------
; Memory Allocation
;-------------------------------------------------------------------------------
			.data
			.retain

ConstSlaveAddr:		.short		00068h
ConstSetupDelay: 	.short		1
ConstSCLdelay:		.short		5
;ConstInnerDelay:	.short		000A6h
ConstInnerDelay:	.short		1

Var0:		.space		3
Var1:		.space		3
;----------------------------- END Delay ---------------------------------------


;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
            
			;sect	".int43"				; EUSCI B0 vector
            ;.short 	ISR_TB0_CCR
