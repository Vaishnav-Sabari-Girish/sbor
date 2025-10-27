#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../include/commands.h"

int cmd_remove(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "❌ Error: Missing header name\n");
        printf("Usage: sbor remove <header>\n");
        printf("Examples:\n");
        printf("  sbor remove string     # Removes string.h\n");
        printf("  sbor remove myheader.h # Removes custom header\n");
        return 1;
    }

    // Check if we're in a valid sbor project
    if (!file_exists("sbor.conf") || !file_exists("src/include.h")) {
        fprintf(stderr, "❌ Error: Not in a valid sbor project directory.\n");
        fprintf(stderr, "   Make sure you're in a directory created with 'sbor init'\n");
        return 1;
    }

    char *header = argv[1];

    printf("🗑️  Removing header: %s\n", header);

    if (remove_header(header) != 0) {
        fprintf(stderr, "❌ Failed to remove header or header not found\n");
        return 1;
    }

    // Update include.h file
    if (update_include_file() != 0) {
        fprintf(stderr, "❌ Failed to update include.h file\n");
        return 1;
    }

    printf("✅ Successfully removed header: %s\n", header);
    printf("   Updated files:\n");
    printf("   - sbor.conf\n");
    printf("   - src/include.h\n");

    return 0;
}
