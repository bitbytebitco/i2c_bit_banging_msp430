;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
; Z.Becker, Haley Turner, EELE 465, Project 02
; I2C "Bit Banging" (Master Read/Write)
; [includes functions for communicating with DS3231 (real-time clock) as SLAVE]
;
; Feb 2023
;
;
; REGISTER USE LEGEND
; R4 - Inner delay loop counter
; R5 - Outer delay loop counter
; R6 - Bit counter for use with buffer during transmit/receive
; R7 - Transmit/receive buffer
; R8 - Buffer offset
; R9 - Receive buffer (for Ack)
; R10 - Register to hold Data Memory pointer for saving bytes
; R11 - Counter in Main
; R12 - I2C Slave address
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
Init:
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
;----------------------------- END Init ----------------------------------------

;-------------------------------------------------------------------------------
; Main
;-------------------------------------------------------------------------------
Main:
 	bis.b	#BIT0, &P1OUT				; Turn on LED1
 	mov.w	#512, R5					; Initialize R5 to be the outer delay loop counter
 	call	#Delay						; Delay subroutine

	mov.w	#Var0, R10					; set memory pointer for saving bytes
	mov.b	#1, R11						; set number of time readings to save

	call 	#RTCreadSecsMinsHoursTemp
	call 	#RTCreadTemp				; Run subroutine to obtain "temperature"

  	jmp		Main
;----------------------------- END Main ---------------------------------------

;-------------------------------------------------------------------------------
; Subroutine: RTCreadSecsMinsHoursTemp
;-------------------------------------------------------------------------------
RTCreadSecsMinsHoursTemp:
	mov.b	#00000000b, R12				; Slave counter address for "minutes"
	call	#I2CsetAddr					; Call subroutine to set I2C Slave counter address

 	call	#I2Cstart					; I2Cstart subroutine

	mov.b   #8, R6						; Set buffer for 7bit-addr + R
 	mov.b	ConstSlaveAddr, R7			; Hex Address of Slave
 	rla.w	R7
 	or.b	#00000001b, R7
	mov.w	#8, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
  	call 	#I2CackRequest

  	call 	#I2Creceive					; Request "seconds"
 	call	#I2CsendAck

  	call 	#I2Creceive					; Request "minutes"
 	call	#I2CsendAck

 	call 	#I2Creceive					; Request "hours"
 	call	#I2CsendNAck
 	call 	#I2Cstop

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
  	call 	#I2CackRequest

  	call 	#I2Creceive					; Request "temp (integer part)"
 	call	#I2CsendAck

  	call 	#I2Creceive					; Request "temp (fractional part)"
 	call	#I2CsendNAck

 	call 	#I2Cstop
 	ret
;----------------------------- END RTCreadTemp ---------------------------------

;-------------------------------------------------------------------------------
; Subroutine: I2Creceive
;-------------------------------------------------------------------------------
I2Creceive:
	bic.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an INPUT
	call	#I2CsetupDelay

	mov.b	#8, R6						; Set bit count (R6) to 8
	call	#ReceiveBit
	bis.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an OUTPUT
	ret
;----------------------------- END I2Creceive ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CsetupDelay
;-------------------------------------------------------------------------------
I2CsetupDelay:
	mov.w	ConstSetupDelay,R5
	call	#Delay
	ret
;----------------------------- END I2CsetupDelay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CbitDelay
;-------------------------------------------------------------------------------
I2CbitDelay:
	mov.w	ConstSCLdelay,R5
	call	#Delay

	ret
;----------------------------- END I2CbitDelay ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: ReceiveBit
;-------------------------------------------------------------------------------
ReceiveBit:
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH
	call 	#I2CbitDelay
	mov.b	P1IN, R9
	bit.b	#00000100b, R9				; Is SDA HIGH? (checking P1.2 with Logical AND)
	jz		I2CreceivedLow
	jmp		I2CreceivedHigh
I2CcheckReceivedBit:
	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	call 	#I2CbitDelay
	dec 	R6
	jnz		ReceiveBit
	call	#SaveByte

	ret
;----------------------------- END ReceiveBit ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CreceivedHigh
;-------------------------------------------------------------------------------
I2CreceivedHigh:
	rla.w	R7
	bis.b	#00000001b, R7
	jmp		I2CcheckReceivedBit
;----------------------------- END I2CreceivedHigh ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CreceivedLow
;-------------------------------------------------------------------------------
I2CreceivedLow:
	rla.w	R7
	bic.b	#00000001b, R7
	jmp		I2CcheckReceivedBit
;----------------------------- END I2CreceivedLow ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: SaveByte
;-------------------------------------------------------------------------------
SaveByte:
	mov.b	R7, 0(R10)
	inc		R10
	ret
;----------------------------- END SaveByte ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CsetAddr
;-------------------------------------------------------------------------------
I2CsetAddr:
 	call	#I2Cstart					; I2Cstart subroutine

	mov.b   #8, R6						; Set buffer count for 7bit-addr + RW
	mov.b	ConstSlaveAddr, R7			; Hex Address of Slave
	mov.w	#9, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
 	call 	#I2CackRequest

 	mov.b   #8, R6						; Set buffer counter for 8 bits of data
	mov.b	R12, R7						; load address
	mov.w	#8, R8
	call	#PrepareBuffer
 	call	#I2Csend					; I2Csend subroutine
 	call 	#I2CackRequest

 	call 	#I2Cstop
 	ret
