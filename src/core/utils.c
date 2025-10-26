#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// Cross-platform includes
#ifdef _WIN32
    #include <direct.h>
    #define chdir _chdir
#else
    #include <sys/types.h>
#endif

#include "../include/commands.h"

// Helper function to check if a file exists
int file_exists(const char *filename) {
    struct stat buffer;
    return (stat(filename, &buffer) == 0);
}

// Helper function to check if we're in a valid sbor project
int is_valid_sbor_project() {
    return file_exists("CMakeLists.txt") && file_exists("src");
}

// Helper function to execute a command and return its exit status
int execute_command(const char *command) {
    printf("Executing: %s\n", command);
    int result = system(command);
    
    #ifdef _WIN32
        return result;
    #else
        // On Unix systems, system() returns the exit status in a specific format
        if (WIFEXITED(result)) {
            return WEXITSTATUS(result);
        } else {
            return -1; // Command failed to execute
        }
    #endif
}

// Helper function to get project name from CMakeLists.txt
char* get_project_name() {
    FILE *file = fopen("CMakeLists.txt", "r");
    if (!file) {
        return NULL;
    }
    
    char line[256];
    char *project_name = NULL;
    
    while (fgets(line, sizeof(line), file)) {
        // Look for project( line
        if (strncmp(line, "project(", 8) == 0) {
            char *start = line + 8;
            char *end = strchr(start, '\n');
            if (end) *end = '\0';
            
            end = strchr(start, ' ');
            if (end) *end = '\0';
            
            end = strchr(start, ')');
            if (end) *end = '\0';
            
            project_name = malloc(strlen(start) + 1);
            strcpy(project_name, start);
            break;
        }
    }
    
    fclose(file);
    return project_name;
}
