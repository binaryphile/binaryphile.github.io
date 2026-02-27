---
layout: post
title: "Bash Style Guide"
date: 2026-02-27
categories: software-engineering
tags: [bash, shell, style-guide]
excerpt: "Conventions derived from five bash projects — naming, error handling, quoting, pipelines. Prescriptive for new code."
---

`deferlist_` has a trailing underscore. `DebugM` ends with a capital M. `local -n RESULT` is all caps. None of this is accidental.

Five bash projects share naming, quoting, error handling, and pipeline conventions that evolved over years — and were never written down in one place. This is the reference, derived from the code.

## 1. Shebang and Version

`#!/usr/bin/env bash`. Bash 4.4+ minimum (for `${var@Q}`).

File extensions: `.bash` for libraries, no extension for executables.

## 2. Safety Preamble

Two tiers: libraries and scripts.

**Libraries** (task.bash, mk.bash, fp.bash): `IFS` and noglob at top, no `set -e` — callers own error policy.

```bash
IFS=$'\n'
set -o noglob
```

**Scripts** (tesht, update-env): defer strict mode until after option parsing. Option parsing uses `$*` unquoted and tests `${1:-}`, which interact poorly with `set -eu` before args are validated.

Standard for new scripts: `set -euo pipefail`. Add `f` if noglob is not already set (`f` is equivalent to `set -o noglob`). mk.bash was designed not to force strict mode on its consumers.

The `return 2>/dev/null` line before strict mode enables interactive debugging by sourcing the script without executing main.

**Library boilerplate** (mk.bash consumer):

```bash
source ~/.local/lib/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 1; }

# enable safe expansion
IFS=$'\n'
set -o noglob

mk.SetProg $Prog
mk.SetUsage "$Usage"
mk.SetVersion $Version

return 2>/dev/null    # stop if sourced, for interactive debugging
mk.HandleOptions $*   # standard options
mk.Main ${*:$?+1}     # showtime
```

**Script bottom** (tesht — new scripts would use `set -euo pipefail`):

```bash
# strict mode
return 2>/dev/null
set -euf

tesht.Main "$(tesht.ListOf "${TestnamesT[@]}")" "$(tesht.ListOf "${FilenamesT[@]}")"
```

## 3. Naming

Every file has a Naming Policy header comment (see template below). The rules:

- **Functions**: `namespace.PascalCase` (public), `namespace.camelCase` (private). Namespace is the project name lowercase (`tesht.`, `task.`, `mk.`, `fp.`).
- **Locals**: `camelCase` — begin with lowercase. Compound words that are single semantic concepts stay lowercase: `filename`, `testname`, `fieldname` (not `fileName`, `testName`, `fieldName`). Arrays use plural names (`testnames`, `filenames`, `requestedTests`); scalars use singular. Unpack positional parameters on one `local` line: `local got=$1 want=$2`, `local msg=$1 rc=${2:-$?}`.
- **Globals**: `PascalCase` — begin with uppercase. Libraries append a (random) project-specific suffix letter (e.g., `DebugM`, `ShowProgressX`, `UnixMilliFuncT`) to prevent namespace collisions. Globals are not public — create accessor functions if consumers need them. Standalone scripts omit the suffix.
- **Namerefs**: `local -n UPPERCASE=$1` — borrows the environment variable namespace (all-caps). Namerefs point to the caller's variable, so they need names that won't collide with any local. UPPERCASE is safe because locals are always camelCase.
- **"List" in names**: functions that serialize arrays into newline-separated strings use "List" — `tesht.ListOf()`, `fp.StreamList()`. Variables holding serialized lists also use the name (e.g., `deferlist_` — with `_` because it contains IFS characters).
- **Standard globals**: `NL=$'\n'` for string interpolation in double quotes. `Prog=$(basename "$0")` is standard in scripts that report their own name (tesht, mk.bash consumers).
- **Keyword functions** (task.bash only): all lowercase, five letters or shorter. These are the task DSL: `cmd`, `desc`, `exist`, `ok`, `runas`, `prog`, `unchg`.
- **Standalone scripts** (update-env): no namespace prefix on functions, no suffix letter on globals — not sourced by others, so no collision risk. Task functions suffixed with `Task` (e.g., `aptUpgradeTask`).

Example header (mk.bash):

