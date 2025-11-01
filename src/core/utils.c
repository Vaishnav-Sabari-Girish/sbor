#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <ctype.h>

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

// Fixed JSON Utility functions for add/remove
static char* find_json_array(const char *json, const char *key) {
    char search_pattern[256];
    snprintf(search_pattern, sizeof(search_pattern), "\"%s\":", key);  // Fixed: colon instead of newline

    char *start = strstr(json, search_pattern);
    if (!start) {
        printf("Debug: Could not find key '%s' in JSON\n", key);
        return NULL;
    }

    start = strchr(start, '[');
    if (!start) {
        printf("Debug: Could not find array opening bracket for '%s'\n", key);
        return NULL;
    }

    char *end = strchr(start, ']');
    if (!end) {
        printf("Debug: Could not find array closing bracket for '%s'\n", key);
        return NULL;
    }

    size_t length = end - start + 1;
    char *result = malloc(length + 1);
    strncpy(result, start, length);
    result[length] = '\0';

    printf("Debug: Found array for '%s': %s\n", key, result);
    return result;
}

// Enhanced function to find nested JSON arrays (like "includes.system")
static char* find_nested_json_array(const char *json, const char *parent_key, const char *child_key) {
    // First find the parent object
    char parent_pattern[256];
    snprintf(parent_pattern, sizeof(parent_pattern), "\"%s\":", parent_key);
    
    char *parent_start = strstr(json, parent_pattern);
    if (!parent_start) {
        printf("Debug: Could not find parent key '%s'\n", parent_key);
        return NULL;
    }
    
    // Find the opening brace of the parent object
    char *obj_start = strchr(parent_start, '{');
    if (!obj_start) {
        printf("Debug: Could not find opening brace for '%s'\n", parent_key);
        return NULL;
    }
    
    // Find the closing brace of the parent object
    int brace_count = 0;
    char *obj_end = obj_start;
    do {
        if (*obj_end == '{') brace_count++;
        else if (*obj_end == '}') brace_count--;
        obj_end++;
    } while (*obj_end && brace_count > 0);
    
    if (brace_count != 0) {
        printf("Debug: Could not find matching closing brace for '%s'\n", parent_key);
        return NULL;
    }
    
    // Create a substring for the parent object
    size_t obj_length = obj_end - obj_start;
    char *obj_content = malloc(obj_length + 1);
    strncpy(obj_content, obj_start, obj_length);
    obj_content[obj_length] = '\0';
    
    // Now find the child array within this object
    char *result = find_json_array(obj_content, child_key);
    free(obj_content);
    
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
    printf("Debug: Header '%s' already exists\n", item);
    return strdup(array_str);
  }

  // Remove closing bracket and add new item
  size_t len = strlen(array_str);
  char *new_array = malloc(len + strlen(item) + 20);

  // Copy array without closing bracket
  strncpy(new_array, array_str, len - 1);
  new_array[len - 1] = '\0';

  // Check if array is empty (just "[]" or "[ ]")
  char *content = new_array + 1; // Skip opening bracket
  while (*content && isspace(*content)) content++;

  if (*content != '\0') {
    // Array is not empty, add comma
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

  if (!contains_header(array_str, item)) {
    printf("Debug: Header '%s' not found in array\n", item);
    return strdup(array_str);
  }

  char *result = malloc(strlen(array_str) + 1);
  strcpy(result, array_str);

  char *found = strstr(result, search_pattern);
  if (!found) {
    return result;
  }

  // Calculate positions
  char *item_start = found;
  char *item_end = found + strlen(search_pattern);

  // Check for comma after
  if (*item_end == ',' && *(item_end + 1) == ' ') {
    item_end += 2; // Remove ", "
  }
  // Check for comma before
  else if (item_start > result + 1 && *(item_start - 2) == ',' && *(item_start - 1) == ' ') {
    item_start -= 2; // Remove ", " before
  }

  // Shift the rest of the string
  memmove(item_start, item_end, strlen(item_end) + 1);

  return result;
}

