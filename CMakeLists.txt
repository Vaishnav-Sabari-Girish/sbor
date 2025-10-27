# Minimum CMake version
cmake_minimum_required(VERSION 3.15)

# Project definition
project(sbor
    VERSION 0.1.7
    DESCRIPTION "C Project Manager and Package Manager"
    LANGUAGES C
)

# Set C standard
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Set default build type to Release if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Source files (updated for new structure)
set(SOURCES
    src/main.c
    src/commands/init.c
    src/core/templates.c
    src/commands/build.c
    src/commands/run.c
    src/commands/clean.c
    src/commands/add.c
    src/commands/remove.c
    src/core/utils.c
    src/commands/stubs.c
    # Add more .c files here as needed
    # Future: src/commands/init.c
    # Future: src/commands/add.c
    # Future: src/core/utils.c
)

# Create executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Include directories (added for new structure)
target_include_directories(${PROJECT_NAME} PRIVATE
    src
    src/include  # For future header files
)

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

# Auto-cleanup: Remove all build artifacts except the executable
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Cleaning up build artifacts..."
    
    # Remove CMake generated files
    COMMAND ${CMAKE_COMMAND} -E remove -f 
        ${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt
        ${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/Makefile
        ${CMAKE_CURRENT_BINARY_DIR}/*.cbp
        ${CMAKE_CURRENT_BINARY_DIR}/*.vcxproj*
        ${CMAKE_CURRENT_BINARY_DIR}/*.sln
    
    # Remove CMakeFiles directory
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles
    
    # Remove object files and intermediate files
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.dir
    
    # Remove other build artifacts (adjust extensions as needed)
    COMMAND ${CMAKE_COMMAND} -E remove -f 
        ${CMAKE_CURRENT_BINARY_DIR}/*.o
        ${CMAKE_CURRENT_BINARY_DIR}/*.obj
        ${CMAKE_CURRENT_BINARY_DIR}/*.pdb
        ${CMAKE_CURRENT_BINARY_DIR}/*.ilk
        ${CMAKE_CURRENT_BINARY_DIR}/*.lib
        ${CMAKE_CURRENT_BINARY_DIR}/*.exp
    
    COMMAND ${CMAKE_COMMAND} -E echo "Cleanup complete! Only sbor executable remains."
    COMMENT "Auto-cleaning build artifacts after successful build"
)

# Alternative: Create a manual cleanup target (optional)
add_custom_target(clean-build
    COMMAND ${CMAKE_COMMAND} -E echo "Manual cleanup initiated..."
    
    # Keep the executable but remove everything else
    COMMAND ${CMAKE_COMMAND} -E remove -f 
        ${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt
        ${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake  
        ${CMAKE_CURRENT_BINARY_DIR}/Makefile
        ${CMAKE_CURRENT_BINARY_DIR}/*.cbp
        ${CMAKE_CURRENT_BINARY_DIR}/*.vcxproj*
        ${CMAKE_CURRENT_BINARY_DIR}/*.sln
        ${CMAKE_CURRENT_BINARY_DIR}/*.o
        ${CMAKE_CURRENT_BINARY_DIR}/*.obj
        ${CMAKE_CURRENT_BINARY_DIR}/*.pdb
        ${CMAKE_CURRENT_BINARY_DIR}/*.ilk
    
    COMMAND ${CMAKE_COMMAND} -E rm -rf 
        ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles
        ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.dir
    
    COMMAND ${CMAKE_COMMAND} -E echo "Manual cleanup complete!"
    COMMENT "Manually clean all build artifacts except executable"
)

# Cross-platform executable detection for cleanup
if(WIN32)
    set(EXECUTABLE_NAME "${PROJECT_NAME}.exe")
else()
    set(EXECUTABLE_NAME "${PROJECT_NAME}")
endif()

# Print build information
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C standard: ${CMAKE_C_STANDARD}")
message(STATUS "Executable will be: ${EXECUTABLE_NAME}")
message(STATUS "Source directory: src/")
message(STATUS "Auto-cleanup enabled: Build artifacts will be removed after successful build")