```bash
# Naming Policy:
#
# All function and variable names are camelCased.
#
# Private function names begin with lowercase letters.
# Public function names begin with uppercase letters.
# Function names are prefixed with "mk." (always lowercase) so they are namespaced.
#
# Local variable names begin with lowercase letters, e.g. localVariable.
#
# Global variable names begin with uppercase letters, e.g. GlobalVariable.
# Since this is a library, global variable names are also namespaced by suffixing them with
# the randomly-generated letter M, e.g. GlobalVariableM.
# Global variables are not public.  Library consumers should not be aware of them.
# If users need to interact with them, create accessor functions for the purpose.
#
# Variable declarations that are name references borrow the environment namespace, e.g.
# "local -n ARRAY=$1".
```

## 4. Namespace Suffix

Single letter per project appended to all globals and DI vars. Prevents collisions when projects are sourced together. Described as "randomly-generated" in headers.

- `X` = task.bash, `T` = tesht, `M` = mk.bash, `F` = fp.bash
- Standalone scripts omit — update-env has no suffix because it's not sourced by others.

```bash
UnixMilliFuncT=tesht.UnixMilli   # DI variable (tesht)
ShowProgressX=1                   # global (task.bash)
DebugM=0                          # global (mk.bash)
```

## 5. Quoting

`_` suffix on variables means "may contain IFS characters, must quote." Variables without `_` are safe unquoted under `IFS=$'\n'; set -o noglob`.

In practice: `deferlist_` (trap output), `testSource_` (file contents), `Usage_` (multiline heredoc).

Nameref collision avoidance uses a separate strategy: UPPERCASE names (see Naming).

**`printf %q`** escapes a value for shell re-evaluation (eval-safe):

```bash
printf -v output '%q ' "$@"    # mk.bash mk.Cue — output is safe to eval
```

**`${var@Q}`** renders a human-readable quoted literal. Used for debug output and test copy-paste lines:

```bash
CMD="sudo -u ${RunAsUserX@Q} bash -c ${CMD@Q}"    # task.bash — readable in logs
echo "want=${got@Q}"                                # tests — paste to update expected value
```

**`read -r` discipline**: always use `read -r` to avoid backslash interpretation. Prefer `IFS='' read -r` when consuming raw lines (see FP Pipeline Helpers for the canonical pattern).

**Array expansion**: `${args[@]:-}` for optional arrays. An empty array under `set -u` needs the `:-` fallback.

## 6. Conditionals

`[[` exclusively. `[[` is bash's compound command with pattern matching, no word splitting, and `&&`/`||` inside.

**`(( ))` for arithmetic and booleans.** Boolean flags are 0/1 integers tested bare: `(( failed )) && return 1`, `(( hasSubtests )) && echo ...`. Numeric variables use explicit comparison: `(( rc == 0 ))`, `(( pid != 0 ))`. Arithmetic expansion: `$(( endTime - startTime ))`.

## 7. Error Handling

Two patterns coexist.

**`fatal()` with message + optional exit code.** Used in update-env and mk.bash. Default rc is `$?`:

```bash
fatal() {
  local msg=$1 rc=${2:-$?}
  echo "fatal: $msg"
  exit $rc
}
```

mk.bash namespaces this as `mk.Fatal` and prints to stderr.

**Return code 128 as fatal signal.** Used in tesht. The test framework detects 128 and reports "fatal" distinct from regular failure:

```bash
case $rc in
  0   ) printf $columns $PassT $duration $testname; subtestPassCount+=1;;
  128 ) printf $columns $FatalT $duration $YellowT$testname$ResetT;;
  *   ) printf $columns $FailT $duration $YellowT$testname$ResetT;;
esac
```

**RC capture**: `cmd && rc=$? || rc=$?` preserves exit code that `set -e` would otherwise lose. Safe under `set -e` because the `||` makes the overall compound command always succeed; `set -e` only triggers on unchecked failures.

```bash
OutputX=$(eval "$CMD" 2>&1) && RC=$? || RC=$?    # task.bash
```

**`pipefail`**: standard for new scripts. `set -euo pipefail`.

**Strict mode escape**: `loosely()` for sourcing optional configs that may not exist or may fail benignly:

```bash
loosely() {
  set +euo pipefail
  "$@"
  set -euo pipefail
}
loosely source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

## 8. Dependency Injection

Assign function names to `PascalCase + suffix` variables. Override in tests:

```bash
# production default
UnixMilliFuncT=tesht.UnixMilli

