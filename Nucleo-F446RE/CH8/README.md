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