int read_config_file(char **content) {
  FILE *file = fopen("sbor.conf", "r");
  if (!file) {
    printf("Debug: Could not open sbor.conf for reading\n");
    return -1;
  }

  fseek(file, 0, SEEK_END);
  long length = ftell(file);
  fseek(file, 0, SEEK_SET);

  *content = malloc(length + 1);
  if (fread(*content, 1, length, file) != (size_t)length) {
    printf("Debug: Could not read sbor.conf completely\n");
    free(*content);
    fclose(file);
    return -1;
  }
  (*content)[length] = '\0';

  fclose(file);
  printf("Debug: Read config file (%ld bytes)\n", length);
  return 0;
}

int write_config_file(const char *content) {
  FILE *file = fopen("sbor.conf", "w");
  if (!file) {
    printf("Debug: Could not open sbor.conf for writing\n");
    return -1;
  }

  if (fputs(content, file) == EOF) {
    printf("Debug: Could not write to sbor.conf\n");
    fclose(file);
    return -1;
  }

  fclose(file);
  printf("Debug: Wrote config file successfully\n");
  return 0;
}

int add_system_header(const char *header) {
    char *config_content;
    if (read_config_file(&config_content) != 0) {
        printf("Debug: Failed to read config file\n");
        return -1;
    }

    // Find system array within includes object - FIXED
    char *system_array = find_nested_json_array(config_content, "includes", "system");
    if (!system_array) {
        printf("Debug: Could not find includes.system array\n");
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

    printf("Debug: Adding header '%s' to system array\n", full_header);
    char *new_system_array = add_to_json_array(system_array, full_header);

    // Replace in config
    char *system_start = strstr(config_content, system_array);
    if (!system_start) {
        printf("Debug: Could not find system array in original config\n");
        free(config_content);
        free(system_array);
        free(new_system_array);
        return -1;
    }

    // Create new config content
    size_t before_len = system_start - config_content;
    size_t after_start = before_len + strlen(system_array);
    size_t new_size = before_len + strlen(new_system_array) + strlen(config_content + after_start) + 1;

    char *new_config = malloc(new_size);
    strncpy(new_config, config_content, before_len);
    new_config[before_len] = '\0';
    strcat(new_config, new_system_array);
    strcat(new_config, config_content + after_start);

    printf("Debug: Writing updated config\n");
    int result = write_config_file(new_config);

    free(config_content);
    free(system_array);
    free(new_system_array);
    free(new_config);

    return result;
}

int add_custom_header(const char *header) {
    char *config_content;
    if (read_config_file(&config_content) != 0) {
        return -1;
    }

    // Find custom array within includes object - FIXED
    char *custom_array = find_nested_json_array(config_content, "includes", "custom");
    if (!custom_array) {
        printf("Debug: Could not find includes.custom array\n");
        free(config_content);
        return -1;
    }

    char *new_custom_array = add_to_json_array(custom_array, header);

    // Replace in config (same logic as system headers)
    char *custom_start = strstr(config_content, custom_array);
    if (!custom_start) {
        free(config_content);
        free(custom_array);
        free(new_custom_array);
        return -1;
    }

    size_t before_len = custom_start - config_content;
    size_t after_start = before_len + strlen(custom_array);
    size_t new_size = before_len + strlen(new_custom_array) + strlen(config_content + after_start) + 1;

    char *new_config = malloc(new_size);
    strncpy(new_config, config_content, before_len);
    new_config[before_len] = '\0';
    strcat(new_config, new_custom_array);
    strcat(new_config, config_content + after_start);

    int result = write_config_file(new_config);

    free(config_content);
    free(custom_array);
    free(new_custom_array);
    free(new_config);

    return result;
}

int remove_header(const char *header) {
    char *config_content;
    if (read_config_file(&config_content) != 0) {
        return -1;
    }

    // Try to remove from system headers first - FIXED
    char *system_array = find_nested_json_array(config_content, "includes", "system");
    char full_header[256];
    if (strstr(header, ".h") == NULL) {
        snprintf(full_header, sizeof(full_header), "%s.h", header);
    } else {
        strcpy(full_header, header);
    }

    int found = 0;
    char *new_config = NULL;

    if (system_array && contains_header(system_array, full_header)) {
        // Remove from system headers
        char *new_system_array = remove_from_json_array(system_array, full_header);

        char *system_start = strstr(config_content, system_array);
        size_t before_len = system_start - config_content;
        size_t after_start = before_len + strlen(system_array);
        size_t new_size = before_len + strlen(new_system_array) + strlen(config_content + after_start) + 1;

        new_config = malloc(new_size);
        strncpy(new_config, config_content, before_len);
        new_config[before_len] = '\0';
        strcat(new_config, new_system_array);
        strcat(new_config, config_content + after_start);

        free(new_system_array);
        found = 1;
    } else {
        // Try custom headers - FIXED
        char *custom_array = find_nested_json_array(config_content, "includes", "custom");
        if (custom_array && contains_header(custom_array, header)) {
            char *new_custom_array = remove_from_json_array(custom_array, header);

            char *custom_start = strstr(config_content, custom_array);
            size_t before_len = custom_start - config_content;
            size_t after_start = before_len + strlen(custom_array);
            size_t new_size = before_len + strlen(new_custom_array) + strlen(config_content + after_start) + 1;

            new_config = malloc(new_size);
            strncpy(new_config, config_content, before_len);
            new_config[before_len] = '\0';
            strcat(new_config, new_custom_array);
            strcat(new_config, config_content + after_start);

            free(new_custom_array);
            found = 1;
        }
        if (custom_array) free(custom_array);
    }

    int result = -1;
    if (found && new_config) {
        result = write_config_file(new_config);
        free(new_config);
    }

    free(config_content);
    if (system_array) free(system_array);

    return result;
}

int update_include_file(void) {
    char *config_content;
    if (read_config_file(&config_content) != 0) {
        return -1;
    }

    // Parse system and custom headers - FIXED
    char *system_array = find_nested_json_array(config_content, "includes", "system");
    char *custom_array = find_nested_json_array(config_content, "includes", "custom");

    // Generate new include.h content
    FILE *file = fopen("src/include.h", "w");
    if (!file) {
        printf("Debug: Could not open src/include.h for writing\n");
        free(config_content);
        if (system_array) free(system_array);
        if (custom_array) free(custom_array);
        return -1;
    }

    fprintf(file, "// Auto-generated by sbor - Managed header includes\n");
    fprintf(file, "// Use 'sbor add <header>' to add system headers\n");
    fprintf(file, "// Use 'sbor add <header> -c' to add custom headers\n\n");

    // Write system headers
    fprintf(file, "// System headers\n");
    if (system_array && strlen(system_array) > 2) { // More than just "[]"
        // Create a working copy for strtok
        char *system_copy = strdup(system_array);
        char *ptr = system_copy + 1; // Skip opening bracket
        char *end = strrchr(system_copy, ']');
        if (end) *end = '\0';

        char *token = strtok(ptr, ",");
        while (token) {
            // Clean up the token (remove quotes and whitespace)
            while (*token && (isspace(*token) || *token == '"')) token++;
            char *token_end = token + strlen(token) - 1;
            while (token_end > token && (isspace(*token_end) || *token_end == '"')) {
                *token_end = '\0';
                token_end--;
            }

            if (strlen(token) > 0) {
                fprintf(file, "#include <%s>\n", token);
            }
            token = strtok(NULL, ",");
        }
        free(system_copy);
    }

    fprintf(file, "\n// Custom headers\n");
    if (custom_array && strlen(custom_array) > 2) { // More than just "[]"
        char *custom_copy = strdup(custom_array);
        char *ptr = custom_copy + 1; // Skip opening bracket
        char *end = strrchr(custom_copy, ']');
        if (end) *end = '\0';

        char *token = strtok(ptr, ",");
        while (token) {
            // Clean up the token
            while (*token && (isspace(*token) || *token == '"')) token++;
            char *token_end = token + strlen(token) - 1;
            while (token_end > token && (isspace(*token_end) || *token_end == '"')) {
                *token_end = '\0';
                token_end--;
            }

            if (strlen(token) > 0) {
                fprintf(file, "#include \"%s\"\n", token);
            }
            token = strtok(NULL, ",");
        }
        free(custom_copy);
    } else {
        fprintf(file, "// Add your custom includes here\n");
    }

    fclose(file);

    free(config_content);
    if (system_array) free(system_array);
    if (custom_array) free(custom_array);

    printf("Debug: Updated include.h successfully\n");
    return 0;
}

int get_json_boolean(const char *json, const char *section, const char *key) {
  // Find the section
  char section_pattern[256];
  snprintf(section_pattern, sizeof(section_pattern), "\"%s\":", section);

  char *section_start = strstr(json, section_pattern);
}
