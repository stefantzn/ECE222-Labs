.section .text
.globl _start
.align  2

// -------------------------------------------------------------------------------------
// Name:        Lab_1.S
// Purpose:     This code will flash a single LED at an approximate 1 Hz frequency
// Author:      Julius Olajos
// -------------------------------------------------------------------------------------
//
// -------------------------------------------------------------------------------------

_start:

// GPIO Control Registers Memory Mapping

.equ GPIO_BASE_CTRL_ADDR, 0x10012000    // Base address for the GPIO control registers
.equ GPIO_OUTPUT_EN,      0x08          // address offset for enabling GPIO outputs
.equ GPIO_OUTPUT_VAL,     0x0C          // Address offset for writing to GPIO outputs
.equ GPIO_OUTPUT_XOR,     0x40          // Address offset for GPIO Outputs XOR

// -------------------------------------------------------------------------------------
// 8 LEDS, 7 Segment LED Display Pins Register Address Mapping

.equ GPIO_7SEGLED_PINS, 0x0000023F      // Seven Segment LED Display Pins (7)
.equ GPIO_LEDBAR_PINS,  0x00FC0C00      // LED Bar Pins (8)
.equ GPIO_ALL_LED_PINS, 0x00FC0E3F      // All LED Pins (15)
.equ GPIO_LEDBAR_LED_1, 0x00000800      // LEDBAR LED1 (Bit 11)
// -------------------------------------------------------------------------------------
// Initialize the GPIO control registers and run the delay loop code
// -------------------------------------------------------------------------------------


    li t0, GPIO_BASE_CTRL_ADDR          // Load Base Address for GPIO Control Registers
    li t1, GPIO_ALL_LED_PINS            // Load GPIO Register to set GPIO_OUTPUT_EN and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw t1, GPIO_OUTPUT_EN(t0)           // Enable outputs on all GPIO LED Pins
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT_VAL(t0)          // Set all LED pins to zero to turn off all LEDS.
  
    li t5, GPIO_LEDBAR_LED_1     // Load LED_1 Address into t5 (Bit 11)
    lw t3, GPIO_OUTPUT_VAL(t0)   // Read GPIO output values into t3 
    xor t3, t5, t3               // XOR the GPIO output value (all zeroes to the LEDs)
    sw t3, GPIO_OUTPUT_VAL(t0)   // Store this new value in GPIO output register

loop: // 

    li t4, 0x3D0900 // Load immediate 0x4c4b40 into t4 (counter value)

loop1: // Label for code looped through by branch structure on line 52, terminated when t4 has same value of x0. 

    addi t4, t4, -1 // Decrement immediate at t4 by -1
    bne t4, x0, loop1 // Branch structure (branch not equal 0) with loop1 as the label for the branch.
    
    lw t3, GPIO_OUTPUT_VAL(t0) //reads the GPIO_OUTPUT_VAL and loads to register t3 
    xor t3, t5, t3 //XOR between t3 and bit 11 (t5) will flip bit 11 causing toggle behaviour
    sw t3, GPIO_OUTPUT_VAL(t0) //Stores the new t3 value post XOR operation to toggle LED ON/OFF

    j loop                       // Jump back to loop and start over

/* Lab Report: Hand Asssembly of ADDI t4,t3, 0x100

Instructions are 32-bits long (4 bytes). ADDI is a I-type instruction because it involves an immediate value. 
Destination register is t4, t3 is operand register 1.

Immediate value 0x100 to decimal yields 256. 256 = 2^8. Hence, in an 11 bit representation, all bits will be 0 expect for the bit at 2^8. 

Using Appendix D/H:

immm[11:0] -> 11 bit immediate value for ADDI -> 00100000000  
rs1 -> 4 bit code for register t3 -> x28 -> 11100    
funct3 -> 3 bit function code for ADDI -> 000
rd -> t4 destination register -> x29 -> 11101
opcode -> opcode of ADDI -> 0010011

Therefore, the commmand handwritten would be as 00100000000 11100 000 11101 0010011.  
*/