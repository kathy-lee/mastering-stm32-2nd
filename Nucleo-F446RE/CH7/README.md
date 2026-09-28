# CH7 — Interrupts management: EXTI on the NUCLEO-F446RE

Three experiments, each with its own `Core/Src/main-exN.c`(N=1,2,3). They share the same `Makefile`, the build command takes the example number as an input variable `EX` like: `make EX=1 flash`. Each builds `build/CH7-EX<n>.elf` and programs it with OpenOCD, as in CH5.
No serial terminal is needed in this chapter: everything is button, LED and
one jumper wire. The harmless compiler warning about `MX_GPIO_Init` in
`main-ex1.c` is a leftover prototype in the book's code.

Board facts used throughout (Nucleo-64 user manual UM1724,
<https://www.st.com/resource/en/user_manual/um1724-stm32-nucleo64-boards-mb1136-stmicroelectronics.pdf>):

| signal | where |
|---|---|
| PC13 | blue USER button B1 — pulled up, so **releasing** it gives the rising edge |
| PA5 | green LED LD2 |
| PC12 | Morpho header CN7 pin 3 (free pin, nothing on the board) |
| PB2 | Morpho header CN10 pin 22 (free pin, nothing on the board) |
| 3V3 | CN7 pin 16 (or the Arduino power header CN6) |
| GND | CN10 pin 20, CN10 pin 9, or any other GND pin — they are all the same net |

Morpho headers: CN7 is the left, CN10 the right double-row header with the USB
connector at the top; pin 1 is top-left, odd pins in the outer column, even
pins in the inner column, counting down. Pin names are printed on the board.

## Example 1 — a bare ISR (`main-ex1.c`)

PC13 is configured as `GPIO_MODE_IT_RISING`, `EXTI15_10_IRQn` is enabled, and
`EXTI15_10_IRQHandler()` checks that PC13 fired, toggles PA5 and clears the
pending bit by hand.

1. `cd Nucleo-F446RE/CH7`
2. `make EX=1 flash`
3. Press and release the blue button: LD2 toggles on each **release**. An
   occasional double toggle is contact bounce — real, and dealt with later in
   the book.
4. `make clean`          # optional: delete the build/ folder

## Example 2 — two pins on one EXTI line, through the HAL (`main-ex2.c`)

PC13 and PC12 are both rising-edge interrupt sources (PC12 with an internal
pull-down) on the shared `EXTI15_10` line. The ISR delegates to
`HAL_GPIO_EXTI_IRQHandler()` for each pin, and the HAL calls
`HAL_GPIO_EXTI_Callback(pin)`: PC13 turns LD2 **on**, PC12 turns it **off**.

1. `cd Nucleo-F446RE/CH7`
2. `make EX=2 flash`
3. Press and release the blue button: LD2 goes on and stays on.
4. Plug a jumper wire into 3V3 and touch its free end to PC12 (CN7 pin 3):
   the rising edge turns LD2 off.
5. Back to step 3 to repeat (no re-flash needed).

## Example 3 — interrupt priorities (`main-ex3.c`)

Two interrupt sources with different priorities (lower number = more urgent):

- PC13, rising edge, `EXTI15_10_IRQn` at priority **1**
- PB2, falling edge with internal pull-up, `EXTI2_IRQn` at priority **0**

The callback for PC13 deliberately never returns: it loops, blinking LD2,
until `blink` is cleared. Only a *higher*-priority interrupt can break in.

1. `cd Nucleo-F446RE/CH7`
2. `make EX=3 flash` — LD2 is off, nothing happens yet.
3. Press and release the blue button: LD2 starts blinking fast. The CPU is now
   trapped inside the priority-1 interrupt handler; `main()` never runs again.
4. Press the blue button again: **no effect** — an interrupt of the same
   priority cannot pre-empt the running one.
5. Plug a jumper wire into GND (CN10 pin 20) and touch its free end to PB2
   (CN10 pin 22): the falling edge fires the priority-0 `EXTI2` interrupt,
   which pre-empts the running handler and sets `blink = 0`. The blinking
   stops.
6. Back to step 3 to repeat (no re-flash needed).


Things to try: swap the two priorities and see that PB2 no longer stops the
blinking; check that `blink` is declared `volatile` — without it the compiler
could keep the flag in a register and the loop would never see the change.
