#!/usr/bin/env bash
# End-to-end tests: run the built binary on files it creates in a
# temporary directory and compare its standard output (or standard error)
# and exit status with the expected ones.
#
# Only fields the test controls are compared: names, sizes, types, modes,
# link counts, link targets, and times set with `touch -t` under a fixed
# TZ. Owners come from `id`; device and inode numbers, blocks and file
# system sizes differ between machines and are only checked for shape.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0
export TZ=UTC0

ok() { pass=$((pass + 1)); }
bad() {
    fail=$((fail + 1))
    echo "FAIL: $1"
    sed 's/^/    stdout: /' "$TMP/out" | head -5
    sed 's/^/    stderr: /' "$TMP/err" | head -5
}

# run ARGS...: runs BINARY in $TMP/f with standard input from /dev/null;
# sets $status.
run() {
    (cd "$TMP/f" && "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err")
    status=$?
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]: exact standard output.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    run "$@"
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out"; then
        ok
    else
        bad "$name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/out" | sed 's/^/    /' | head -10
    fi
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]: exact standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    run "$@"
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/err"; then
        ok
    else
        bad "$name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/err" | sed 's/^/    /' | head -10
    fi
}

# expect_line NAME N EXPECTED: line N of the last standard output.
expect_line() {
    local got
    got=$(sed -n "$2p" "$TMP/out")
    if [ "$got" = "$3" ]; then ok; else bad "$1: line $2 is '$got', expected '$3'"; fi
}

try=$'Try \'stat --help\' for more information.\n'

# --- the files ------------------------------------------------------------------
mkdir -p "$TMP/f/dir"
cd "$TMP/f" || exit 1
head -c 5000 /dev/zero > data
chmod 640 data
ln data data.link
: > empty
chmod 600 empty
ln -s data sym
ln -s 'sp ace' quoted
printf 'x\n' > 'sp ace'
chmod 644 'sp ace'
printf 'q\n' > "it's"
chmod 644 "it's"
mkfifo pipe
chmod 644 pipe
chmod 751 dir
chmod 4755 data.link 2>/dev/null
touch -t 202001020304.05 data
cd - > /dev/null || exit 1
me=$(id -u)
myname=$(id -un)

# --- help and version ---------------------------------------------------------------
check "version" 0 $'stat (loup-cmd-stat) 0.1.0\n' --version
run --help
if [ "$status" -eq 0 ] && head -1 "$TMP/out" | grep -qx 'Usage: stat \[OPTION\]... FILE...'; then ok; else bad "help"; fi

# --- -c directives ------------------------------------------------------------------
check "name, size, type, mode, links" 0 $'data 5000 regular file 4755 -rwsr-xr-x 2\n' \
    -c '%n %s %F %a %A %h' data
check "an empty file"   0 $'regular empty file 0600 -rw-------\n'   -c '%F %04a %A' empty
check "a directory"     0 $'directory 751 drwxr-x--x\n'             -c '%F %a %A' dir
check "a fifo"          0 $'fifo prw-r--r--\n'                      -c '%F %A' pipe
check "a symbolic link" 0 $'symbolic link 4 lrwxrwxrwx\n'           -c '%F %s %A' sym
check "-L follows it"   0 $'sym regular file 5000\n'                -L -c '%n %F %s' sym
check "raw mode in hex" 0 $'89ed 0x89ed\n'                          -c '%f %#f' data
check "octal flags"     0 $'4755|04755|  4755|0004755\n'            -c '%a|%#a|%6a|%07a' data
check "%N quoting"      0 $'\'sym\' -> \'data\'\n\'quoted\' -> \'sp ace\'\n"it\'s"\n'  -c '%N' sym quoted "it's"
check "width, precision" 0 $'[data      ][dat][00005000][      5000]\n'  -c '[%-10n][%.3n][%08s][%10s]' data
check "unknown directive" 0 $'[?][%]\n'                            -c '[%Q][%%]' data
check "one line per file" 0 $'data\nempty\n'                        -c '%n' data empty
check "owner"           0 "$me $myname
"  -c '%u %U' data
check "block size"      0 $'512\n'                                  -c '%B' data

# --- times (touch -t under TZ=UTC0) -------------------------------------------------------
check "modify time"     0 $'2020-01-02 03:04:05.000000000 +0000\n'  -c '%y' data
check "seconds"         0 $'1577934245|1577934245.000|1577934245.000000000\n'  -c '%Y|%.3Y|%.Y' data
export TZ='<+0530>-5:30'
check "another time zone" 0 $'2020-01-02 08:34:05.000000000 +0530\n'  -c '%y' data
export TZ=UTC0

