.section .text
.align 2
.globl _start


// -------------------------------------------------------------------------------------
// Name:        Lab_3.S
// Purpose:     This code has 2 parts: the first part is to create a simple counter
//              subroutine that increments from 0x00 to 0xFF, wraps to 0 and continues
//              counting.  There is a 100ms delay between the display of the count. 
//		The second part is a reflex meter that will measure how fast
//              a user responds to an event accurate to a 10th of a millisecond.
//              Initially, all LED's are off and after a random amount of time
//              (between 2 and 10 seconds), one LED turns on (LED_6) and then the user
//		presses pushbutton S1.  The press of the button will be monitored by
//		using "polling".
//
// Author:      Julius Olajos
// -------------------------------------------------------------------------------------


_start:

// -------------------------------------------------------------------------------------
// GPIO Control Registers Memory Mapping

    .equ GPIO_BASE_CTRL_ADDR, 0x10012000    // Base address for the GPIO control registers
    .equ GPIO_OUTPUT_EN,      0x08          // address offset for enabling GPIO outputs
    .equ GPIO_OUTPUT_VAL,     0x0C          // Address offset for writing to GPIO outputs
    .equ GPIO_OUTPUT_XOR,     0x40          // Address offset for GPIO Outputs XOR
    .equ GPIO_INPUT_VAL,      0x00          // Address offset for reading GPIO inputs
    .equ GPIO_INPUT_EN,       0x04          // address offset for enabling GPIO inputs
    .equ GPIO_PUE,            0x10          // address offset for internal GPIO pull-up resistor

// -------------------------------------------------------------------------------------
// 8 LEDS, 7 Segment LED Display Pins Register Address Mapping

    .equ GPIO_7SEGLED_PINS,   0x0000023F      // Seven Segment LED Display Pins (7)
    .equ GPIO_LEDBAR_PINS,    0x00FC0C00      // LED Bar Pins (8)
    .equ GPIO_ALL_LED_PINS,   0x00FC0E3F      // All LED Pins (15)
    .equ GPIO_LEDBAR_LED_1,   0x00000800      // LEDBAR LED1

// -------------------------------------------------------------------------------------
// Pushbuttons SW(x) Register Address Mapping

    .equ GPIO_SW_1,           0x00001000      // SW1 pushbutton (bit 12)
    .equ GPIO_SW_2,           0x00002000      // SW2 Pushbutton (bit 13)
    .equ GPIO_ALL_PBS,        0x00003000      // All Pushbutton Pins (bits 12, 13)

// Initialize the GPIO control registers
// -------------------------------------------------------------------------------------

    li t0, GPIO_BASE_CTRL_ADDR          // Load Base Address for GPIO Control Registers
    li t1, GPIO_ALL_LED_PINS            // Load GPIO Register to set GPIO_OUTPUT_EN and GPIO_OUTPUT_XOR registers for all GPIO LED Pins
    sw t1, GPIO_OUTPUT_EN(t0)           // Enable outputs on all GPIO LED Pins
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT_VAL(t0)          // Set all LED pins to zero to turn off all LEDS.
    li t1, GPIO_SW_1                    // Load GPIO Register to set GPIO_INPUT_EN for input pins
    sw t1, GPIO_INPUT_EN(t0)            // Enable inputs on all Pushbutton pins

// -------------------------------------------------------------------------------------


INITIAL:

 	li a7, 0xABCD                   // Initializes register a7 to a 16-bit non-zero value and NOTHING else can write to a7 !!!!
    li a0, 0x00                     // Initialize counter at 0
    li s0, 0xFF                     // Upper max for LED counter

COUNTER:
    
    jal ra, DISPLAY_NUM             // Display the current number in the counter
    addi a0, a0, 1                  // Increment the counter by 1
    li t0, 0x3E8                    // Finetuned delay value
    li t4, GPIO_BASE_CTRL_ADDR      // Load base address for GPIO control
    li t2, 0x00001000               // Bitmask for s1 (button 1)

// I create my own counter delay so that I can keep constantly checking if the button has been pressed compared to waiting a whole 100ms delay for it to process,
// also, creating a counter delay helps keep the number more random as it regenerates every 0.1ms.
COUNTER_DELAY:

    jal ra, DELAY                       // Call 0.1ms delay
    jal ra, RandomNum                   // Generate new random number in a7


    lw t3, GPIO_INPUT_VAL(t4)           // Load current value of GPIO input into t2                  
    and t3, t3, t2                      // And the s1 mask with the current input value to get the new one
    beqz t3, REFLEX                     // Branch out to reflex if the button is pressed (0, as the button is active low)
    addi t0, t0, -1                     // Decrement counter delay value
    bnez t0, COUNTER_DELAY              // Exit if it reaches 0

    bne a0, s0, COUNTER
    j INITIAL

