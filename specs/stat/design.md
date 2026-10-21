# Design: stat

## Overview

`main()` hands `runtime.args()` to `cli.app.run`, which parses the options
into `Options` and calls `commands.stat.run_stat`. That checks the C struct
layouts, loads the time zone, and for each FILE asks `sys.libc` for a
`FileStatus` (or, with `-f`, an `FsStatus`), then expands the format with
`format.printf.expand` over a `FieldSource` from `format.fields`. `--df`
reads the mount table (`df.mounts`) and prints a table. All sources are
`@mode(host.native)` `.lphc` files.

## Lane

Everything is built by Stage0: `make check` (`loup-bootstrap check`), the
binary (`loup-bootstrap build --target native`) and the unit tests
(`loup-bootstrap test --native`). The FFI features this program is about
(`@repr(C)` structs passed as `edits`, `NativeHandle` returns and struct
members, `size_of`) are `ok` in FEATURES.md's Stage0-native column, and one
compiler for the binary and the tests means one set of rules. The rules it
brings: no `match` on strings (if/else chains), and `containsKey()` with a
key built by `str(n)` is unreliable (keys are interpolated instead).

## Modules

| Module | Contents |
|---|---|
| `source/main.lphc` | entry point |
| `source/appinfo.lphc` | name, version, exit statuses |
| `source/cli/args.lphc` | `Options`, `parse_args` (getopt-style) |
| `source/cli/usage.lphc` | `usage()`, `version_line()` |
| `source/cli/app.lphc` | `run()`: parse, help/version, usage errors |
| `source/sys/cstructs.lphc` | `@repr(C)` structs, blank constructors, `CText` bytes, `c_size`, `layout_errors` |
| `source/sys/libc.lphc` | `extern native` declarations, `CBuffer`, `c_text`, errno, `FileStatus`, `FsStatus`, user and group names |
| `source/sys/clock.lphc` | `localtime_r` + `strftime`: `local_time_text` |
| `source/format/modes.lphc` | file types, `mode_string`, major/minor, fs type names, bases |
| `source/format/printf.lphc` | `Field`, `Directive`, `FieldSource`, `expand`, escapes, `format_problem` |
| `source/format/fields.lphc` | `FileFields`, `FsFields`, default and terse formats, `shell_quote` |
| `source/df/mounts.lphc` | `parse_mounts`, `mount_for`, `listing_rows`, `df_row`, `df_table` |
| `source/commands/stat.lphc` | `run_stat`, `run_df` |

## The C boundary

- Each C struct is a `@repr(C) struct` with C's field names and prefixes,
  used by no other type (the native back end places struct fields by name
  program-wide). Sizes are checked with `size_of` at start-up; `size_of`
  only measures a struct in its own module, so `sys.cstructs` answers for
  all of them (`c_size`, `layout_errors`).
- A struct goes to C as `edits buf: StatBuf` (a pointer); C fills it; the
  wrapper copies what it needs into a class (`FileStatus`, `FsStatus`)
  before returning, so no C struct travels.
- `NativeHandle` is opaque: no `+`, no `==`, no NULL. Hence:
  - C text is read with `memcpy` into `CText` (eight `uint64` words) 64
    bytes at a time; to start k bytes in, `mempcpy` over a private copy
    returns the address k bytes in (`c_text`).
  - "not found" from `getpwuid_r`/`getgrgid_r` is read from a `PtrCell`
    (`struct passwd **` as a `uint64` address), not from a handle.
  - `realpath` is only called after `stat` succeeded, because its NULL
    return cannot be tested.
- `CBuffer` owns `malloc` memory; `finalize()` frees it.

## Formats

`expand` makes one pass over the format: text, `%%`, directives
`%[flags][width][.precision]conversion` (two-letter `Hd Ld Hr Lr`), and with
`--printf` backslash escapes, so an escaped `%` never starts a directive.
`render` applies printf rules per field kind: text (precision cuts),
decimal/octal/hex numbers (precision = minimum digits, `#` prefix, `0`
padding), and seconds (precision = decimals; a lone `.` = 9). `-c` prints a
newline after each expansion.

## Error handling

- `Err(errno)` from the libc wrappers; messages from `strerror`.
- Usage errors as `Err(message)` from `parse_args`, printed with the hint.
- A format that ends inside a directive is refused before any output.

## Testing

- Unit tests (`tests/*_test.lphc`, native binaries): struct sizes, the
  libc layer on files the tests create (sizes, modes, links, long link
  targets, errno, root's names, statvfs), local time under fixed `TZ`
  values, mode strings and type names, the format engine, the directives
  on real files, mount-table parsing and the df table, options, exit
  statuses.
- End-to-end (`tests/e2e.sh`): deterministic fields on files with set
  sizes, modes, links and `touch -t` times under `TZ=UTC0`; the default,
  terse and `-f` reports' shape; `--df`; every error message.

## Differences from GNU stat

See the README.
