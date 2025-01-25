// -------------------------------------------------------------------------------------
// Name:        Lab_4.S
// Purpose:     This code has 2 parts: the first part is to flash all 8 LED's on and off
//              at a rate between 1 - 10Hz while the random number generator is called
//              continuosly. The random number generated will generate a number that
//              gives a time delay of 5.0 to 25.0 seconds. with a resolution of 0.1s.
//              Pressing pushbutton S1 will create an interrupt in the microprocessor, 
//              forcing the interrupt service routine (ISR) to run.
//              The ISR program displays this random number (without a decimal) on 
//              the 8 LED's.  The program delays for 1 second (count of 10) and the
//              new count (time left) is diplayed. This continues until the count is
//              equal to or less than 0.  The program then exits the ISR and returns to
//              the main program and flashes all 8 LED's again as before.  
//              The program then waits for another press of pushbutton S1 and everything
//              repeats.

// Author:      Julius Olajos
// -------------------------------------------------------------------------------------

.section .text
.align 2
.globl _start

// Constants
GPIO_BASE                   = 0x10012000      // GPIO base address
GPIO_OUTPUT                 = 0x0C            // GPIO output register offset
GPIO_OUTPUT_ENABLE          = 0x08            // GPIO output enablr register offset
GPIO_INPUT                  = 0x00            // GPIO input register offset
GPIO_INPUT_ENABLE           = 0x04            // GPIO input enable register offset
GPIO_7SEGLED_PINS           = 0x0000023F      // Seven Segment LED Display Pins (7)
GPIO_LEDBAR_PINS            = 0x00FC0C00      // LED Bar Pins (8)
GPIO_ALL_LED_PINS           = 0x00FC0E3F      // All LED Pins (15)
GPIO_FALL_INTERRUPT_ENABLE  = 0x20            // Falling edge interrupt enable register offset
GPIO_FALL_INTERRUPT_PENDING = 0x24            // Falling Edge interrupt pending register offset
GPIO_IO_FUNCTION_ENABLE     = 0x028           // I/O function enable register offset
GPIO_IO_FUNCTION_SELECT     = 0x02C           // I/O function select register offset
PLIC_BASE                   = 0x0C000000      // PLIC base address
PLIC_ENABLE                 = 0x2000          // PLIC interrupt enable register offset
PLIC_PRIORITY               = 0x0004          // PLIC priority register offset
PLIC_THRESHOLD              = 0x200000        // PLIC threshold register offset
PLIC_CLAIM                  = 0x200004        // PLIC claim/complete register offset
PLIC_INT_PEND               = 0x1000          // PLIC Interrupt pending register 1 offset
S1_GPIO_PIN                 = 12              // S1 pushbutton pin number (active low)
S1_IRQ                      = 12              // IRQ number for GPIO pin 12
S1_PLIC_ID                  = 20              // PLIC Interrupt source ID for GPIO pin 12
S1_PRIORITY                 = 7               // Interrupt priority for S1

// --------------------------------------------------------------------------------------------------------------
// This is the setup for the interrupt functionality of the RISC-V processor
//
// --------------------------------------------------------------------------------------------------------------

_start:
    // Set up mtvec with the address of the interrupt vector (S1_interrupt)
    la t0, S1_interrupt
    csrw mtvec, t0

    // Enable external machine interrupts in the mie register
    li t0, (1 << 11)                      // Enable machine external interrupts (MEIE)
    csrs mie, t0

    // Enable global interrupts in the mstatus register
    csrr t0, mstatus
    li t1, (1 << 3)                       // Set MIE (Machine Interrupt Enable) bit mask in mstatus
    or t0, t0, t1
    csrw mstatus, t0

// You need to set up the pushbutton S1 in the GPIO pins as an input. Refer to your Lab 3 code.
// --------------------------------------------------------------------------------------------------------------

    li t0, GPIO_BASE
    li t1, 0x1000                  // Load GPIO Register to set GPIO_INPUT_EN for input pins
    sw t1, GPIO_INPUT_ENABLE(t0)            // Enable inputs on all Pushbutton pins

// --------------------------------------------------------------------------------------------------------------

// You need to set up the LED's in the GPIO pins as outputs. Refer to your Lab 3 code.
// --------------------------------------------------------------------------------------------------------------

    li t2, 0x00FC0E3F
    sw t2, GPIO_OUTPUT_ENABLE(t0)
    li t2, 0xFF03F1C0
    sw t2, GPIO_OUTPUT(t0)

// --------------------------------------------------------------------------------------------------------------

// You need to configure the GPIO interrupt to trigger when S1 (GPIO pin 12) is on a falling edge.
// --------------------------------------------------------------------------------------------------------------

    li t1, 0x1000
    sw t1, GPIO_FALL_INTERRUPT_ENABLE(t0) // Enable falling edge interrupt for S1

// --------------------------------------------------------------------------------------------------------------

    // Enable PLIC for S1 interrupt  
    li t1, PLIC_BASE + PLIC_ENABLE         // Calculate address of PLIC interrupt enable register
    li t2, (1 << 20)                       // Set bit 20 for PLIC Interrupt Source ID = 20 (GPIO pin 12)
    sw t2, 0(t1)

    // Set PLIC priority for S1 interrupt  // Set PLIC priority 
    li t1, PLIC_BASE
    li t2, 4*(S1_PLIC_ID)                  // Calculate address of Interrupt Priority Regoster
    add t2, t2, t1
    li t3, S1_PRIORITY                     // Set interrup priority = 7
    sw t3, 0(t2)

    // Set PLIC threshold to 6 (allow all interrupts)
    li t1, PLIC_BASE + PLIC_THRESHOLD      // Calculate address of PLIC threshold register
    li t2, 6                               // Set threshold to 6.  Masks all interrups of priority 6 or less
    sw t2, 0(t1) 


