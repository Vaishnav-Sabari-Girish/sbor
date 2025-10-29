# Minimum CMake version
cmake_minimum_required(VERSION 3.15)

# Project definition
project(sbor
    VERSION 0.1.8
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
)

# Create executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE
    src
    src/include
)

# Cross-platform compiler flags
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

# Windows-specific configurations
if(WIN32)
    # Add Windows-specific definitions
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        _WIN32_WINNT=0x0600  # Windows Vista and later
        WIN32_LEAN_AND_MEAN  # Exclude rarely used APIs
        _CRT_SECURE_NO_WARNINGS  # Disable MSVC security warnings
    )
    
    # Link with Windows-specific libraries if needed
    # target_link_libraries(${PROJECT_NAME} PRIVATE kernel32 user32)
    
    set(EXECUTABLE_NAME "${PROJECT_NAME}.exe")
else()
    set(EXECUTABLE_NAME "${PROJECT_NAME}")
endif()

# Cross-platform auto-cleanup function
function(add_cleanup_commands target_name)
    if(WIN32)
        # Windows cleanup commands
        add_custom_command(TARGET ${target_name} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "Cleaning up build artifacts..."
            
            # Remove CMake generated files (Windows compatible)
            COMMAND ${CMAKE_COMMAND} -E remove -f 
                "${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt"
                "${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake"
                "${CMAKE_CURRENT_BINARY_DIR}/ALL_BUILD.vcxproj"
                "${CMAKE_CURRENT_BINARY_DIR}/ALL_BUILD.vcxproj.filters"
                "${CMAKE_CURRENT_BINARY_DIR}/ZERO_CHECK.vcxproj"
                "${CMAKE_CURRENT_BINARY_DIR}/ZERO_CHECK.vcxproj.filters"
                "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.vcxproj"
                "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.vcxproj.filters"
                "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.sln"
            
            # Remove CMakeFiles directory
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles"
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.dir"
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/x64"
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/Win32"
            
            # Remove Windows-specific build artifacts
            COMMAND ${CMAKE_COMMAND} -E remove -f 
                "${CMAKE_CURRENT_BINARY_DIR}/*.pdb"
                "${CMAKE_CURRENT_BINARY_DIR}/*.ilk"
                "${CMAKE_CURRENT_BINARY_DIR}/*.lib"
                "${CMAKE_CURRENT_BINARY_DIR}/*.exp"
                "${CMAKE_CURRENT_BINARY_DIR}/*.obj"
            
            COMMAND ${CMAKE_COMMAND} -E echo "Windows cleanup complete! Only ${EXECUTABLE_NAME} remains."
            COMMENT "Auto-cleaning Windows build artifacts after successful build"
        )
    else()
        # Unix/Linux cleanup commands  
        add_custom_command(TARGET ${target_name} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "Cleaning up build artifacts..."
            
            # Remove CMake generated files
            COMMAND ${CMAKE_COMMAND} -E remove -f 
                "${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt"
                "${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake"
                "${CMAKE_CURRENT_BINARY_DIR}/Makefile"
            
            # Remove CMakeFiles directory
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles"
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles"
            
            # Remove object files
            COMMAND ${CMAKE_COMMAND} -E remove -f 
                "${CMAKE_CURRENT_BINARY_DIR}/*.o"
                "${CMAKE_CURRENT_BINARY_DIR}/*.a"
            
            COMMAND ${CMAKE_COMMAND} -E echo "Unix cleanup complete! Only ${EXECUTABLE_NAME} remains."
            COMMENT "Auto-cleaning Unix build artifacts after successful build"
        )
    endif()
endfunction()

# Apply cleanup commands
add_cleanup_commands(${PROJECT_NAME})

# Cross-platform manual cleanup target
if(WIN32)
    add_custom_target(clean-build
        COMMAND ${CMAKE_COMMAND} -E echo "Manual Windows cleanup initiated..."
        COMMAND ${CMAKE_COMMAND} -E remove -f 
            "${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt"
            "${CMAKE_CURRENT_BINARY_DIR}/*.vcxproj*"
            "${CMAKE_CURRENT_BINARY_DIR}/*.sln"
            "${CMAKE_CURRENT_BINARY_DIR}/*.pdb"
            "${CMAKE_CURRENT_BINARY_DIR}/*.ilk"
            "${CMAKE_CURRENT_BINARY_DIR}/*.obj"
        COMMAND ${CMAKE_COMMAND} -E rm -rf 
            "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles"
            "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.dir"
            "${CMAKE_CURRENT_BINARY_DIR}/x64"
            "${CMAKE_CURRENT_BINARY_DIR}/Win32"
        COMMAND ${CMAKE_COMMAND} -E echo "Windows manual cleanup complete!"
        COMMENT "Manually clean all Windows build artifacts except executable"
    )
else()
    add_custom_target(clean-build
        COMMAND ${CMAKE_COMMAND} -E echo "Manual Unix cleanup initiated..."
        COMMAND ${CMAKE_COMMAND} -E remove -f 
            "${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt"
            "${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake"  
            "${CMAKE_CURRENT_BINARY_DIR}/Makefile"
            "${CMAKE_CURRENT_BINARY_DIR}/*.o"
        COMMAND ${CMAKE_COMMAND} -E rm -rf 
            "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles"
        COMMAND ${CMAKE_COMMAND} -E echo "Unix manual cleanup complete!"
        COMMENT "Manually clean all Unix build artifacts except executable"
    )
endif()

# Print build information
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C standard: ${CMAKE_C_STANDARD}")
message(STATUS "Target platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Executable will be: ${EXECUTABLE_NAME}")
message(STATUS "Source directory: src/")
message(STATUS "Auto-cleanup enabled: Build artifacts will be removed after successful build")

# Additional Windows-specific information
if(WIN32)
    message(STATUS "Windows build detected - Using MSVC-compatible settings")
    if(MSVC)
        message(STATUS "MSVC version: ${MSVC_VERSION}")
    endif()
endif()
