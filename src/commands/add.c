#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../include/commands.h"

int cmd_add(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "❌ Error: Missing header name\n");
    printf("Usage:\n");
    printf("  sbor add <header>     Add system header (e.g., sbor add string)\n");
    printf("  sbor add -c <header>  Add custom header (e.g., sbor add -c myheader.h)\n");
    return 1;
  }

  // Check if we are in a valid sbor project
  if (!file_exists("CMakeLists.txt") || !file_exists("sbor.conf")) {
    fprintf(stderr, "❌ Error: Not in a valid sbor project directory.\n");
    fprintf(stderr, "   Make sure you're in a directory created with 'sbor init'\n");
    return 1;
  }

  int is_custom = 0;
  char *header = NULL;

  // Parse arguments
  if (argc == 3 && strcmp(argv[1] , "-c") == 0) {
    // sbor add -c <header>
    is_custom = 1;
    header = argv[1];
  } else if (argc == 3 && strcmp(argv[2], "-c") == 0) {
    // sbor add <header> -c
    is_custom = 1;
    header = argv[1];
  } else {
    // sbor add <header>
    header = argv[1];
  }

  printf("📦 Adding %s header: %s\n", is_custom ? "custom" : "system", header);

  int result;
  if (is_custom) {
    result = add_custom_header(header);
  } else {
    result = add_system_header(header);
  }

  if (result != 0) {
    fprintf(stderr, "❌ Failed to add header\n");
    return 1;
  }

  // Update include.h file
  if (update_include_file() != 0) {
    fprintf(stderr, "❌ Failed to update include.h file\n");
    return 1;
  }

  printf("✅ Successfully added %s header: %s\n", is_custom ? "custom" : "system", header);
  printf("   Updated files:\n");
  printf("   - sbor.conf\n");
  printf("   - src/include.h\n");

  return 0;
}