// --------------------------------------------------------------------------------------------------------------
 
// Main Program: Keep looping, let the interrupt handle events

// Initialize random number generator
 	li a7, 0xABCD
    li a4, 0

main_program:

    jal LED_ON                      // LED ON
    jal LED_OFF                     // LED OFF
    jal RandomNum                   //  Generate random number
    mv a4, a7                       // Move random value into a4 from a7
    j main_program

LED_ON:
    addi sp, sp, -16
    sw ra, 12(sp)

    li t0, GPIO_BASE                  // Load Base Address for GPIO Control Registers
    lw t2, GPIO_OUTPUT(t0)            // Read current GPIO output values
    li t3, 0x00FC0C00                 // Mask for LEDs 23-18 and 11-10
    or t2, t2, t3                     // Turn ON LEDs 23-18 and 11-10
    sw t2, GPIO_OUTPUT(t0)            // Write modified value back to output register

    li a2, 1000                      // Delay duration
    jal ra, DELAY_mul       

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

LED_OFF:
    addi sp, sp, -16
    sw ra, 12(sp)

    li t0, GPIO_BASE                  // Load Base Address for GPIO Control Registers
    lw t2, GPIO_OUTPUT(t0)            // Read current GPIO output values
    li t3, 0x00FC0C00                 // Mask for LEDs 23-18 and 11-10
    not t3, t3                        // Invert mask to clear bits
    and t2, t2, t3                    // Turn OFF LEDs 23-18 and 11-10
    sw t2, GPIO_OUTPUT(t0)            // Write modified value back to output register

    li a2, 1000                      // Delay duration
    jal ra, DELAY_mul

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

// Random Number generator Subroutine
// Register a7 holds the random number.
// You can read this value anywhere in the code, but this register can only be written to by this subroutine
// Or Else!
RandomNum:

    addi sp, sp, -16
    sw ra, 12(sp)

    li s4, 0x8000		     // Load upper 20 bits
    and t1, a7, s4  		     // Mask to lower 16 bits
    li s4, 0x2000  		     // Load upper 20 bits
    and t3, a7, s4  		     // Mask to lower 16 bits

    slli t3, t3, 2
    xor t3, t1, t3
    li s4, 0x1000  		     // Load upper 20 bits
    and t1, a7, s4		     // Mask to lower 16 bits

    slli t1, t1, 3
    xor t3, t3, t1
    andi t1, a7, 0x0400
    slli t1, t1, 5
    xor t3, t3, t1
    srli t3, t3, 15
    slli a7, a7, 1
    or a7, a7, t3		     // Register a7 holds the random number

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

// --------------------------------------------------------------------------------------------------------------
// Interrupt Service Routine (ISR) for S1 interrupt
S1_interrupt:

    // Acknowledge the interrupt in the PLIC (write the IRQ number to PLIC claim/complete register)
    li t1, PLIC_BASE + PLIC_CLAIM          // Calculate address of PLIC claim/complete register
    lw t5, 0(t1)                           // Read the PLIC Interrupt ID

    // Scale random number and initialize countdown
    li t2, 200          
    remu a4, a4, t2      // Random Num modulus 200 (0-200)
    addi a4, a4, 50      // Random Num + 50 (50-250)

    // Delay loop subroutine
    DISPLAY_LOOP:

    jal DISPLAY

    // Decrement the counter 
    addi a4, a4, -10
    bgt a4, x0, DISPLAY_LOOP
    li a4, 0


// You need to clear the interrupt pending flag for S1 (GPIO pin 12). Refer to Appendix I in the lab manual
// --------------------------------------------------------------------------------------------------------------

    li t0, GPIO_BASE
    lw t1, 0(t0)
    li t2, (1 << 12)
    or t1, t1, t2
    sw t1, GPIO_FALL_INTERRUPT_PENDING(t0)

// --------------------------------------------------------------------------------------------------------------

    // Acknowledge interrupt in PLIC
    li t1, PLIC_BASE + PLIC_CLAIM
    sw t5, 0(t1)

end_interrupt:
    mret        // Return from interrupt

DISPLAY:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw t3, 8(sp)

    // Display countdown value on LEDs
    li t0, GPIO_BASE
    lw t4, GPIO_OUTPUT(t0)

    // Delay for 1 second
    // Bitmask for LEDS[23:18]
    andi t2, a4, 0xFC
    slli t2, t2, 16

    // Bitmask for LEDS[11:10]
    andi t3, a4, 0x3
    slli t3, t3, 10

    // Combine masks
    or t2, t2, t3

    // Mask inverse of LEDS
    li t3, 0xFF03F3FF

    // Set LEDS to 0 and keep original GPIO output values the same
    and t4, t4, t3

    // Apply the 8-bit LED number to the output
    or t4, t4, t2

    // Set to the GPIO output values (turn on the LEDS)
    sw t4, GPIO_OUTPUT(t0)

    li a2, 10000
    jal ra, DELAY_mul

    lw t3, 8(sp)
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

      

