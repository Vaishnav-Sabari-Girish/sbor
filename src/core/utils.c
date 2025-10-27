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

// JSON Utility functions for add/remove
static char* find_json_array(const char *json, const char *key) {
  char search_pattern[256];
  snprintf(search_pattern, sizeof(search_pattern), "\"%s\"\n", key);

  char *start = strstr(json, search_pattern);
  if (!start) return NULL;

  start = strchr(start, '[');
  if (!start) return NULL;

  char *end = strchr(start, ']');
  if (!end) return NULL;

  size_t length = end - start + 1;
  char *result = malloc(length + 1);
  strncpy(result, start, length);
  result[length] = '\0';

  return result;
}

static int contains_header(const char *array_str, const char *header) {
  char search_pattern[256];
  snprintf(search_pattern, sizeof(search_pattern), "\"%s\"", header);
  return strstr(array_str, search_pattern) != NULL;
}

static char* add_to_json_array(const char *array_str, const char *item) {
  if (contains_header(array_str, item)) {
    // Header already exists
    return strdup(array_str);
  }

  // Remove closing bracket and add new item
  size_t len = strlen(array_str);
  char *new_array = malloc(len + strlen(item) + 20);

  // Copy array without closing bracket
  strncpy(new_array, array_str, len - 1);
  new_array[len - 1] = '\0';

  // Add comma if not empty array
  if (len > 2) {   // More than just [] 
    strcat(new_array, ", ");
  }

  // Add new item
  strcat(new_array, "\"");
  strcat(new_array, item);
  strcat(new_array, "\"]");

  return new_array;
}

static char* remove_from_json_array(const char *array_str, const char *item) {
  char search_pattern[256];
  snprintf(search_pattern, sizeof(search_pattern), "\"%s\"", item);

  char *found = strstr(array_str, search_pattern);

  if (!found) {
    return strdup(array_str);   // Item not found
  }

  char *new_array = malloc(strlen(array_str) + 1);

  size_t before_len = found - array_str;

  // Copy part before the item
  strncpy(new_array, array_str, before_len);
  new_array[before_len] = '\0';

  // Skip the item and potential comma
  char *after = found + strlen(search_pattern);
  if (*after == ',' && *(after + 1) == ' ') {
    after += 2;
  } else if (before_len > 1 && *(found - 2) == ',' && *(found - 1) == ' ') {
    // Remove comma before if this was not the first item
    new_array[before_len - 2] = '\0';
  }

  // Copy the rest
  strcat(new_array, after);

  return new_array;
}

int read_config_file(char **content) {
  FILE *file = fopen("sbor.conf", "r");
  if (!file) return -1;

  fseek(file, 0, SEEK_END);
  long length = ftell(file);
  fseek(file, 0, SEEK_SET);

  *content = malloc(length + 1);
  fread(*content, 1, length, file);

  (*content)[length] = '\0';

  fclose(file);
  return 0;
}

int write_config_file(const char *content) {
  FILE *file = fopen("sbor.conf", "w");
  if (!file) return -1;

  fputs(content, file);
  fclose(file);
  return 0;
}

int add_system_header(const char *header) {
  char *config_content;
  if (read_config_file(&config_content) != 0) {
    return -1;
  }

  // Find systems array
  char *system_array = find_json_array(config_content, "system");
  if (!system_array) {
    free(config_content);
    return -1;
  }

  // Add header with .h extension if not present
  char full_header[256];
  if (strstr(header, ".h") == NULL) {
    snprintf(full_header, sizeof(full_header), "%s.h", header);
  } else {
    strcpy(full_header, header);
  }

  char *new_system_array = add_to_json_array(system_array, full_header);

  // Replace in config
  char *system_start = strstr(config_content, system_array);
  if (!system_start) {
    free(config_content);
    free(system_array);
    free(new_system_array);
    return -1;
  }


}
