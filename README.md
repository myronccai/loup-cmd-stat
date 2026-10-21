# loup-cmd-stat

GNU `stat` in [Loup](https://code-craft.ai/references/loup): display file
or file-system status, in GNU's default, terse or your own format, plus a
`--df` mode that lists mounted file systems with their sizes. Everything
comes from the C library through `extern native` calls and `@repr(C)`
structs laid out like glibc's.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is a `host.native` (host-compiled) command.

## Requirements

- Linux on x86-64 with glibc. The C structs are written for that ABI
  (`struct stat` is 144 bytes there, `struct statx` 256, `struct statvfs`
  112, `struct statfs` 120, `struct tm` 56); the program checks their sizes
  with `size_of` at start-up and refuses to run if one differs. `statx(2)`
  needs Linux 4.11 and glibc 2.28 or later; `--df` reads
  `/proc/self/mounts`.
- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                                     # native binary: build/stat
make ci                                        # check, native unit tests, build, end-to-end tests
make run ARGS="-c '%n %F %A' /etc/passwd"      # build, then run with ARGS
```

Everything is built by Stage0: `make check`, the binary
(`loup-bootstrap build --target native`) and the unit tests
(`loup-bootstrap test --native`).

`report-final.pdf` is a hard link to `report.pdf`, and `latest.pdf` a
symbolic link to it; times are in the local time zone (here UTC-7):

```text
$ stat report.pdf
  File: report.pdf
  Size: 18432     	Blocks: 40         IO Block: 4096   regular file
Device: 0,49	Inode: 7038324     Links: 2
Access: (0640/-rw-r-----)  Uid: ( 1000/   myron)   Gid: ( 1000/   myron)
Access: 2026-10-19 10:30:15.000000000 -0700
Modify: 2026-10-19 10:30:15.000000000 -0700
Change: 2026-10-20 23:45:56.944889484 -0700
 Birth: 2026-10-20 23:45:56.930813015 -0700
$ stat -c '%n: %s bytes, %F, %A (%a), %h links' report.pdf notes latest.pdf
report.pdf: 18432 bytes, regular file, -rw-r----- (640), 2 links
notes: 40 bytes, directory, drwxr-x--- (750), 2 links
latest.pdf: 10 bytes, symbolic link, lrwxrwxrwx (777), 1 links
$ stat -c %N latest.pdf
'latest.pdf' -> 'report.pdf'
$ stat -L -c '%n -> %F, %s bytes' latest.pdf
latest.pdf -> regular file, 18432 bytes
$ stat --printf='%n\t%U:%G\t%y\n' report.pdf notes
report.pdf	myron:myron	2026-10-19 10:30:15.000000000 -0700
notes	myron:myron	2026-10-20 23:45:56.941889456 -0700
$ stat -c '%Y %.3Y %10.10A|' report.pdf
1792431015 1792431015.000 -rw-r-----|
$ stat -t report.pdf
report.pdf 18432 40 81a0 1000 1000 31 7038324 2 0 0 1792431015 1792431015 1792565156 1792565156 4096
$ TZ=Asia/Tokyo stat -c '%y' report.pdf
2026-10-20 02:30:15.000000000 +0900
```

File systems:

```text
$ stat -f /
  File: "/"
    ID: e776e1c7f2b69ba0 Namelen: 255     Type: ext2/ext3
Block size: 4096       Fundamental block size: 4096
Blocks: Total: 480160322  Free: 240309913  Available: 215900672
Inodes: Total: 122028032  Free: 118140579
$ stat -f -c '%n is %T, %b blocks of %S bytes, %a free for users' /tmp
/tmp is tmpfs, 7783460 blocks of 4096 bytes, 1712778 free for users
$ stat --df / /tmp
Filesystem      1K-blocks      Used Available Use% Mounted on
/dev/nvme1n1p2 1920641288 959401636 863602688  53% /
tmpfs            31133840  24282728   6851112  78% /tmp
$ stat missing
stat: cannot stat 'missing': No such file or directory
```

## Options

| Option | Meaning |
|---|---|
| `-L`, `--dereference` | follow symbolic links |
| `-f`, `--file-system` | report the file system that holds each FILE |
| `-c`, `--format=FORMAT` | print FORMAT, then a newline, for each FILE |
| `--printf=FORMAT` | print FORMAT with backslash escapes, no newline added |
| `-t`, `--terse` | GNU's one-line form |
| `--df` | list mounted file systems (or those holding each FILE) |
| `--cached=WHEN` | accepted (`always`, `never`, `default`); no effect |
| `--help`, `--version` | |

`-` as FILE means standard input. Short options bundle (`-Lc '%n'`), long
options take unambiguous prefixes, and `--` ends the options.

**Directives for files:** `%a` octal permissions, `%A` `-rw-r--r--`,
`%b` blocks, `%B` block size (512), `%d`/`%D` device (decimal/hex),
`%Hd`/`%Ld` its major/minor, `%f` raw mode (hex), `%F` file type, `%g`/`%G`
group id/name, `%h` links, `%i` inode, `%m` mount point, `%n` name, `%N`
quoted name (with ` -> target`), `%o` I/O block, `%r`/`%R` device type,
`%Hr`/`%Lr` (decimal) and `%t`/`%T` (hex) its major/minor, `%s` size,
`%u`/`%U` owner id/name, `%w`/`%W` birth, `%x`/`%X` access, `%y`/`%Y`
modification, `%z`/`%Z` status change (local time / seconds), `%%`.

**Directives with `-f`:** `%a` available blocks, `%b` total blocks, `%c`
inodes, `%d` free inodes, `%f` free blocks, `%i` ID (hex), `%l` name length,
`%n` name, `%s` block size, `%S` fundamental block size, `%t`/`%T` type
(hex/name).

Directives take printf flags, width and precision: `%-10n`, `%04a`, `%#a`
(`0640`), `%#f` (`0x81a0`), `%.3Y` (three decimals), `%.Y` (nine).
`--printf` escapes: `\n \t \\ \" \a \b \e \f \r \v \NNN \xHH`.

Exit status: `0` if every FILE was examined, `1` otherwise or on a usage
error.

## Differences from the original

- The error for a file that cannot be examined says `cannot stat`, as
  GNU stat did before it switched to `statx` (`cannot statx`).
- `--df` is new. It hides file systems without blocks, `squashfs`,
  `devtmpfs` and repeated devices (like GNU df's default listing) and
  silently leaves out mount points it cannot examine (GNU df reports them).
- `--cached` is accepted and ignored; `%C` (SELinux context) is not
  supported and prints `?`.
- `%N` uses GNU's shell quoting for ordinary names (`'a b'`, `"it's"`,
  `'it'\''s $x'`), but does not write control characters as `$'\n'`.
- `--printf` escapes for bytes 128 to 255 (`\377`, `\xff`) print the
  character U+0080..U+00FF in UTF-8, not the raw byte: a Loup string cannot
  hold a lone byte that is not UTF-8.
- File-system type names (`%T` with `-f`) cover the common Linux file
  systems; others show as `UNKNOWN (0x...)`.

## What this example shows

- **`@repr(C)` structs for real C APIs.** `sys/cstructs.lphc` declares
  `struct stat`, `struct statx`, `struct statvfs`, `struct statfs`,
  `struct tm`, `struct passwd` and `struct group` field by field, with C's
  names and padding, and `layout_errors()` compares `size_of` of each with
  glibc's x86-64 size before anything runs. They cross into C as
  `edits buf: StatBuf` and come back filled.
- **`extern native "c"` for 21 libc functions**: `stat`, `lstat`, `fstat`,
  `statx`, `statvfs`, `statfs`, `getpwuid_r`, `getgrgid_r`, `localtime_r`,
  `strftime`, `tzset`, `readlink`, `realpath`, `malloc`, `free`, `strlen`,
  `memcpy`, `memmove`, `mempcpy`, `strerror`, `__errno_location`.
- **`NativeHandle` without pointer arithmetic.** A handle is opaque (no `+`,
  no `==`, no NULL). C text is copied into a `CText` struct of eight
  `uint64` words, 64 bytes at a time, and `mempcpy`, which returns the end of
  what it copied, provides the address k bytes into a buffer
  (`sys/libc.lphc` `c_text`). The `_r` forms of `getpwuid`/`getgrgid`
  report "not found" through a `struct passwd **` read as an address
  (`PtrCell`), which can be compared with 0.
- **A class that owns C memory.** `CBuffer` wraps `malloc`; its
  `finalize()` frees the block when the last reference goes away.
- **Local time from libc.** `core.datetime` knows only UTC;
  `sys/clock.lphc` uses `localtime_r` and `strftime`, so `TZ` and the
  system's zone files work (the tests set `TZ` with `setenv`).
- **An interface for the format engine.** `format/printf.lphc` expands
  `%[flags][width][.precision]X` over any `FieldSource`; `FileFields` and
  `FsFields` (`format/fields.lphc`) implement it.

## Layout

```text
source/main.lphc              # entry point
source/appinfo.lphc           # name, version, exit statuses
source/cli/args.lphc          # Options, parse_args()
source/cli/usage.lphc         # --help and --version text
source/cli/app.lphc           # run(): parse, help/version, usage errors
source/sys/cstructs.lphc      # @repr(C) structs, size checks, CText bytes
source/sys/libc.lphc          # extern native libc, CBuffer, c_text, FileStatus, FsStatus, names
source/sys/clock.lphc         # local time with localtime_r and strftime
source/format/modes.lphc      # file types, mode strings, device numbers, fs type names
source/format/printf.lphc     # the format engine: directives, flags, escapes
source/format/fields.lphc     # FileFields, FsFields, default and terse formats, shell quoting
source/df/mounts.lphc         # /proc/self/mounts, mount_for(), the df table
source/commands/stat.lphc     # run_stat(), run_df()
tests/*_test.lphc             # native unit tests (make test)
tests/helpers.lphc            # expect_text(), files with chosen modes and links
tests/e2e.sh                  # end-to-end tests of build/stat (make e2e)
specs/stat/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
