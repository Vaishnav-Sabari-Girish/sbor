#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>

// Cross-platform directory and execution
#ifdef _WIN32
  #include <direct.h>
  #define chdir _chdir                    
  #define PATH_SEPARATOR "\\"             
  #define EXE_EXTENSION ".exe"
#else
  #include <sys/types.h>
  #define PATH_SEPARATOR "/"               
  #define EXE_EXTENSION ""
#endif

#include "../include/commands.h"

// Reuse the build function
extern int cmd_build(int argc, char *argv[]);

// Helper function to find the executable in build directory
char* find_executable() {
    DIR *dir = opendir("build");
    if (!dir) {
        return NULL;
    }
    
    struct dirent *entry;
    char *exe_path = NULL;
    
    while ((entry = readdir(dir)) != NULL) {
        // Skip . and .. and CMake files
        if (strcmp(entry->d_name, ".") == 0 || 
            strcmp(entry->d_name, "..") == 0 ||
            strstr(entry->d_name, "CMake") != NULL ||
            strstr(entry->d_name, "Makefile") != NULL ||
            strcmp(entry->d_name, "cmake_install.cmake") == 0) {
            continue;
        }
        
        // Check if it's a regular file (not a directory)
        char full_path[512];
        snprintf(full_path, sizeof(full_path), "build/%s", entry->d_name);
        
        struct stat file_stat;
        if (stat(full_path, &file_stat) == 0 && S_ISREG(file_stat.st_mode)) {
            // On Unix systems, check if it's executable
            #ifndef _WIN32
            if (file_stat.st_mode & S_IXUSR) {
            #endif
                exe_path = malloc(strlen(full_path) + 1);
                strcpy(exe_path, full_path);
                break;  // Don't print here - let caller decide
            #ifndef _WIN32
            }
            #endif
        }
    }
    
    closedir(dir);
    return exe_path;
}

// Execute the binary with enhanced visual formatting
int execute_binary_verbose(const char *exe_path, int argc, char *argv[]) {
    printf("🎯 Found executable: %s\n", exe_path);
    printf("🚀 Running: %s", exe_path);

    // Print arguments if any
    if (argc > 0) {
        printf(" ");
        for (int i = 0; i < argc; i++) {
            printf("%s ", argv[i]);
        }
    }
    printf("\n\n");

    // Build the command string
    char command[1024];
    snprintf(command, sizeof(command), ".%s%s", PATH_SEPARATOR, exe_path);

    // Add arguments to command
    for (int i = 0; i < argc; i++) {
        strcat(command, " ");
        strcat(command, argv[i]);
    }

    // Enhanced visual separator
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                     PROGRAM OUTPUT                        ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("\n");

    // Execute the command
    int result = system(command);

    printf("\n");
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                      END OUTPUT                           ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");

    #ifdef _WIN32
        int exit_code = result;
    #else
        int exit_code = WIFEXITED(result) ? WEXITSTATUS(result) : -1;
    #endif

    if (exit_code == 0) {
        printf("✅ Program completed successfully (exit code: %d)\n", exit_code);
    } else {
        printf("❌ Program exited with error (exit code: %d)\n", exit_code);
    }

    return exit_code;
}

// Execute binary in quiet mode (minimal output)
int execute_binary_quiet(const char *exe_path, int argc, char *argv[]) {
    // Build the command string
    char command[1024];
    snprintf(command, sizeof(command), ".%s%s", PATH_SEPARATOR, exe_path);

    // Add arguments to command
    for (int i = 0; i < argc; i++) {
        strcat(command, " ");
        strcat(command, argv[i]);
    }

    // Just execute - no extra formatting
    int result = system(command);

    #ifdef _WIN32
        return result;
    #else
        return WIFEXITED(result) ? WEXITSTATUS(result) : -1;
    #endif
}

int cmd_run(int argc, char *argv[]) {
    // Check for quiet flag
    int quiet_mode = 0;
    
    // Parse flags and rebuild argv without flags
    char *filtered_argv[argc];
    int filtered_argc = 0;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-q") == 0 || strcmp(argv[i], "--quiet") == 0) {
            quiet_mode = 1;
        } else {
            filtered_argv[filtered_argc++] = argv[i];
        }
    }

    if (!quiet_mode) {
        printf("🏃 Building and running project...\n\n");
    }

    // Check if we are in a valid sbor project
    if (!file_exists("CMakeLists.txt") || !file_exists("src")) {
        fprintf(stderr, "❌ Error: Not in a valid sbor project directory.\n");
        fprintf(stderr, "   Make sure you're in a directory created with 'sbor init' that contains:\n");
        fprintf(stderr, "   - CMakeLists.txt\n");
        fprintf(stderr, "   - src/ directory\n\n");
        fprintf(stderr, "   Run 'sbor init <project_name>' to create a new project.\n");
        return 1;
    }

    // Build the project
    if (!quiet_mode) {
        printf("📦 Building project...\n");
        int build_result = cmd_build(0, NULL);
        
        if (build_result != 0) {
            fprintf(stderr, "❌ Build failed! Cannot run the program.\n");
            return build_result;
        }
        printf("\n");
    } else {
        // In quiet mode, suppress build output
        // Redirect stdout temporarily
        FILE *original_stdout = stdout;
        stdout = fopen("/dev/null", "w");
        
        int build_result = cmd_build(0, NULL);
        
        // Restore stdout
        fclose(stdout);
        stdout = original_stdout;
        
        if (build_result != 0) {
            fprintf(stderr, "❌ Build failed! Cannot run the program.\n");
            return build_result;
        }
    }

    // Find the executable
    char *exe_path = find_executable();
    if (!exe_path) {
        fprintf(stderr, "❌ Error: Could not find executable in build directory.\n");
        fprintf(stderr, "   Expected executable location: build/<project_name>%s\n", EXE_EXTENSION);
        fprintf(stderr, "   Make sure the build was successful.\n");
        return 1;
    }

    // Execute the binary based on mode
    int run_result;
    if (quiet_mode) {
        run_result = execute_binary_quiet(exe_path, filtered_argc, filtered_argv);
    } else {
        run_result = execute_binary_verbose(exe_path, filtered_argc, filtered_argv);
    }

    free(exe_path);
    return run_result;
}
