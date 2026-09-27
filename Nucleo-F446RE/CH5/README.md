# CH5-EX1 — retargeting `printf()`/`scanf()` to USART2

Chapter 5 of *Mastering STM32*, on the NUCLEO-F446RE, built from the terminal
with the `Makefile` in this folder instead of STM32CubeIDE.

`Core/Src/retarget.c` implements the newlib system calls (`_write()`,
`_read()`, `_isatty()`, `_close()`, `_fstat()`) on top of `HAL_UART_*`, so the
standard streams go over USART2, which the on-board ST-LINK exposes to the PC
as a USB serial port. `Core/Src/main-ex1.c` calls `RetargetInit(&huart2)` and
then uses plain `printf()`/`scanf()`:

```
How many times to print the message?: 3

Hello, Nucleo: 1
Hello, Nucleo: 2
Hello, Nucleo: 3
```

## Prerequisites (Ubuntu)

```
sudo apt install gcc-arm-none-eabi make openocd picocom
```

- `gcc-arm-none-eabi` — compiler and newlib (the C library `printf` comes from)
- `openocd` — programs the board through the ST-LINK; also installs the udev
  rule that lets a normal user open it (unplug/replug the board after installing)
- `picocom` — serial terminal; any other one works too (`screen`, `minicom`, `tio`)

To use the serial port without `sudo`, add yourself to the `dialout` group once
and log in again: `sudo usermod -aG dialout $USER`.

## Connect the board

Plug the Nucleo into the PC with the USB cable on the ST-LINK end of the board
(it powers the board too) and confirm it is seen:

```
lsusb | grep 0483     # ST-LINK: "0483:374b STMicroelectronics ST-LINK/V2.1"
ls /dev/ttyACM*       # its serial port, normally /dev/ttyACM0
```

## Build and flash

```
cd Nucleo-F446RE/CH5
make          # optional sanity check: build build/CH5.elf and print its size, no board needed
make flash    # make sure build/CH5.elf is up to date (rebuilds if not), then program the board over the ST-LINK with OpenOCD
make clean    # optional: delete the build/ folder (git ignores it anyway)
```

The Makefile compiles and links everything in one gcc call, with the same flags
as the CubeIDE `CH5-EX1` configuration (Cortex-M4, hard-float FPU, `-O0 -g3`,
newlib-nano). It rebuilds everything each time, which takes a few seconds.

`make flash` runs
`openocd -f board/st_nucleo_f4.cfg -c "program build/CH5.elf verify reset exit"`.
A good run ends with `** Verified OK **`, `** Resetting Target **` and
`shutdown command invoked`. The previous firmware is simply overwritten; no
erase step is needed. The link warning `_lseek is not implemented` is expected
(CubeIDE prints it too).

## Run

1. Open the terminal at 115200 baud, 8N1, with local echo (the firmware does
   not echo what you type):

   ```
   picocom -b 115200 --echo /dev/ttyACM0
   ```

2. Press the black **RESET** button (B2) on the board. The prompt is printed
   once, right after start-up, so it is lost if the terminal was not open yet;
   RESET restarts the program while the terminal is listening.

3. Type a number and press Enter. `scanf("%hhu")` stores it in a `uint8_t`, so
   `0` ends immediately and `300` gives 44 (300 mod 256) messages.

4. The program then sits in `while(1);`. Press RESET to run it again.

Leave picocom with Ctrl-A then Ctrl-X (Ctrl-C is sent to the board, not to
picocom).

The program lives in flash, so after a power cycle the board boots straight
into it; `make flash` is only needed again after changing the code.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `cannot open /dev/ttyACM0: Permission denied` | `dialout` group (see above), or `sudo picocom …` once |
| OpenOCD cannot open the ST-LINK | `lsusb` must list `0483:374b`; replug the board after installing `openocd` |
| No prompt in the terminal | press RESET again; or just type a number and Enter — the program is already waiting in `scanf()` |
| OpenOCD cannot connect at all | hold RESET while `make flash` starts (only happens if the old firmware disabled SWD or sleeps immediately) |
