# CH8 — UART: management console on the NUCLEO-F446RE

The examples each have their own `Core/Src/main-exN.c`. The shared `Makefile`
takes the example number as `EX` (default 1); `Core/Src/main.c` is the empty
CubeMX template and is not built.

```
cd Nucleo-F446RE/CH8
make EX=1 flash     # or just: make flash
make EX=2 flash
make EX=3 flash
make clean          # optional: delete the build/ folder
```

Each builds `build/CH8-EX<n>.elf` and programs it with OpenOCD, as in CH5.
These examples talk to the PC over USART2 (PA2/PA3, the ST-LINK virtual COM
port) at 115200 8N1, so a serial terminal is needed.

Unlike CH5 they do not use `printf()`/`scanf()`: text is formatted with
`sprintf()` into a buffer and sent with `HAL_UART_Transmit()`, input is read
with `HAL_UART_Receive()` — the HAL called directly, no retargeting.

## Example 1 — a blocking console (`main-ex1.c`)

Prints a welcome screen and a menu, then loops: `HAL_UART_Receive()` blocks
until one byte arrives, `atoi()` turns it into a number, and a `switch` acts
on it. Options: `1` toggles LD2, `2` prints the USER button state, `3` clears
the screen and prints the menu again.

1. `cd Nucleo-F446RE/CH8`
2. `make EX=1 flash`
3. Open the terminal **without local echo** — the program echoes the digit
   itself, with `--echo` you would see it twice:

   ```
   picocom -b 115200 /dev/ttyACM0
   ```

   A few garbage characters right after `Terminal ready` are normal: stray
   bytes from the moment the port opens, or the tail of output the board sent
   before the terminal was listening.
4. Press the black RESET button. The screen clears (`\033[0;0H` and
   `\033[2J` are VT100 "cursor home" and "clear screen", which picocom
   understands) and the menu appears:

   ```
   Welcome to the Nucleo management console
   Select the option you are interested in:
       1. Toggle LD2 LED
       2. Read USER BUTTON status
       3. Clear screen and print this message
   >
   ```
5. Type `1`, `2` or `3` — one key, no Enter, since the program reads exactly
   one byte. `1` toggles LD2; `2` prints `USER BUTTON status: PRESSED` or
   `RELEASED` (hold the blue button while typing `2` to see PRESSED); `3`
   redraws the menu.
6. Any other key (`8`, `0`, a letter) does nothing but print a new prompt:
   `processUserInput()` returns 0 for `!opt || opt > 3` before echoing the
   digit, and `main()` just loops.

Leave picocom with Ctrl-A then Ctrl-X.

Side note on the code: `readBuf` is `char readBuf[1]` with no terminating
`'\0'`, and `atoi()` expects a C string. It works because `atoi()` stops at
the first non-digit byte and the next byte on the stack is normally not a
digit — sloppy, but harmless here.

## Example 3 — the same console, interrupt-driven (`main-ex3.c`)

Same menu and behaviour as example 1, but `main()` never blocks on the UART,
so it can keep doing other work (`performCriticalTasks()`, here just
`HAL_Delay(100)` standing in for real work).

- **Input**: `readUserInput()` arms `HAL_UART_Receive_IT()` for one byte and
  returns immediately. When the byte arrives, `USART2_IRQHandler()` →
  `HAL_UART_IRQHandler()` → `HAL_UART_RxCpltCallback()` sets `UartReady`; the
  next loop pass picks the key up. `UartReady` is `__IO` (`volatile`) because
  it is shared with the ISR — the CH7 lesson.
- **Output**: `UART_Transmit()` tries `HAL_UART_Transmit_IT()`; while the UART
  is still busy it returns `HAL_BUSY` and the bytes go into a ring buffer
  (`txBuf`, `ringbuffer.c`). `HAL_UART_TxCpltCallback()` then feeds the next
  byte from the buffer, so the menu's five strings are sent from interrupts
  while `main()` carries on.

Why it matters: at 115200 baud the ~200-byte welcome screen takes ~17 ms to
send. Example 1 sits in `HAL_UART_Transmit()` for those 17 ms, then in
`HAL_UART_Receive()` until a key is pressed — frozen between keys. Example 3
returns from `printWelcomeMessage()` in microseconds and `performCriticalTasks()`
runs every 100 ms regardless of the UART.

1. `cd Nucleo-F446RE/CH8`
2. `make EX=3 flash`
3. `picocom -b 115200 /dev/ttyACM0` (no `--echo`), press RESET, use the keys
   `1`/`2`/`3` as in example 1. It looks the same — that is the point. A key
   is acted on up to 100 ms later, since input is polled once per loop pass.

To *see* the difference: add `HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);` inside
`performCriticalTasks()` as a 5 Hz heartbeat. In example 3 the blink never
stutters however much text is being sent; put the same line in example 1's
loop and the LED stops whenever the program waits in `HAL_UART_Receive()`.

Changes made to the book's code here: `RingBuffer_Init(&txBuf)` is now called
explicitly in `main()` (the original relied on the global being
zero-initialised, which happens to give the same `head = tail = 0`), and the
unused `rxBuf` declaration was removed.

## Example 4 — both directions through ring buffers (`main-ex4-my.c`, my own)

Not from the book: a rework of example 3 that uses a ring buffer on the
receive side too, and fixes two things in the original.

- **Receive**: `HAL_UART_Receive_IT()` is armed once before the loop and
  re-armed in `HAL_UART_RxCpltCallback()`, which copies each byte into
  `rxBuf`. `readUserInput()` takes bytes from `rxBuf` and returns the digit
  (`1`..`9`) or `0` if nothing useful is waiting. `readBuf` and the `UartReady`
  flag are gone. Keys typed faster than the 100 ms loop are queued instead of
  lost — type `13` quickly: example 3 usually acts on only one of them, this
  one on both.
- **Transmit**: `UART_Transmit()` always copies into `txBuf` and starts the
  transmitter only if it is idle (`huart->gState == HAL_UART_STATE_READY`);
  `HAL_UART_TxCpltCallback()` drains the rest one byte at a time. The
  original version (kept in a comment) handed a caller's buffer straight to
  `HAL_UART_Transmit_IT()`, which keeps reading from it in the background
  after the caller has returned — unsafe for a stack array such as `msg[30]`
  in `processUserInput()` (string literals, as in `printWelcomeMessage()`,
  live in flash and are fine).

Build and run exactly like example 3; from the terminal it behaves the same:

```
make EX=4-my flash
picocom -b 115200 /dev/ttyACM0
```
