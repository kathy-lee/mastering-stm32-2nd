# CMake toolchain file for the GNU Arm Embedded toolchain (arm-none-eabi-gcc),
# with the same MCU flags as the STM32CubeIDE project (Cortex-M4F, hard-float ABI).
set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

set(TOOLCHAIN_PREFIX                arm-none-eabi-)
set(CMAKE_C_COMPILER                ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_ASM_COMPILER              ${CMAKE_C_COMPILER})
set(CMAKE_OBJCOPY                   ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_SIZE                      ${TOOLCHAIN_PREFIX}size)

set(CMAKE_EXECUTABLE_SUFFIX_C       ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_ASM     ".elf")

# The compiler check must not try to link a bare-metal executable
set(CMAKE_TRY_COMPILE_TARGET_TYPE   STATIC_LIBRARY)

set(TARGET_FLAGS "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard")

set(CMAKE_C_FLAGS           "${TARGET_FLAGS} -Wall -ffunction-sections -fdata-sections --specs=nano.specs")
set(CMAKE_C_FLAGS_DEBUG     "-O0 -g3")
set(CMAKE_C_FLAGS_RELEASE   "-Os -g0")
set(CMAKE_ASM_FLAGS         "${CMAKE_C_FLAGS} -x assembler-with-cpp")
set(CMAKE_ASM_FLAGS_DEBUG   "-g3")
set(CMAKE_ASM_FLAGS_RELEASE "-g0")

# The C flags above (MCU flags, nano.specs) are passed to the link step too.
set(CMAKE_EXE_LINKER_FLAGS  "--specs=nosys.specs -static -Wl,--gc-sections -Wl,--print-memory-usage")