# in test
UnixMilliFuncT=mockUnixMilli
```

## 9. Code Organization

**Cuddling**: group related lines together, separate concepts with blank lines. One concept per group — similar to golangci-lint's wsl rules.

**Scripts**: option parsing near bottom, `return 2>/dev/null` (debug hook), strict mode, then main call as last line.

**Libraries**: function definitions only, no main call. Consumer scripts call the entry point.

mk.bash consumers follow boilerplate: source → IFS → noglob → set prog/usage → return → HandleOptions → `mk.Main`.

Standard flags: `-h`/`--help`, `-x`/`--trace` (`set -x` for debugging). mk.bash HandleOptions provides these.

## 10. Comments

Three placements.

**Function docs** go directly above the definition, no blank line between. Start with the function name:

```bash
# tesht.Main runs any test functions in the files given as arguments.
# It outputs success or failure.
tesht.Main() {
```

**Inline comments** explain non-obvious flags, return codes, or surprising behavior:

```bash
local tmpname=$(mktemp -u)   # -u doesn't create a file, just a name
(( $? == 128 )) && return 128 # fatal
local NL=$'\n' # newline works with backgrounding (&) and legal semicolons, semicolon doesn't
```

**Section markers** use a hierarchical style like inverted markdown headers: `#` is the lowest level, `##` is a level up. Rarely more than `##` in practice. Preceded by a blank line:

```bash
# strict mode          ← low-level annotation

## library functions   ← major section

## logging             ← major section
```

## 11. Testing

tesht conventions.

**Associative array cases** define test data:

```bash
local -A case1=(
  [name]='not run when ok'
  [command]="cmd 'echo hello'"
  [ok]=true
  [wants]="(ok 'not run when ok')"
)
```

**Unpack with `tesht.Inherit`**. Unset optional fields first so missing keys don't carry over:

```bash
unset -v ok shortrun prog unchg want wanterr
eval "$(tesht.Inherit "$casename")"
```

**Run with `tesht.Run ${!case@}`** — iterates all variables matching `case*`:

```bash
local failed=0 casename
for casename in ${!case@}; do
  tesht.Run $casename || {
    (( $? == 128 )) && return 128   # fatal
    failed=1
  }
done
return $failed
```

**Assertion failure output** shows a diff and a copy-paste line for easy test updates:

```bash
[[ $got == $want ]] || {
  echo "${NL}cmd: got doesn't match want:$NL$(tesht.Diff "$got" "$want" 1)$NL"
  echo "use this line to update want to match this output:${NL}want=${got@Q}"
  return 1
}
```

**Subshell `()`** for directory isolation in setup helpers — changes to working directory don't leak:

```bash
createCloneRepo() (
  git init clone
  cd clone
  echo hello >hello.txt
  git add hello.txt
  git commit -m init
) >/dev/null
```

**`tesht.MktempDir`** with trap for cleanup:

```bash
local dir=$(tesht.MktempDir) || return 128
trap "rm -rf $dir" EXIT
```

**AAA structure**: `## arrange`, `## act`, `## assert` comment sections in each subtest.

## 12. FP Pipeline Helpers

Stdin-based composition: command name as first arg, applied to each line via `eval`. Core trio: `Each` (side effects), `Map` (transform), `KeepIf`/`RemoveIf` (filter).

The pattern (from update-env):

```bash
each() {
  local command=$1 arg
  while IFS='' read -r arg; do
    eval "$command $arg"
  done
}

keepIf() {
  local command=$1 arg
  while IFS='' read -r arg; do
    eval "$command $arg" && echo "$arg"
  done
  return 0
}

map() {
  local VARNAME=$1 EXPRESSION=$2
  local "$VARNAME"
  while IFS='' read -r "$VARNAME"; do
    eval "echo \"$EXPRESSION\""
  done
}
```

Call site:

```bash
each task.Ln <<'  END'
  .config         ~/config
  .local          ~/local
  .ssh            ~/ssh
  secrets/netrc   ~/.netrc
END
```

Inline versions exist in update-env (`each`, `map`, `keepIf`) and mk.bash (`mk.Each`, `mk.Map`, `mk.KeepIf`). `fp.bash` (`~/projects/fp.bash/`, v0.2) consolidates these as `fp.Each`, `fp.Map`, etc. The library is still evolving — the inline versions in update-env and mk.bash are the proven reference implementations for now.
