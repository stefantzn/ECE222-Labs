.section .text
.align 2
.globl _start

// -------------------------------------------------------------------------------------
// Name:        Lab_2.S
// Purpose:     This code will convert a string of ASCII chracters into Morse code
//              and flash a single LED (Led Bar LED_7) in Morse code with a time base
//		of approximately 500ms.
// Author:      Julius Olajos
// -------------------------------------------------------------------------------------


_start:

// -------------------------------------------------------------------------------------
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
    .equ GPIO_LEDBAR_LED_1, 0x00000800      // LEDBAR LED1
// -------------------------------------------------------------------------------------
// Initialize the GPIO control registers
// -------------------------------------------------------------------------------------

    li t0, GPIO_BASE_CTRL_ADDR          // Load Base Address for GPIO Control Registers
    li t1, GPIO_ALL_LED_PINS            // Load GPIO Register to set GPIO_OUTPUT_EN and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw t1, GPIO_OUTPUT_EN(t0)           // Enable outputs on all GPIO LED Pins (offset to t0 + GPIO_OUTPUT_EN)
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT_VAL(t0)          // Set all LED pins to zero to turn off all LEDS. (offset to t0 + GPIO_OUTPUT_VAL)
          
     
// Reset s1 to the starting address of the input string
ResetLUT:
    la s1, InputLUT           // Assign s1 to the address at label LUT


// Start processing each character byte by byte
NextChar:

    lbu a0, 0(s1)             // Read a character to convert to Morse
    addi s1, s1, 1            // point to next value for number of delays, jump by 1 byte
    snez a1, a0               // If we hit 0 (null at end of the string) then reset to the start of lookup table
    bnez a1, ProcessChar      // If we have a character process it

    // 4 x 500ms delay for repeating the string
    li a2, 4
    jal ra, DELAY

    // Restart from the beginning of the string
    j ResetLUT

// Display the converted character to the LED BAR LED_7
ProcessChar:
    jal ra, CHAR2MORSE        // Convert ASCII to Morse pattern in a1
    li s2, 16                 // Initialize bit counter

// Skip leading zeros of the morse code value
SkipZeros:

    slli a1, a1, 1          // Shift morse code 1 bit left
    li t5, 0x8000           // Mask for the MSB
    and t4, a1, t5          // Set t4 to be the and of the morse code and the MSB
    bnez t4, ProcessBit     // Branch to process the bit if it is 1 
    addi s2, s2, -1         // Decrement bit counter
    j SkipZeros             // Jump back if the 1 has not been reached.

// Process the bit, will start off with t4 being 1, but can be 1 or 0 later on.
ProcessBit:

    and t4, a1, t5
    bnez t4, LED_ON         // If 1, branch to LED_ON
    j LED_OFF               // If 0, jump to LED_OFF

// Turn the LED On
LED_ON:

    addi sp, sp, -16
    sw ra, 12(sp)

    li t0, GPIO_BASE_CTRL_ADDR      // Load Base Address for GPIO Control Registers
    lw t2, GPIO_OUTPUT_VAL(t0)      // Read current GPIO output values
    li t3, 0x800000                 // Mask for LED_7
    or t2, t2, t3                   // Clear bit for LED_7
    sw t2, GPIO_OUTPUT_VAL(t0)      // Write modified value back to output register (0x0C + 0x10012000)

    li a2, 1
    jal ra, DELAY   // 500ms delay

    lw ra, 12(sp)
    addi sp, sp, 16
    j NextBit 

// Turn the LED Off
LED_OFF:
    
    // Set-up stack
    addi sp, sp, -16
    sw ra, 12(sp)

    li t0, GPIO_BASE_CTRL_ADDR      // Load Base Address for GPIO Control Registers
    lw t2, GPIO_OUTPUT_VAL(t0)      // Read current GPIO output values
    li t3, 0x800000                 // Mask for LED_7
    not t3, t3                      // Invert the mask to clear the bit (turn off LED)
    and t2, t2, t3                  // Clear bit for LED_7
    sw t2, GPIO_OUTPUT_VAL(t0)      // Write modified value back to output register

    li a2, 1
    jal ra, DELAY                   // 500ms delay         

    // Read stack and return
    lw ra, 12(sp)
    addi sp, sp, 16
    j NextBit 

NextBit:

    beqz s2, EndChar                // If s2 (bit counter) has parsed through 16 bits, branch to end character
    addi s2, s2, -1                 // Decrement bit counter
    slli a1, a1, 1                  // Shift a1 right by 1 to bring the next bit into MSB
    j ProcessBit                    // Continue processing the next bit

EndChar:

    // 3 x 500ms delay for going to next character
    li a2, 3
    jal ra, DELAY   
    // Jump to next character
    j NextChar


//  Delay Routines
DELAY:
    // Set-up stack
    addi sp, sp, -16
    sw ra, 12(sp)

    li t3, 0x3D0900             // Decrement value for a 500ms delay (500ms * 16MHz / 2 clock cycles)     
    mul t3, t3, a2              // Multiply the decrement value by a2 (the delay factor as an argument)
    
delay_loop:

    addi t3, t3, -1             // Decrement t3
    bnez t3, delay_loop         // As long as t3 is not zero keep looping

    // Read stack and return
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

// Subroutines
// Convert ASCII character to Morse pattern
// Pass ASCII character in a0, output in a1
// Index into MorseLUT must be by steps of 2 bytes

// Convert the ASCII character to Morse Code
CHAR2MORSE:

    // Set-up the stack
    addi sp, sp, -16	    
    sw ra, 12(sp)

    addi s2, a0, -0x41      // s2 index for LUT 
    la t1, MorseLUT         // Load address of the Morse Lookup Table

    // Increment by two bytes as t1 is of type half
    add t1, t1, s2
    add t1, t1, s2
    
    lhu a1, 0(t1)           // Argument reg 1 gets character corresponding half word from LUT
    
    // Read stack and return
    lw ra, 12(sp)		
    addi sp, sp, 16		
    ret

// Data used in the program
.align 2

// Character input string
InputLUT:

    .asciz "AJSTA"

// Morse Code Look Up Table
.align 2
MorseLUT:

    .half 0x17, 0x1D5, 0x75D, 0x75   // A, B, C, D
    .half 0x1, 0x15D, 0x1DD, 0x55    // E, F, G, H
    .half 0x5, 0x1777, 0x1D7, 0x175  // I, J, K, L
    .half 0x77, 0x1D, 0x777, 0x5DD   // M, N, O, P
    .half 0x1DD7, 0x5D, 0x15, 0x7    // Q, R, S, T
    .half 0x57, 0x157, 0x177, 0x757  // U, V, W, X
    .half 0x1D77, 0x775              // Y, Z

End:

  .end