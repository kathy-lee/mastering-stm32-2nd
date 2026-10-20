# CH9 — DMA: USART2 transmit on the NUCLEO-F446RE

Two examples, each with its own `Core/Src/main-exN.c`. The shared `Makefile`
takes the example number as `EX` (default 2):

```
cd Nucleo-F446RE/CH9
make EX=1 flash
make EX=2 flash     # or just: make flash
make clean          # optional: delete the build/ folder
```

Each builds `build/CH9-EX<n>.elf` and programs it with OpenOCD, as in CH5.
Both send one line over USART2 (PA2/PA3, the ST-LINK virtual COM port) at
115200 8N1, so a serial terminal is needed.

## What both examples share

The string `msg` lives in RAM. Instead of the CPU writing it byte by byte into
the UART data register (what `HAL_UART_Transmit()` does), the DMA controller
does it:

- **Stream/channel**: on the F446 the USART2 TX request is wired to
  **DMA1 Stream 6, Channel 4** (reference manual RM0390, table "DMA1 request
  mapping"). This is fixed in hardware, not a free choice.
- **Direction** `DMA_MEMORY_TO_PERIPH`, memory address increments
  (`MINC_ENABLE`), peripheral address does not (`PINC_DISABLE`): source is
  `msg`, destination is always `USART2->DR`. Both sides are byte-wide.
- `DMA_NORMAL` mode: one shot of `strlen(msg)` bytes, then the stream stops.
- `HAL_DMA_Start[_IT]()` only arms the DMA. Nothing moves until the UART asks
  for data, which happens when the **DMAT** bit in `USART2->CR3` is set: from
  then on every time the TX register is empty the UART raises a DMA request
  and one byte is copied. That is why the code sets `CR3 |= USART_CR3_DMAT`
  *after* starting the DMA, and clears it when the transfer is done.
- `MX_DMA_Init()` just turns on the DMA1 clock. The stream itself is set up
  in `main()` by filling `hdma_usart2_tx.Init` and calling `HAL_DMA_Init()`.

## Example 1 — polling (`main-ex1.c`)

`HAL_DMA_Start()` arms the stream, DMAT is set, then
`HAL_DMA_PollForTransfer(..., HAL_DMA_FULL_TRANSFER, HAL_MAX_DELAY)` spins
until the transfer-complete flag of stream 6 is set. After that DMAT is
cleared and LD2 is lit.

The CPU is free of the byte-copying work, but it still waits: this is
equivalent to a blocking `HAL_UART_Transmit()` from the program's point of
view.

1. `cd Nucleo-F446RE/CH9`
2. `make EX=1 flash`
3. Open the terminal:

   ```
   picocom -b 115200 /dev/ttyACM0
   ```

4. Press the black RESET button (the blue one is the USER button, unused
   here). One line appears and LD2 turns on:

   ```
   Hello STM32 Lovers! This message is transferred in DMA Mode.
   ```

   The message is sent once per reset, so if the terminal was opened after
   `make flash` finished, press RESET again to see it.

Leave picocom with Ctrl-A then Ctrl-X.

## Example 2 — interrupt on completion (`main-ex2.c`)

Same stream setup, with three differences:

- `hdma_usart2_tx.XferCpltCallback = &DMATransferComplete;` registers a
  function the HAL will call when the stream finishes.
- `DMA1_Stream6_IRQn` is enabled in the NVIC and `HAL_DMA_Start_IT()` is used
  instead of `HAL_DMA_Start()`, so the stream raises its transfer-complete
  interrupt. `DMA1_Stream6_IRQHandler()` in `stm32f4xx_it.c` calls
  `HAL_DMA_IRQHandler(&hdma_usart2_tx)`, which clears the flag and runs the
  registered callback.
- `main()` falls straight through to `while (1);` — no polling. The callback
  checks `hdma->Instance == DMA1_Stream6`, clears DMAT and turns LD2 on.

1. `cd Nucleo-F446RE/CH9`
2. `make EX=2 flash` (or just `make flash`, since `EX` defaults to 2)
3. `picocom -b 115200 /dev/ttyACM0`
4. Press the black RESET button. One line appears and LD2 turns on:

   ```
   Hello STM32 Lovers! This message is transferred in DMA-Interrupt Mode.
   ```

Leave picocom with Ctrl-A then Ctrl-X.

From the terminal both look the same. The difference is where the CPU is
while the ~60 bytes go out (about 5 ms at 115200 baud): in example 1 it is
stuck in `HAL_DMA_PollForTransfer()`, in example 2 it is already in the main
loop and could do other work, the same step as CH8's example 1 → example 3,
but now even the per-byte interrupts are gone — only one interrupt at the end.

To see it: put `HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5); HAL_Delay(50);` inside
example 2's `while (1)` — the LED blinks while the message is still being
sent (make the message longer, or lower the baud rate, to make the overlap
noticeable).

Note: this chapter drives the DMA and the UART's DMAT bit by hand to show the
mechanism. The normal HAL way is `HAL_UART_Transmit_DMA()`, which does the
same (link the DMA handle with `__HAL_LINKDMA`, start it, set DMAT) and calls
`HAL_UART_TxCpltCallback()` when done.