loop:
//  Generate random number
    jal ra, RandomNum

//  Once your number has been generated, it will be stored in register a7. Do not overwrite this!
//  You will now need to set up delays, subroutines to turn the LED ON and OFF, and for polling whether the Pushbutton S1 has been pressed.
//  Keep in mind that you will get a 32-bit number back from the random number generator.  You will need to display this 8 bits at a time,
//  starting with the lowest 8 bits.
//  You will probably want to rotate 8 bits at a time for display.
REFLEX:

    // Set-up stack
    addi sp, sp, -16
    sw ra, 12(sp) 

    li t0, GPIO_BASE_CTRL_ADDR  // Load base address for GPIO control

    // Turn off all LEDS
    li t1, 0                    
    sw t1, GPIO_OUTPUT_VAL(t0) 

    // a7 % 128
    li t2, 128
    remu a7, a7, t2

    // (a7 % 128) * 630
    li t2, 630
    mul a7, a7, t2

    // (a6 % 128) * 630 + 20000
    li t2, 20000
    add a7, a7, t2

    mv t2, a7   // Move the modified value into t2 to process in the next subroutine

REFLEX_DELAY_STAGE_1:

    jal ra, DELAY                   // Call delay
    addi t2, t2, -1                 // Decrement random value delay
    bnez t2, REFLEX_DELAY_STAGE_1   // Exit once the random delay reaches 0

    li t1, (1 << 21)                // Bit mask for LED 6 (bit 21)
    sw t1, GPIO_OUTPUT_VAL(t0)      // Turn LED 6 on
    li s0, 0x00001000               // Mask for button
    lui t2, 0                       // Starter value for human reaction time

// This stage is performed after the LED is turned on which starts the human reaction time counter is started
REFLEX_DELAY_STAGE_2:

    jal ra, DELAY                   // Call delay
    lw t1, GPIO_INPUT_VAL(t0)       // Load the GPIO input value into t1
    addi t2, t2, 1                  // Increment by 1
    and t1, t1, s0                  // Check if button is active low

    bnez t1, REFLEX_DELAY_STAGE_2   // Exit if the button is pressed
    mv s2, t2                       // Store the value of t2 (human reaction time) to s2 so we free up t2

// Display the 32-bit number on the 8-LED Bar
// Register t1 holds the value of the number to be displayed
// Map each bit of the number to the corresponding LED Bar bit
// MSB to LSB: bits 23, 22, 21, 20, 19, 18, 11, 10
DISPLAY:

    li t1, 4                        // Loop counter for 4 bytes (4 segments of 8 bits each)
    mv a0, s2                       // Move the stored reaction time to a0        

DISPLAY_LOOP:

    // Set-up stack
    li t0, GPIO_BASE_CTRL_ADDR      // Load base address for GPIO control
    lw t4, GPIO_OUTPUT_VAL(t0)      // Load t4 with GPIO output value

    // Bitmask for LEDS[23:18]
    andi t2, a0, 0xFC
    slli t2, t2, 16

    // Bitmask for LEDS[11:10]
    andi t3, a0, 0x3
    slli t3, t3, 10

    // Combine masks
    or t2, t2, t3

    // Mask inverse of LEDS
    li t5, 0xFF03F3FF

    // Set LEDS to 0 and keep original GPIO output values the same
    and t4, t4, t5

    // Apply the 8-bit LED number to the output
    or t4, t4, t2

    // Set to the GPIO output values (turn on the LEDS)
    sw t4, GPIO_OUTPUT_VAL(t0)

    // Shift to the next 8-bits going right (from least to most significant)
    srli a0, a0, 8

    // Delay by 2 seconds between the 4 8-bit numbers
    li a2, 20000
    jal ra, DELAY_mul

    // Decrement the counter 
    addi t1, t1, -1
    bnez t1, DISPLAY_LOOP

    // Delay by 5 seconds once the full 32-bit number
    li a2, 50000
    jal ra, DELAY_mul

    // Keep looping the DISPLAY subroutine
    j DISPLAY

    // Read stack and return
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

