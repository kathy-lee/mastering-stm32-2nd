# CH5-EX1 on the NUCLEO-F446RE:  make | make flash | make clean

CC  = arm-none-eabi-gcc
MCU = -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard

SRCS = $(wildcard Core/Src/*.c) $(wildcard Drivers/STM32F4xx_HAL_Driver/Src/*.c) \
       Core/Startup/startup_stm32f446retx.s
INCS = Core/Inc Drivers/STM32F4xx_HAL_Driver/Inc Drivers/STM32F4xx_HAL_Driver/Inc/Legacy \
       Drivers/CMSIS/Device/ST/STM32F4xx/Include Drivers/CMSIS/Include

CFLAGS  = $(MCU) -O0 -g3 -Wall -ffunction-sections -fdata-sections \
          -DUSE_HAL_DRIVER -DSTM32F446xx -DDEBUG $(addprefix -I,$(INCS))
LDFLAGS = -TSTM32F446RETX_FLASH.ld -specs=nano.specs -specs=nosys.specs -Wl,--gc-sections -Wl,-Map=build/CH5.map

build/CH5.elf: $(SRCS) STM32F446RETX_FLASH.ld Makefile
	@mkdir -p build
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@
	arm-none-eabi-size $@

flash: build/CH5.elf
	openocd -f board/st_nucleo_f4.cfg -c "program $< verify reset exit"

clean:
	rm -rf build

.PHONY: flash clean
