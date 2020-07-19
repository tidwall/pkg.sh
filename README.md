# `pkg.sh`

A generalized package manager for whatever code.

## Features

- Simple syntax, only three directives
- Language agnostic
- Supports dependency versioning and checksums
- Entire program is a single self-contained script

## Installing

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tidwall/pkg.sh/master/install.sh)"
```

Paste that in a macOS Terminal or Linux shell prompt.

## How to use

The `pkg.sh` help menu:

```
usage pkg.sh [command] [options]

Commands:
   import    Import files from .package into working directory
   sum       Add checksums to .package
   clean     Remove all imported files

Examples:
   pkg.sh import   # import files
   pkg.sh sum      # generate checksums
   pkg.sh sum -y   # generate checksums and ignore prompt
   pkg.sh clean    # remove all imports

Documentation can be found at https://github.com/tidwall/pkg.sh
```

### The `.package` file

Let's assume that you created a cool networking library that has two local
files, `network.c` and `network.h`. And, your library requires two remote 
dependencies.

```
file network.c
file network.h

import github.com/tidwall/hashmap.c v0.1.1
import github.com/tidwall/btree.c   v0.1.1
```

The `file network.c` and `file network.c` directives specify which local files
belong to the package. This will allow for others to fetch the files when 
importing this package.

An `import` directive imports remote packages and their dependencies.

### Importing

From the same directory as the .package file, run `pkg.sh import`:

```
$ pkg.sh import
[get] https://raw.githubusercontent.com/tidwall/hashmap.c/v0.1.1/.package
[get] https://raw.githubusercontent.com/tidwall/hashmap.c/v0.1.1/hashmap.c
[get] https://raw.githubusercontent.com/tidwall/hashmap.c/v0.1.1/hashmap.h
[get] https://raw.githubusercontent.com/tidwall/btree.c/v0.1.1/.package
[get] https://raw.githubusercontent.com/tidwall/btree.c/v0.1.1/btree.c
[get] https://raw.githubusercontent.com/tidwall/btree.c/v0.1.1/btree.h
[yay] import complete
```

```
$ ls
btree.c  btree.h  buf.c  buf.h  network.c  network.h  hashmap.c  hashmap.h
```

Now all dependencies have been imported.

### Import syntax

Along with the above example, here are some additional `import` syntaxes:

```bash
import github.com/tidwall/hashmap.c                  # default `master` branch
import github.com/tidwall/hashmap.c 01fb55d          # specify a commit
import github.com/tidwall/hashmap.c 01fb55d -> src/  # save to a sub directory
```

The `->` arrow allows for saving the import into a sub directory.

You can also grab arbitrary files from anywhere on the web using a standard url.

```
import https://brew.sh/assets/img/homebrew-256x256.png
import https://raw.githubusercontent.com/willemt/raft/4aeeb54/include/raft.h
```

## Cleaning

Calling `pkg.sh clean` will remove all imported files. 

## Checksums

Run `pkg.sh sum` to generate checksums for all imported files. The sums will be
appended to the end of the `.package` file.

This will ensure that every `pkg.sh import` call imports the exact same files
every time.

## License

pkg.sh source code is available under the MIT License.
