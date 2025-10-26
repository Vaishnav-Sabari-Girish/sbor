#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
  #include <direct.h>
  #include <windows.h>
#else
  #include <unistd.h>
  #include <dirent.h>
  #include <sys/types.h>
#endif

#include "../include/commands.h"

// Helper function to recursively delete a directory
int remove_directory(const char *path) {
  #ifdef _WIN32
    char command[512];
    snprintf(command, sizeof(command), "rmdir /s /q \"%s\"", path);
    return system(command);
  #else 
    char command[512];
    snprintf(command, sizeof(command), "rm -rf \"%s\"\n", path);
  #endif
  
  int result = system(command);
  return result;
}

int cmd_clean(int argc, char *argv[]) {
  (void)argc;
  (void)argv;

  printf("🧹 Cleaning build artifacts...\n\n");

  // Check if we are in a valid sbor project
  if (!file_exists("CMakeLists.txt") || !file_exists("sbor.conf")) {
    fprintf(stderr, "❌ Error: Not in a valid sbor project directory.\n");
    fprintf(stderr, "   Make sure you're in a directory created with 'sbor init' that contains:\n");
    fprintf(stderr, "   - CMakeLists.txt\n\n");
    fprintf(stderr, "   - sbor.conf\n\n");
    fprintf(stderr, "   Run 'sbor init <project_name>' to create a new project.\n");
    return 1;
  }

  // Check if build directory exists
  if (!file_exists("build")) {
    printf("✨ Already clean! No build directory found.\n");
    printf("   The project has no build artifacts to remove.\n");
    return 0;
  }

  printf("🗑️  Removing build directory...\n");

  int result = remove_directory("build");

  if (result == 0) {
    printf("   ✅ Build directory removed successfully.\n\n");
    printf("🎉 Clean completed!\n");
    printf("   All build artifacts have been removed.\n");
    printf("   💡 Run 'sbor build' to rebuild your project.\n");
    return 0;
  }
  else {
    fprintf(stderr, "   ❌ Failed to remove build directory.\n");
    fprintf(stderr, "   You may need to remove it manually or check permissions.\n");
    return 1;
  }
}
