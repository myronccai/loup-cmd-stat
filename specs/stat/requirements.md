# Requirements: stat

## Introduction

`stat` displays file and file-system status, like GNU `stat` from
coreutils, and adds a `--df` mode that lists mounted file systems with
their sizes. It gets everything from the C library: `stat`/`lstat`,
`statx` (birth time), `statvfs` and `statfs`, `getpwuid_r`/`getgrgid_r`,
`localtime_r`/`strftime`, `readlink` and `realpath`. It is the
host-compiled (`host.native`) FFI example of the loup-cmd series:
`@repr(C)` structs laid out like glibc's on Linux x86-64, checked with
`size_of`, and `NativeHandle` pointers to C memory.

## Requirements

### Requirement 1: File status

**User Story:** As a user, I want to see everything the system knows about
a file.

#### Acceptance Criteria

1. WHEN FILE operands are given, THE program SHALL print GNU stat's default
   report for each: name (with ` -> TARGET` for a symbolic link), size,
   blocks, I/O block, type, device, inode, links, device type for device
   files, mode in octal and as `-rwxr-xr-x`, owner and group by number and
   name, and the access, modify, change and birth times.
2. THE program SHALL not follow symbolic links, unless `-L` is given.
3. Times SHALL be in the local time zone (`TZ` included) as
   `YYYY-MM-DD HH:MM:SS.NNNNNNNNN +ZZZZ`, computed by the C library; a
   birth time the file system does not record SHALL be `-`.
4. WHEN FILE is `-`, THE program SHALL report standard input.
5. WHEN a user or group id has no name, THE program SHALL print `UNKNOWN`.

### Requirement 2: Formats

**User Story:** As a script author, I want to pick the fields and their
layout.

#### Acceptance Criteria

1. `-c FORMAT` / `--format=FORMAT` SHALL print FORMAT followed by a newline
   for each file; `--printf=FORMAT` SHALL print FORMAT without one and
   SHALL interpret backslash escapes (`\n \t \\ \" \a \b \e \f \r \v`,
   `\NNN` octal, `\xHH` hex).
2. THE directives `%a %A %b %B %d %D %f %F %g %G %h %i %m %n %N %o %r %R %s
   %t %T %u %U %w %W %x %X %y %Y %z %Z` SHALL mean what they mean in GNU
   stat, `%Hd %Ld %Hr %Lr` the major and minor numbers, and `%%` a percent
   sign; any other directive SHALL print `?`.
3. A directive MAY carry printf flags (`-`, `0`, `#`), a width and a
   precision: strings are cut to the precision, numbers get at least that
   many digits, `#` adds `0` to octal and `0x` to hexadecimal, and the
   precision of `%X %Y %Z %W` is the number of decimals of the seconds.
4. `-t` / `--terse` SHALL print GNU's terse line.

### Requirement 3: File-system status

**User Story:** As a user, I want to know how full a file system is.

#### Acceptance Criteria

1. WHEN `-f` is given, THE program SHALL report the file system containing
   each FILE from `statvfs`: ID, maximum name length, type (from `statfs`),
   block sizes, total, free and available blocks, total and free inodes.
2. With `-f`, the directives SHALL be `%a %b %c %d %f %i %l %n %s %S %t
   %T`, and `-t` SHALL print GNU's terse file-system line.

### Requirement 4: The df mode

**User Story:** As a user, I want a quick list of mounted file systems.

#### Acceptance Criteria

1. WHEN `--df` is given without operands, THE program SHALL read
   `/proc/self/mounts` and print one line per real file system: source, size,
   used and available space in 1024-byte blocks, use percentage (rounded
   up), and mount point, in aligned columns under a header.
2. It SHALL leave out file systems with no blocks (proc, sysfs, ...),
   read-only images (squashfs), `devtmpfs`, and a source already listed.
3. WHEN FILE operands are given, THE program SHALL list the file system
   that holds each FILE.
4. Escapes in the mount table (`\040` for a space, ...) SHALL be decoded.

### Requirement 5: Errors and exit status

**User Story:** As a script author, I want GNU stat's messages and status.

#### Acceptance Criteria

1. WHEN a FILE cannot be examined, THE program SHALL print `stat: cannot
   stat 'FILE': REASON` (with `-f`: `cannot read file system information
   for 'FILE': REASON`), go on with the next one, and exit with status 1.
2. WHEN no FILE is given (outside `--df`), THE program SHALL print
   `stat: missing operand` and the usage hint, and exit with status 1.
3. Unknown options and missing values SHALL be usage errors (status 1).
4. `--help` and `--version` SHALL print the help and
   `stat (loup-cmd-stat) 0.1.0` with status 0.

### Requirement 6: The C layout

**User Story:** As a maintainer, I want the program to refuse to run with a
struct layout that does not match the C library.

#### Acceptance Criteria

1. THE program SHALL check with `size_of` that its `struct stat`,
   `struct statx`, `struct statvfs`, `struct statfs` and `struct tm` have
   glibc's x86-64 sizes, and SHALL stop with an error naming the struct
   otherwise. (`struct passwd` and `struct group` hold a `NativeHandle`,
   which `size_of` cannot measure.)
