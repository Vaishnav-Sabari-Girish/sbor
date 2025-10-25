#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

// Cross-platform directory and execution
#ifdef _WIN32
  #include <direct.h>
  #define chidir _chidir
  #define PATH_SEPERATOR "\\"
  #define EXE_EXTENSION ".exe"
#else
  #include <sys/types.h>
  #define PATH_SEPERATOR "/"
  #define EXE_EXTENSION ""
#endif

#include "../include/commands.h"
