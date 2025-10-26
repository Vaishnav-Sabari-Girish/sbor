#include <stdio.h>
#include <string.h>
#include "include/commands.h"

#define VERSION "V0.1.7"


void print_usage(void) {
  printf("sbor - C Project Manager and Package Manager\n\n");
  printf("Usage: sbor <command> [options]\n\n");
  printf("Commands:\n");
  printf("  init <name>     Create a new C project\n");
  printf("  add <header>    Add header to include.h\n");
  printf("  remove <header> Remove header from include.h\n");
  printf("  list            List current headers\n");
  printf("  build           Build the project\n");
  printf("  run             Build and run the project\n");
  printf("    -q            Build and Run in quiet Mode\n");
  printf("    -v            Build and Run in verbose Mode (Default)\n");
  printf("  version         Display sbor version\n");
  printf("  clean           Clean the build files\n");
  printf("  help            Display this message\n\n");
  printf("Examples:\n");
  printf("  sbor init my_project\n");
  printf("  sbor add string\n");
  printf("  sbor add custom.h -c\n");
}


int main(int argc, char *argv[]) {

  if (argc < 2) {
    print_usage();
    return 1;
  }

  const char *command = argv[1];

  if (strcmp(command, "init") == 0) {
    return cmd_init(argc - 1, argv + 1);
  } else if (strcmp(command, "add") == 0) {
    return cmd_add(argc - 1, argv + 1);
  } else if (strcmp(command, "remove") == 0) {
    return cmd_remove(argc - 1, argv + 1);
  } else if (strcmp(command, "list") == 0) {
    return cmd_list(argc - 1, argv + 1);
  } else if (strcmp(command, "build") == 0) {
    return cmd_build(argc - 1, argv + 1);
  } else if (strcmp(command, "run") == 0) {
    return cmd_run(argc - 1, argv + 1);
  } else if (strcmp(command, "help") == 0) {
    print_usage();
    return 0;
  } else if (strcmp(command, "version") == 0) {
    printf("Version : %s\n", VERSION);
    return 0;
  } else if (strcmp(command, "clean") == 0) {
    return cmd_clean(argc - 1, argv + 1);
  } else {
    fprintf(stderr, "Unknown Command : %s\n", command);
    print_usage();
    return 1;
  }
  return 0;
}
