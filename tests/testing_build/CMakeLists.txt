# Minimum CMake version
cmake_minimum_required(VERSION 3.15)

# Project definition
project(testing_build
    VERSION 1.0.0
    DESCRIPTION "A C project created with sbor"
    LANGUAGES C
)

# Set C standard
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Set default build type to Release if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Source files
set(SOURCES
    src/main.c
    # Add more .c files here as needed
)

# Create executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE src)

# Compiler flags
target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<C_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
    $<$<C_COMPILER_ID:MSVC>:/W4>
    
    $<$<CONFIG:Debug>:
        $<$<C_COMPILER_ID:GNU,Clang>:-g -O0>
        $<$<C_COMPILER_ID:MSVC>:/Od /Zi>
    >
    
    $<$<CONFIG:Release>:
        $<$<C_COMPILER_ID:GNU,Clang>:-O3 -DNDEBUG>
        $<$<C_COMPILER_ID:MSVC>:/O2 /DNDEBUG>
    >
)

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C compiler: ${CMAKE_C_COMPILER}")
