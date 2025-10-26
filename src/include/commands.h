#ifndef COMMANDS_H
#define COMMANDS_H

// Command function declarations
int cmd_init(int argc, char *argv[]);
int cmd_add(int argc, char *argv[]);
int cmd_remove(int argc, char *argv[]);
int cmd_list(int argc, char *argv[]);
int cmd_build(int argc, char *argv[]);
int cmd_run(int argc, char *argv[]);
int cmd_clean(int argc, char *argv[]);

// Utility functions for the init Command
int create_directory(const char *path);
int create_file_with_content(const char *filepath, const char *content);
char* generate_cmake_template(const char *project_name);
char* generate_main_template(void);
char* generate_include_template(void);
char* generate_readme_template(const char *project_name);
char* generate_gitignore_template(void);
char* generate_config_template(const char *project_name);

// Shared utility functions 
int file_exists(const char *filename);
int is_valid_sbor_project(void);
int execute_command(const char *command);
char* get_project_name(void);

#endif // !COMMANDS_H
