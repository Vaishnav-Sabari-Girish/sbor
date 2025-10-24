# Sbor

`sbor` is a package manager cum project manager for C


## Functionalities (Not yet created)

1. `sbor init` : Initializes a new C project  (**Created**)
2. `sbor add` : Adds a new dependency (No need to add `#include` in main.c file, this will do it automatically)
3. `sbor build` : Builds the project and creates a new binary
4. `sbor run` : Builds and runs the project

The dependencies are listed a configuration file (`sbor.conf`) which also contains the project metadata.

Since the dependencies have to be imported , they are also included in a separate `include.h` file which is included into the `main.c` file.

## Installation and Running

```bash
# Run cmake to generate the Makefile
cmake .

# Run make to generate the binary
make

# Run the binary
./sbor
```

## Goals

### Project Manager (To be created first)

- [x] Initialize a project using `sbor init`
- [ ] Add dependencies using `sbor add`
- [ ] Build the project using `sbor build`
- [ ] Remove a dependency using `sbor remove`
- [ ] Run the project using `sbor run`


## Recordings 

### Initializing a project

![init](./assets/recordings/hello_world.gif)
