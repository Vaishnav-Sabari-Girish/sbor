# Sbor

`sbor` is a  project manager for C inspired by `cargo`.

`sbor` means **Collection** in **Russian**.

[![Release](https://img.shields.io/badge/Release-V0.1.7-blue?style=for-the-badge&labelColor=gray)](https://github.com/Vaishnav-Sabari-Girish/sbor/releases/tag/v0.1.7)

## Functionalities

1. `sbor init` : Initializes a new C project   
2. `sbor add` : Adds a new dependency (No need to add `#include` in main.c file, this will do it automatically)
3. `sbor remove` : Removes a dependency
4. `sbor build` : Builds the project and creates a new binary  
5. `sbor run` : Builds and runs the project 
6. `sbor clean` : Removed build artifacts 

The dependencies are listed a configuration file (`sbor.conf`) which also contains the project metadata.

Since the dependencies have to be imported , they are also included in a separate `include.h` file which is included into the `main.c` file.

## Commands List

![help](./assets/images/help.png)


## Installation and Running

### Using `curl`

```bash
curl -sSL https://raw.githubusercontent.com/Vaishnav-Sabari-Girish/sbor/refs/heads/main/install.sh | bash
```

### From Source

```bash
# Run cmake to generate the Makefile
cmake .

# Run make to generate the binary
make

# Run the binary
./sbor version
```

### Using Homebrew

```bash
brew install Vaishnav-Sabari-Girish/taps/sbor

# Then Run

sbor version
```

## Goals

### Project Manager

- [x] Initialize a project using `sbor init`
- [x] Add dependencies using `sbor add`
- [x] Build the project using `sbor build`
- [x] Remove a dependency using `sbor remove`
- [x] Run the project using `sbor run`
- [x] Delete build artifacts using `sbor clean`
- [ ] Add a quiet option for code running in `sbor.conf` (Run code in quiet mode)


## Recordings 

### Initializing a project

![init](./assets/recordings/hello_world.gif)

### Building a project

![build](./assets/recordings/testing_build.gif)

### Running the project

#### Verbose Mode (Default)

![run_verbose](./assets/recordings/testing_run_verbose.gif)

#### Quiet Mode

![run_quiet](./assets/recordings/testing_run_quiet.gif)

### Cleaning the project

![clean](./assets/recordings/testing_clean.gif)

### Adding and Removing headers

![add_remove](./assets/recordings/testing_add_remove.gif)

## Stargazers over time

![stargazers badge](https://readme-contribs.as93.net/stargazers/Vaishnav-Sabari-Girish/sbor)

