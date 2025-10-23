#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Cross-platform directory creation
#ifdef _WIN32
  #include <direct.h>
  #define mkdir(path, mode) _mkdir(path)
#else 
  #include <sys/stat.h>
  #include <sys/types.h>
#endif

#include "../include/commands.h"

int cmd_init(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Error: Project Name required\n");
    fprintf(stderr, "Usage: sbor init <project_name>\n");
    return 1;
  }

  const char *project_name = argv[1];

  // Validate project name
  if (strlen(project_name) == 0) {
    fprintf(stderr, "Error: Project name cannot be empty\n");
    return 1;
  }

  // Create main project directory
  printf("Creating project: %s\n", project_name);
  if (create_directory(project_name) != 0) {
    fprintf(stderr, "Error: Failed to create a project directory '%s'\n", project_name);
    return 1;
  }

  // Change to project directory for relative paths
  char src_dir[256];
  snprintf(src_dir, sizeof(src_dir), "%s/src\n", project_name);

  // Create src directory
  if (create_directory(src_dir) != 0) {
    fprintf(stderr, "Error: Failed to create src directory\n");
    return 1;
  }

  // Generate file paths
  char cmake_path[256], main_path[256], include_path[256];
  char readme_path[256], gitignore_path[256], config_path[256];

  snprintf(cmake_path, sizeof(cmake_path), "%s/CMakeLists.txt\n", project_name);
  snprintf(main_path, sizeof(main_path), "%s/src/main.c\n", project_name);
  snprintf(include_path, sizeof(include_path), "%s/src/include.h\n", project_name);
  snprintf(readme_path, sizeof(readme_path), "%s/README.md\n", project_name);
  snprintf(gitignore_path, sizeof(gitignore_path), "%s/.gitignore\n", project_name);
  snprintf(config_path, sizeof(config_path), "%s/sbor.conf\n", project_name);

  // Generate and create files
  printf("Creating Project Files\n");

  // CMakeLists.txt
  char *cmake_content = generate_cmake_template(project_name);
  if (create_file_with_content(cmake_path, cmake_content) != 0) {
    fprintf(stderr, "Error: Failed to create CMakeLists.txt\n");
    free(cmake_content);
    return 1;
  }

  free(cmake_content);
  printf("  ✓ CMakeLists.txt\n");

  // src/main.c 
  char *main_content = generate_main_template();
  if (create_file_with_content(main_path, main_content) != 0) {
    fprintf(stderr, "Error: Failed to create main.c\n");
    free(main_content);
    return 1;
  }

  free(main_content);
  printf("  ✓ src/main.c\n");

  // src/include.h
  char *include_content = generate_include_template();
  if (create_file_with_content(include_path, include_content) != 0) {
    fprintf(stderr, "Error: Failed to create src/include.h\n");
    free(include_content);
    return 1;
  }

  free(include_content);
  printf("  ✓ src/include.h\n");

  // README.md
  char *readme_content = generate_readme_template(project_name);
  if (create_file_with_content(readme_path, readme_content) != 0) {
    fprintf(stderr, "Error: Failed to create README.md\n");
    free(readme_content);
    return 1;
  }

  free(readme_content);
  printf("  ✓ README.md\n");

  // .gitignore
  char *gitignore_content = generate_gitignore_template();
  if (create_file_with_content(gitignore_path, gitignore_content) != 0) {
    fprintf(stderr, "Error: Failed to create .gitignore\n");
    free(gitignore_content);
    return 1;
  }

  free(gitignore_content);
  printf("  ✓ .gitignore\n");

  // sbor.conf
  char *config_content = generate_config_template(project_name);
  if (create_file_with_content(config_path, config_content) != 0) {
    fprintf(stderr, "Error: Failed to create sbor.conf\n");
    free(config_content);
    return 1;
  }

  free(config_content);
  printf("  ✓ sbor.conf\n");

  // Success message
  printf("\n✨ Project '%s' created successfully!\n\n", project_name);
  printf("Next steps:\n");
  printf("  cd %s\n", project_name);
  printf("  mkdir build && cd build\n");
  printf("  cmake .. && make\n");
  printf("  ./%s\n\n", project_name);

  return 0;
}

// Utility functions implementation

int create_directory(const char *path) {
  #ifdef _WIN32
    return mkdir(path);
  #else
    return mkdir(path, 0755);
  #endif
}

int create_file_with_content(const char *filepath, const char *content) {
  FILE *file = fopen(filepath, "w");
  if (file == NULL) {
    return -1;
  }

  fprintf(file, "%s", content);
  fclose(file);
  return 0;
}