# --- --printf -----------------------------------------------------------------------------------
check "escapes"         0 $'data\t5000\nAA"\\\n'                    --printf='%n\t%s\n\x41\101\"\\\n' data
check "no newline added" 0 'dataempty'                             --printf='%n' data empty
check_err "unknown escape" 0 $'stat: warning: unrecognized escape \'\\q\'\n'  --printf='\q' data
check "-c keeps backslashes" 0 $'data\\t\n'                        -c '%n\t' data

# --- default and terse reports ---------------------------------------------------------------
run data
expect_line "default report"  1 '  File: data'
expect_line "default report"  4 "Access: (4755/-rwsr-xr-x)  Uid: ($(printf '%5s' "$me")/$(printf '%8s' "$myname"))   Gid: ($(printf '%5s' "$(id -g)")/$(printf '%8s' "$(id -gn)"))"
expect_line "default report"  6 'Modify: 2020-01-02 03:04:05.000000000 +0000'
if sed -n 2p "$TMP/out" | grep -q '^  Size: 5000      	Blocks: [0-9]* *IO Block: [0-9]* *regular file$'; then ok; else bad "size line"; fi
if [ "$(wc -l < "$TMP/out")" -eq 8 ]; then ok; else bad "eight lines"; fi
run sym
expect_line "a link's name line" 1 '  File: sym -> data'
run -t data
if [ "$(cut -d' ' -f1,2,4,9 "$TMP/out")" = "data 5000 89ed 2" ] && [ "$(wc -w < "$TMP/out")" -eq 16 ]; then ok; else bad "terse"; fi

# --- standard input -----------------------------------------------------------------------------
(cd "$TMP/f" && "$BIN" -c '%F %s' - < data > "$TMP/out" 2> "$TMP/err")
if [ "$(cat "$TMP/out")" = "regular file 5000" ]; then ok; else bad "- is standard input"; fi

# --- file systems ----------------------------------------------------------------------------
check "-f name"        0 $'.\n'                                     -f -c '%n' .
run -f -t .
if [ "$status" -eq 0 ] && [ "$(wc -w < "$TMP/out")" -eq 11 ]; then ok; else bad "-f -t: eleven fields"; fi
run -f .
expect_line "-f report" 1 '  File: "."'
if sed -n 2p "$TMP/out" | grep -q '^    ID: [0-9a-f]* *Namelen: [0-9]* *Type: .'; then ok; else bad "-f ID line"; fi
run --df .
if head -1 "$TMP/out" | grep -q '^Filesystem  *1K-blocks  *Used  *Available Use% Mounted on$'; then ok; else bad "--df header"; fi
if [ "$status" -eq 0 ] && [ "$(wc -l < "$TMP/out")" -eq 2 ]; then ok; else bad "--df FILE: one file system"; fi
if sed -n 2p "$TMP/out" | grep -q ' [0-9][0-9]*  *[0-9][0-9]*  *[0-9][0-9]*  *[0-9-]*%* /'; then ok; else bad "--df row"; fi
run --df
if [ "$status" -eq 0 ] && head -1 "$TMP/out" | grep -q '^Filesystem .*Mounted on$' && [ "$(wc -l < "$TMP/out")" -ge 2 ]; then ok; else bad "--df listing"; fi

# --- errors ----------------------------------------------------------------------------------------
check_err "missing file"     1 $'stat: cannot stat \'nope\': No such file or directory\n'  nope
check "the rest is reported" 1 $'data\n'                            -c '%n' nope data
check_err "not a directory"  1 $'stat: cannot stat \'data/x\': Not a directory\n'  data/x
check_err "-f missing"       1 $'stat: cannot read file system information for \'nope\': No such file or directory\n'  -f nope
check_err "quoted in messages" 1 $'stat: cannot stat "no\'pe": No such file or directory\n'  "no'pe"
check_err "missing operand"  1 "stat: missing operand
$try"
check_err "invalid option"   1 "stat: invalid option -- 'q'
$try"  -q data
check_err "missing format"   1 "stat: option requires an argument -- 'c'
$try"  -c
check_err "ambiguous"        1 "stat: option '--d' is ambiguous; possibilities: '--dereference' '--df'
$try"  --d data
check_err "bad --cached"     1 "stat: invalid argument 'x' for '--cached'
Valid arguments are:
  - 'default'
  - 'never'
  - 'always'
$try"  --cached=x data
check_err "unfinished directive" 1 $'stat: \'%-\': invalid directive\n'  -c '%-' data

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
