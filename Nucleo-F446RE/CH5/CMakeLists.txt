cmake_minimum_required(VERSION 3.22)

# Build with the presets in CMakePresets.json (they select the toolchain file):
#   cmake --preset Debug
#   cmake --build --preset Debug
project(CH5 LANGUAGES C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif()

file(GLOB SOURCES CONFIGURE_DEPENDS
  Core/Src/*.c
  Core/Startup/*.s
  Drivers/STM32F4xx_HAL_Driver/Src/*.c)

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE
  Core/Inc
  Drivers/STM32F4xx_HAL_Driver/Inc
  Drivers/STM32F4xx_HAL_Driver/Inc/Legacy
  Drivers/CMSIS/Device/ST/STM32F4xx/Include
  Drivers/CMSIS/Include)

target_compile_definitions(${PROJECT_NAME} PRIVATE
  USE_HAL_DRIVER
  STM32F446xx
  $<$<CONFIG:Debug>:DEBUG>)

set(LINKER_SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/STM32F446RETX_FLASH.ld)
target_link_options(${PROJECT_NAME} PRIVATE
  -T${LINKER_SCRIPT}
  -Wl,-Map=${PROJECT_NAME}.map)
set_target_properties(${PROJECT_NAME} PROPERTIES LINK_DEPENDS ${LINKER_SCRIPT})

target_link_libraries(${PROJECT_NAME} PRIVATE m)

# Optional: `cmake --build --preset Debug --target flash` programs the board over
# the ST-LINK with whichever programmer is on the PATH.
find_program(STM32_PROGRAMMER STM32_Programmer_CLI)
find_program(OPENOCD openocd)
if(STM32_PROGRAMMER)
  add_custom_target(flash DEPENDS ${PROJECT_NAME} USES_TERMINAL VERBATIM
    COMMAND ${STM32_PROGRAMMER} -c port=SWD -w $<TARGET_FILE:${PROJECT_NAME}> -v -rst)
elseif(OPENOCD)
  # Braces keep the path as one Tcl word even if it contains spaces
  add_custom_target(flash DEPENDS ${PROJECT_NAME} USES_TERMINAL VERBATIM
    COMMAND ${OPENOCD} -f board/st_nucleo_f4.cfg -c "program {$<TARGET_FILE:${PROJECT_NAME}>} verify reset exit")
endif()