DISPLAY_NUM:

    addi sp, sp, -16
    sw ra, 12(sp)

    // Remember, the 8 LEDS are mapped to the GPIO as bits MSB to LSB: bits 23, 22, 21, 20, 19, 18, 11, 10

    li t0, GPIO_BASE_CTRL_ADDR      // Load base address for GPIO control
    lw t4, GPIO_OUTPUT_VAL(t0)      // Load t4 with GPIO output value

    // Bitmask for LEDS[23:18]
    andi t2, a0, 0xFC
    slli t2, t2, 16

    // Bitmask for LEDS[11:10]
    andi t3, a0, 0x3
    slli t3, t3, 10

    // Combine masks
    or t2, t2, t3

    // Mask inverse of LEDS
    li t5, 0xFF03F3FF

    // Set LEDS to 0 and keep original GPIO output values the same
    and t4, t4, t5
    
    // Apply the 8-bit LED number to the output
    or t4, t4, t2
   
    // Set to the GPIO output values (turn on the LEDS)
    sw t4, GPIO_OUTPUT_VAL(t0)

    // Read stack and return
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

// Random Number generator
// Register a7 holds the random number.
// You can read this value anywhere in the code, but this register can only be written to by this subroutine
// Or Else!
RandomNum:

    // Set-up stack
    addi sp, sp, -16
    sw ra, 12(sp)

    li s4, 0x8000		     // Load upper 20 bits
    and t1, a7, s4  		 // Mask to lower 16 bits
    li s4, 0x2000  		     // Load upper 20 bits
    and t3, a7, s4  		 // Mask to lower 16 bits


    slli t3, t3, 2
    xor t3, t1, t3
    li s4, 0x1000  		     // Load upper 20 bits
    and t1, a7, t0		     // Mask to lower 16 bits

    slli t1, t1, 3
    xor t3, t3, t1
    andi t1, a7, 0x0400
    slli t1, t1, 5
    xor t3, t3, t1
    srli t3, t3, 15
    slli a7, a7, 1
    or a7, a7, t3		     // Register a7 holds the random number

    // Read stack and return
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

DELAY:
    // Set-up stack
    addi sp, sp, -16
    sw ra, 12(sp)

    li t3, 0x3E8        // Fine tuned value of the delay, which is 1000 (originally 800)
    
delay_loop:

    addi t3, t3, -1          // Decrement loop
    bnez t3, delay_loop     // Exit when it equals 0  

    // Read stack and return
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

DELAY_mul:
    // Set-up stack
    addi sp, sp, -16
    sw ra, 12(sp)

    li t3, 0x3E8        // Fine tuned value of the delay, which is 1000 (originally 800)
    mul t3, t3, a2      // Multiply by factor  
    
delay_mul_loop:

    addi t3, t3, -1             // Decrement loop
    bnez t3, delay_mul_loop     // Exit when it equals 0  

    // Read stack and return
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

/*  POST-LAB QUESTIONS - Stefan.T
*
*   1. If a 32-bit register is counting user reaction time in 0.1 milliseconds increments, what is
*      the maximum amount of time which can be stored in 8 bits, 16-bits, 24-bits and 32-bits?
*
*   A. In 8 bits, the maximum unsigned value is 2^8 - 1 = 255, which if the increment is 0.1ms, than 255 x 0.1ms = 25.5 milliseconds.
*      Consequently, for 16-bits: 2^16 - 1 = 65535 x 0.1ms = 6.5535 seconds, 24-bits: 2^24 - 1 = 16777215 x 0.1ms = 1677.7215 seconds
*      32-bits: 2^32 - 1 = 4294967295 x 0.1ms = 429496.7295 seconds, or 119.3 hours
*
*   2. Considering typical human reaction time, which size would be the best for this task (8, 16, 24, or 32 bits)?
*   
*   A. Average human reaction time is around 250 milliseconds, so a good upper bound to have would be 6.5535 seconds, so 16 bits would suffice for this task.
*
*   3. Prove time delay meets 2 to 10 sec +/- 5% spec
*
*   A. To prove we meet the 2 to 10 seconds +/- 5%, we know that a7 will contain a value between 0 and 65535, we can do a7 % 128 to get a value between 0 and 127.
*      After, multiply this value by 630 to get a range of 0-80010. Finally, we can apply a postive offset of 20000 to get a desired range of 20000 and 100010, which well within 
*      5% range of the specified 20000-100000. Next, to prove that my 0.1ms delay loop is relatively close to an actual delay of 0.1ms, we can do the following calculations:
*      ((16 Mhz * 0.1ms) / 2) = 800. This is just an aproximation however, so the actual clock speed of the processor might be higher as after adjusting and doing hand-tests
*      of my program, a value of 1000 gets me within 5% of the actual time of the scaled delay. By this, after proving my 0.1ms delay is within 5%, and my range of 20,0000 to
*      100010 is sufficient with the desired range, my delay meets 2 to 10 sec +/- 5% spec.
*
*      Note that 20000 to 100000 times 0.1ms is 2-10 seconds.
*/