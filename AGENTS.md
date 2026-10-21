# AGENTS.md

This repository is `stat`, GNU stat written in the Loup programming
language, as part of the loup-cmd series of example applications. It is a
`host.native` project: every source file is `.lphc`, and everything it
reports comes from the C library through `extern native` calls and
`@repr(C)` structs laid out for Linux x86-64 with glibc, so the program only
runs as a native binary.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership
(`edits`, `@repr(C)`), execution modes and projects, errors and diagnostics,
the standard library, and common mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.lphc                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.lphc             # APP_NAME, APP_VERSION, exit statuses
│   ├── cli/
│   │   ├── args.lphc            # class Options, parse_args()
│   │   ├── usage.lphc           # usage(), version_line()
│   │   └── app.lphc             # run(): parse, help/version, usage errors
│   ├── sys/
│   │   ├── cstructs.lphc        # @repr(C) StatBuf, StatxBuf, VfsBuf, FsBuf, TmBuf, PasswdBuf, GroupBuf, CText; c_size(), layout_errors()
│   │   ├── libc.lphc            # extern native libc; CBuffer, c_text(), last_errno(); FileStatus, FsStatus, user_name(), group_name()
│   │   └── clock.lphc           # local_time_text(): localtime_r + strftime
│   ├── format/
│   │   ├── modes.lphc           # file_type_name(), mode_string(), major_of(), minor_of(), fs_type_name()
│   │   ├── printf.lphc          # Field, Directive, interface FieldSource, expand(), format_problem()
│   │   └── fields.lphc          # FileFields, FsFields, default/terse formats, shell_quote()
│   ├── df/
│   │   └── mounts.lphc          # parse_mounts(), mount_for(), listing_rows(), df_row(), df_table()
│   └── commands/
│       └── stat.lphc            # run_stat(), run_df()
├── tests/
│   ├── *_test.lphc              # native unit tests: func test_*(): void
│   ├── helpers.lphc             # expect_text(), make_file(), make_hard_link(), make_symlink(), make_fifo()
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/stat/                  # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Linux x86-64 with glibc, Loup 1.26.0 (`loup` and
`loup-bootstrap` on `PATH`), `make`, and `clang` 17 or later.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run | `make run ARGS="-c '%n %F %A' /etc/passwd"` | builds `build/stat`, then runs it: `loup run` cannot call libc |
| Type-check | `make check` | checks `source/main.lphc` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.lphc`, each test built as a native binary (about 1 s each) |
| Run matching tests | `make test TEST_ARGS="--filter escape"` | tests whose name contains `escape` |
| Run one test file | `make test TEST_ARGS="--file tests/printf_test.lphc"` | |
| Build | `make build` | native binary at `build/stat` (`loup-bootstrap build --target native`) |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/stat` on files it creates in a temporary directory |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/stat --version` |
| Clean | `make clean` | removes `build/`, `.temp/` and `.loup-cache/` |

Run `make ci` before reporting a change as done.

The Makefile uses `loup-bootstrap` (Stage0) for every step: the self-hosted
`loup` refuses `check`, and Stage0 runs `host.native` test files through the
native AOT pipeline in a temporary package outside the repository. That is
why `LOUPPATH` is absolute (`$(CURDIR)/source:$(CURDIR)/tests`). Each test
binary runs in that temporary directory, so tests that need files create
them with relative names.

## Making a change

1. Update the spec in `specs/stat/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/stat/tasks.md`.

Keep the C calls in `sys/`: every wrapper copies what it needs out of the C
struct into a class before it returns. Only `commands/stat.lphc` and
`cli/app.lphc` print.

## Conventions

- Every source file is `@mode(host.native)` with the `.lphc` extension. Only
  `source/main.lphc` has a `main()`.
- Modules import each other by path from `source/`:
  `from sys.libc import (file_status);`. Tests import them the same way. Do
  not use relative imports.
- C structs keep C's field names and prefixes (`st_`, `stx_`, `f_`, `fs_`,
  `tm_`, `pw_`, `gr_`, `ct_`), and no other type may use those names: the
  native back end places struct fields by name across the whole program.
  Construct them only in `sys/cstructs.lphc` (the `blank_*` functions), and
  measure them there (`size_of` refuses a struct from another module). A new
  struct also needs a line in `layout_errors()`.
- Records that cross modules are classes, not structs.
- Loup 1.26.0 native-lane pitfalls this code works around:
  - `match` on a `string` always takes the `_` arm in Stage0 native code: use
    `if (s == "x") ... else if` chains (see `FileFields.field`).
  - `d.containsKey(k)` misses a key that `str(n)` built in Stage0 native
    code; build such keys with interpolation (`i"{$ n $}"`).
  - Backslash escapes inside `i"..."` are not decoded by every toolchain:
    concatenate `"\n"` instead.
  - `expectEq` on two equal strings fails in native tests: use
    `expect_text(actual, expected, context)` from `tests/helpers.lphc`.
  - A test file that does not compile is skipped silently. A full
    `make test` therefore fails unless it ran every `test_` function; find
    the broken file with `LOUPPATH=source:tests loup-bootstrap run tests/FILE`.
- Keep `APP_VERSION` in `source/appinfo.lphc` equal to `version` in
  `package.lppkg`.
- The skill documents toolchain 1.25.1; this project targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
