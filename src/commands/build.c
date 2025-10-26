#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

// Cross-platform directory creation
#ifdef _WIN32
  #include <direct.h>
  #define mkdir(path, mode) _mkdir(path)
  #define chdir _chdir
#else 
  #include <sys/types.h>
#endif 

#include "../include/commands.h"


int cmd_build(int argc, char *argv[]) {
  (void)argc;
  (void)argv;

  printf("🔨 Building project...\n\n");

  // Check if we are in a valid sbor project
  if (!is_valid_sbor_project()) {
    fprintf(stderr, "❌ Error: Not in a valid sbor project directory.\n");
    fprintf(stderr, "   Make sure you're in a directory created with 'sbor init' that contains:\n");
    fprintf(stderr, "   - CMakeLists.txt\n");
    fprintf(stderr, "   - sbor.conf\n");
    fprintf(stderr, "   - src/ directory\n\n");
    fprintf(stderr, "   Run 'sbor init <project_name>' to create a new project.\n");
    return 1;
  }

  // Create build directory if it doesn't exist
  if (!file_exists("build")) {
    printf("📁 Creating build directory...\n");
    if (mkdir("build", 0755) != 0) {
      fprintf(stderr, "❌ Error: Failed to create build directory\n");
      return 1;
    }
    printf("   ✅ Build directory created successfully.\n\n");
  } else {
    printf("📁 Using existing build directory...\n\n");
  }

  // Save current directory
  char current_dir[1024];
  if (getcwd(current_dir, sizeof(current_dir)) == NULL) {
    fprintf(stderr, "❌ Error: Failed to get current directory.\n");
    return 1;
  }

  // Change build directory
  if (chdir("build") != 0) {
    fprintf(stderr, "❌ Error: Failed to change to build directory.\n");
    return 1;
  }

  printf("🔧 Configuring project with CMake...\n");

  // Run cmake command
  int cmake_result = execute_command("cmake ../");
  if (cmake_result != 0) {
    fprintf(stderr, "❌ Error: CMake configuration failed (exit code: %d).\n", cmake_result);
    fprintf(stderr, "   Please check your CMakeLists.txt file and ensure CMake is installed.\n");
    chdir(current_dir);  // Return to original directory
    return 1;
  }

  printf("   ✅ CMake configuration completed successfully.\n\n");

  // Run make command
  printf("🔨 Building project with Make...\n");

  // make command changes based on pplatform
  int make_result;
  #ifdef _WIN32
    // Trying nmake first , then mingw32-make then make
    make_result = execute_command("nmake");
    if (make_result != 0) {
      make_result = execute_command("mingw32-make");
      if (make_result != 0) {
        make_result = execute_command("make");
      }
    }
  #else
    // On unix-like sytems, it is just make
    make_result = execute_command("make");
  #endif
  
  if (make_result != 0) {
    fprintf(stderr, "❌ Error: Build failed (exit code: %d).\n", make_result);
    fprintf(stderr, "   Please check for compilation errors above.\n");
    chdir(current_dir);  // Return to original directory
    return 1;
  }

  printf("   ✅ Build completed successfully.\n\n");

  // Return to original directory
  if (chdir(current_dir) != 0) {
    fprintf(stderr, "⚠️  Warning: Failed to return to original directory.\n");
  }

  // Check if binary was created and show its location
  if (file_exists("build")) {
    printf("🎉 Build successful!\n");
    printf("   📍 Binary location: ./build/\n");
    printf("   🚀 Run your project with: cd build && ./<project_name>\n");
    printf("   💡 Or use: sbor run\n");
  }

  return 0;

}