;----------------------------- END I2CsetAddr ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: Delay
;-------------------------------------------------------------------------------
Delay:
	mov.w 	ConstInnerDelay, R4			; Initialize R4 to be the inner delay loop counter
InnerDelay:
	dec.w 	R4							; Decrement R4, the inner delay loop
	jnz 	InnerDelay					; Iterate inner delay loop until R4 holds a value of 0
	dec.w	R5							; Decrement R5, the outer delay loop
	jnz		Delay						; Reiterate inner loop until R5 holds a value of 0
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
;----------------------------- END I2Cstart ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2Cstop
;-------------------------------------------------------------------------------
I2Cstop:
	bis.b	#BIT3, &P1OUT				; Set P1.2 = SCL to HIGH
	call	#I2CbitDelay
	bis.b	#BIT2, &P1OUT				; Set P1.3 = SDA to HIGH
	call	#I2CbitDelay

	ret
;----------------------------- END I2Cstop ------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2Csend
;-------------------------------------------------------------------------------
I2Csend:
	call	#I2CtxByte					; I2CtxByte subroutine
	ret
;----------------------------- END I2Csend -------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CtxByte
;-------------------------------------------------------------------------------
I2CtxByte:
	call 	#I2CtransmitBit
	ret
;----------------------------- END I2CtxByte ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: PrepareBuffer
;-------------------------------------------------------------------------------
PrepareBuffer:
	rla.w 	R7
	dec 	R8
	jnz		PrepareBuffer
	ret
;----------------------------- END PrepareBuffer ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CtransmitBit
;-------------------------------------------------------------------------------
I2CtransmitBit:
	rla.w	R7							; Rotate next bit into carry bit
	jc		SetSDA
	jnc 	ResetSDA
I2CtransmitBitMid:
	call	#I2CsetupDelay
	call	#I2CcycleSCL
	DEC 	R6
	jnz  	I2CtransmitBit
	ret
	jmp 	Main
;----------------------------- END I2CtransmitBit ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CackRequest
;-------------------------------------------------------------------------------
I2CackRequest:
	bic.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an INPUT
	call	#I2CsetupDelay
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH
	call 	#I2CbitDelay
	mov.b	P1IN, R9

	call 	#I2CtestAck

	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	bis.b	#BIT2, &P1DIR				; Set P1.2 = SDA as an OUTPUT
	call 	#I2CbitDelay

	ret
;----------------------------- END I2CackRequest ---------------------------------------

;-------------------------------------------------------------------------------
; Subroutine: I2CtestAck
;-------------------------------------------------------------------------------
I2CtestAck:
	bit.b	#00000100b, R9				; Logical AND of HIGH and R9 (P1IN register copy)
	jnz 	I2CackError
	ret
;----------------------------- END I2CtestAck ---------------------------------------

;-------------------------------------------------------------------------------
; Subroutine: I2CackError
;-------------------------------------------------------------------------------
I2CackError:
	; do something meaningful here
	NOP
	ret
;----------------------------- END I2CackError ---------------------------------------

;-------------------------------------------------------------------------------
; Subroutine: I2CsendAck
;-------------------------------------------------------------------------------
I2CsendAck:
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	call	#I2CsetupDelay
	call	#I2CcycleSCL
	ret
;----------------------------- END I2CsendAck ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: I2CsendNAck
;-------------------------------------------------------------------------------
I2CsendNAck:
	bis.b	#BIT2, &P1OUT				; Set P1.2 = SDA to HIGH
	call	#I2CsetupDelay
	call	#I2CcycleSCL
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	call 	#I2CbitDelay
	ret
;----------------------------- END I2CsendNAck ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: SetSDA
;-------------------------------------------------------------------------------
SetSDA:
	bis.b	#BIT2, &P1OUT				; Set P1.2 = SDA to HIGH
	jmp 	I2CtransmitBitMid
;----------------------------- END SetSDA ---------------------------------------


;-------------------------------------------------------------------------------
; Subroutine: ResetSDA
;-------------------------------------------------------------------------------
ResetSDA:
	bic.b	#BIT2, &P1OUT				; Set P1.2 = SDA to LOW
	jmp 	I2CtransmitBitMid
;----------------------------- END ResetSDA ---------------------------------------



;-------------------------------------------------------------------------------
; Subroutine: I2CcycleSCL
;-------------------------------------------------------------------------------
I2CcycleSCL:
	bis.b	#BIT3, &P1OUT				; Set P1.3 = SCL to HIGH
	call 	#I2CbitDelay				; Delay subroutine
	bic.b	#BIT3, &P1OUT				; Set P1.3 = SCL to LOW
	call 	#I2CbitDelay				; Delay subroutine
	ret
;----------------------------- END I2CcycleSCL ---------------------------------


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
