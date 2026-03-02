# Bash Style Guide

Prescriptive conventions for bash code under `IFS=$'\n'; set -o noglob`. Techniques are general; examples use standalone script style unless demonstrating library conventions.

## 1. Shebang and Version

`#!/usr/bin/env bash`. Bash 4.4+ minimum (for `${var@Q}`).

File extensions: `.bash` for libraries, no extension for executables.

## 2. Safety Preamble

Two tiers: libraries and scripts.

**Libraries**: expect `IFS=$'\n'` and noglob from their callers, no `set -e` — callers own error policy. The library files themselves don't set these; consumers do after sourcing (see boilerplate below). Some libraries handle IFS internally per-function with `IFS='' read -r`.

Consumers set this after sourcing:

```bash
IFS=$'\n'
set -o noglob
```

**Scripts**: defer strict mode until after option parsing. Option parsing uses `$*` unquoted and tests `${1:-}`, which interact poorly with `set -eu` before args are validated.

Standard for new scripts: `set -euo pipefail`. Add `f` if noglob is not already set (`f` is equivalent to `set -o noglob`). Libraries should not force strict mode on their consumers.

The `return 2>/dev/null` line before strict mode enables interactive debugging by sourcing the script without executing main.

**Library consumer boilerplate**:

```bash
source ~/.local/lib/mylib.bash 2>/dev/null || { echo 'fatal: mylib.bash not found' >&2; exit 1; }

# enable safe expansion
IFS=$'\n'
set -o noglob

return 2>/dev/null    # stop if sourced, for interactive debugging
main $*               # entry point — library consumers may strip parsed options first
```

**Script bottom**:

```bash
# strict mode
return 2>/dev/null
set -euo pipefail
set -o noglob

main "$@"
```

## 3. Naming

Every file has a Naming Policy header comment (see template below). The rules:

- **Functions** (libraries): `namespace.PascalCase` (public), `namespace.camelCase` (private). Namespace is the project name lowercase (e.g., `lib.`). Libraries are sourced by others and need namespace collision protection; standalone scripts use plain `PascalCase`/`camelCase` (see Standalone scripts below).
- **Locals**: `camelCase` — begin with lowercase. Compound words that are single semantic concepts stay lowercase: `filename`, `testname`, `fieldname` (not `fileName`, `testName`, `fieldName`). Arrays use plural names (`testnames`, `filenames`, `requestedTests`); scalars use singular. Unpack positional parameters on one `local` line: `local got=$1 want=$2`, `local msg=$1 rc=${2:-$?}`.
- **Globals**: `PascalCase` — begin with uppercase. Libraries append a randomly-chosen project-specific suffix letter (e.g., `DebugQ`, `ShowProgressQ`, `TimeFuncQ`) to prevent namespace collisions. Globals are not public — create accessor functions if consumers need them. Standalone scripts omit the suffix.
- **Namerefs**: `local -n UPPERCASE=$1` — borrows the environment variable namespace (all-caps). Namerefs point to the caller's variable, so they need names that won't collide with any local. UPPERCASE is safe because locals are always camelCase.
- **"List" in names**: functions that serialize arrays into newline-separated strings use "List" — `ListOf()`, `StreamList()`. Variables holding serialized lists also use the name (e.g., `commands_` — with `_` because it contains IFS characters).
- **Standard globals** (suffix exceptions): `NL=$'\n'` for string interpolation in double quotes. `Prog=$(basename "$0")` is standard in scripts that report their own name. These are conventional exceptions to the suffix rule.
- **Standalone scripts**: no namespace prefix on functions, no suffix letter on globals — not sourced by others, so no collision risk.

Example header (library):

```bash
# Naming Policy:
#
# All function and variable names are camelCased.
#
# Private function names begin with lowercase letters.
# Public function names begin with uppercase letters.
# Function names are prefixed with "lib." (always lowercase) so they are namespaced.
#
# Local variable names begin with lowercase letters, e.g. localVariable.
#
# Global variable names begin with uppercase letters, e.g. GlobalVariable.
# Since this is a library, global variable names are also namespaced by suffixing them with
# the randomly-generated letter Q, e.g. GlobalVariableQ.
# Global variables are not public.  Library consumers should not be aware of them.
# If users need to interact with them, create accessor functions for the purpose.
#
# Variable declarations that are name references borrow the environment namespace, e.g.
# "local -n ARRAY=$1".
```

## 4. Namespace Suffix

Single letter per library appended to all globals and DI vars. Prevents collisions when libraries are sourced together. Choose a random letter per library — described as "randomly-generated" in headers.

Standalone scripts omit the suffix — not sourced by others, so no collision risk.

```bash
TimeFuncQ=UnixMilli   # DI variable
ShowProgressQ=1       # global
DebugQ=0              # global
```

## 5. Quoting

`_` suffix on variables means "may contain IFS characters, must quote." Variables without `_` are safe unquoted under `IFS=$'\n'; set -o noglob`.

In practice: `commands_` (trap output), `content_` (file contents), `usage_` (multiline heredoc).

Nameref collision avoidance uses a separate strategy: UPPERCASE names (see Naming).

**`printf %q`** escapes a value for shell re-evaluation (eval-safe):

```bash
printf -v output '%q ' "$@"    # output is safe to eval
```

**`${var@Q}`** renders a human-readable quoted literal. Used for debug output and test copy-paste lines:

```bash
CMD="sudo -u ${RunAsUser@Q} bash -c ${CMD@Q}"    # readable in logs
echo "want=${got@Q}"                                # tests — paste to update expected value
```

**`read -r` discipline**: always use `read -r` to avoid backslash interpretation. Prefer `IFS='' read -r` when consuming raw lines (see FP Pipeline Helpers for the canonical pattern).

**Avoid braces in expansion.** `$var`, not `${var}` — braces add noise for no benefit when the variable name is unambiguous. For disambiguation when text follows the name, prefer quotes over braces: `"$var"Suffix` concatenates the quoted expansion with the literal. Use braces when the variable is embedded mid-string and quotes can't delimit it: `"prefix${var}suffix"`.

**Array/positional expansion**: `"${array[@]}"` and `"$@"` preserve element boundaries — each element stays a separate word. `"$*"` joins elements with the first character of IFS (useful for serialization). Unquoted, both `${array[@]}` and `$@` undergo word splitting on IFS, so elements containing newlines get broken apart. Under `set -u`, an empty array needs `${args[@]:-}` as fallback.

**Quoting decision tree.** Walk this algorithm for any expansion you're unsure about:

1. **No-split context?** Assignment RHS, `[[ ]]` (except RHS of `==` and `=~`), `(( ))`, `case`, array subscripts, `${...}` operators, redirections, here-strings — quoting is unnecessary. These contexts never split or glob regardless of IFS/noglob settings.
2. **`_`-suffixed variable?** Contains IFS characters (newlines). Must quote in non-assignment contexts: `echo "$Usage_"`, `eval "$testSource_"`.
3. **Required-quoting context?** Array expansion (`"${arr[@]}"`), RHS of `==` in `[[` (for literal match), `eval` arguments, `trap` strings, external command arguments, process substitution with multi-line content — must quote. See the full list below.
4. **Otherwise** — safe unquoted under `IFS=$'\n'; set -o noglob`. The variable has no `_` suffix (newline-free by convention), and the context is a shell builtin or function call with scalar arguments.

**Why not quote everything?** Under IFS+noglob, selective quoting signals intent. Quotes mean "this value needs protection" — either it contains IFS characters, or the context demands exact word boundaries. Quoting every expansion adds noise without adding safety, and obscures which values actually require care. When a reviewer sees quotes, they should be able to trust that those quotes are there for a reason.

**When to quote.** Under `IFS=$'\n'; set -o noglob`, most scalar expansions are safe unquoted. Quotes are required in these contexts:

- **Trust boundaries and the `_` suffix** — assigning a parameter to a non-`_` variable documents that it won't contain IFS characters: `local command=$1` means "I expect single-line input." If a parameter may contain newlines, assign to a `_`-suffixed variable and quote from there.
- **`"${array[@]}"` / `"$@"` / `"$*"`** — quote to preserve element boundaries (see above). Unquote only when IFS splitting is intentional (e.g., populating arrays from command output: `local arr=( $(command) )`).
- **RHS of `==` in `[[`** — `[[ $x == "$y" ]]` for literal match. Unquoted RHS is a glob pattern: `*`, `?`, `[` become wildcards. Leave unquoted for intentional pattern matching: `[[ $OSTYPE == darwin* ]]`.
- **RHS of `=~` in `[[`** — quoting disables regex metacharacter interpretation in bash 3.2+ (`.` becomes literal dot, `*` loses repetition meaning), though the regex engine is still in use. Leave unquoted for regex matching (the common case): `[[ $x =~ ^[0-9]+$ ]]`. For complex patterns, store in a variable: `local pattern='^[0-9]+$'; [[ $x =~ $pattern ]]`.
- **`_`-suffixed variables** in non-assignment contexts — contain IFS characters (newlines), must quote: `eval "$testSource_"`, `echo "$Usage_"`.
- **`eval` arguments** — `eval "$CMD"`. Without quotes, newlines become argument separators; `eval` joins arguments with spaces, changing multi-line code semantics.
- **Command substitution as argument** — a judgment call. `func "$(command)"` when the result should be a single word. Unquoted `$(command)` splits on newlines, which is sometimes desired: `local arr=( $(listItems) )`.
- **`trap` command strings** — `trap "$command$NL$(existing)" EXIT`. The string is stored for later eval; must be a single coherent argument.
- **Process substitution with multi-line content** — `diff <(echo "$got") <(echo "$want")`. Unquoted `echo $var` splits on newlines into separate arguments; echo outputs them space-separated, destroying line structure.
- **External command arguments** — `mkdir -p "$dir"`, `install -m "$mode"`, `ssh-keygen -f "$file"`. Without noglob, unquoted values undergo pathname expansion before the command sees them. Scripts using `set -euo pipefail` without `f` need this; code following these conventions quotes external command args consistently regardless.

**When quoting is unnecessary.** These contexts never split or glob — quoting is harmless but adds no safety:

- **Assignment RHS** — `local var=$value`, `var=$(command)`, `var=${1:-default}`. Bash assigns the full expansion without splitting.
- **`[[ ]]` operands** (except RHS of `==` and `=~`) — `[[ -e $file ]]`, `[[ $var == pattern ]]` (LHS). The conditional command suppresses splitting.
- **`(( ))` arithmetic** — `(( rc == 0 ))`, `(( ${#array[@]} ))`. Arithmetic context, not string context.
- **`case` word** — `case $var in`. No splitting.
- **Array subscripts** — `${map[$key]}`, `array[$idx]=val`. Inside brackets, no splitting.
- **Inside `${...}` operators** — `${1:-$default}`, `${var#$prefix}`. Nested expansions are protected.
- **Redirection targets** — `>$file`, `<$file`, `<<<$var`. Bash takes the single word.
- **Scalar command arguments** — `func $simplevar`, `printf $fmt $val`. No word-splitting surprises for newline-free values under `IFS=$'\n'; set -o noglob`. This is the default assumption for variables without the `_` suffix. Note: commands still interpret values (printf parses its format string) — quoting controls splitting, not command semantics.

## 6. Variable Scoping

Bash has dynamic scoping: a function can read and modify variables in its caller's scope, even `local` variables. This is the opposite of lexical scoping (C, Python, Go) where a function can only see its own locals and globals.

**Mechanism.** When bash resolves a variable name, it walks up the call stack. A callee's `local x` shadows the caller's `x`, but without `local`, the callee accesses the caller's variable directly. This applies to both reads and writes.

**Deliberate use — callback counting.** A test runner can exploit dynamic scoping intentionally. The callback modifies `passCount` and `failCount`, which are locals in the calling function:

```bash
passCount+=1   # in caller's scope
```

The comment `# in caller's scope` documents the intentional cross-scope access. Without this pattern, the runner would need to pass counters through return values or globals.

**Accidental shadowing — the collision risk.** If a callee declares `local x` and the caller also has `local x`, the callee gets its own copy. But if the callee *doesn't* declare `local` and uses `x`, it silently modifies the caller's `x`. This is especially dangerous with namerefs: `local -n REF=$1` — if `$1` is `REF`, the nameref points to itself (circular reference).

**Defenses:**

- **Naming conventions** are the primary protection. `camelCase` locals and `PascalCase + suffix` globals occupy separate namespaces. Two callees in the same chain are unlikely to collide if they follow conventions.
- **UPPERCASE namerefs** (`local -n ARRAY=$1`) borrow the environment variable namespace, which never collides with `camelCase` locals in the caller.
- **Subshell `()` function bodies** provide hard isolation when dynamic scoping is unwanted. Changes to variables, working directory, and shell options are discarded when the subshell exits:

```bash
createCloneRepo() (     # () not {} — subshell isolates side effects
  git init clone
  cd clone              # doesn't affect caller's pwd
  echo hello >hello.txt
  git add hello.txt && git commit -m init
) >/dev/null
```

Use `()` when a helper needs to `cd` or modify shell state; use `{}` (the default) when the caller needs to see the function's side effects.

## 7. Conditionals

`[[` exclusively. `[[` is bash's compound command with pattern matching, no word splitting, and `&&`/`||` inside.

**`(( ))` for arithmetic and booleans.** Boolean flags are 0/1 integers tested bare: `(( failed )) && return 1`, `(( hasSubtests )) && echo ...`. Numeric variables use explicit comparison: `(( rc == 0 ))`, `(( pid != 0 ))`. Arithmetic expansion: `$(( endTime - startTime ))`.

## 8. Error Handling

Two patterns coexist.

**`fatal()` with message + optional exit code.** Default rc is `$?`:

```bash
fatal() {
  local msg=$1 rc=${2:-$?}
  echo "fatal: $msg"
  exit $rc
}
```

Libraries namespace this (e.g., `lib.Fatal`) and typically print to stderr.

**Return code 128 as fatal signal.** A test framework can detect 128 and report "fatal" distinct from regular failure:

```bash
case $rc in
  0   ) printf $columns $Pass $duration $testname; passCount+=1;;
  128 ) printf $columns $Fatal $duration $Yellow$testname$Reset;;
  *   ) printf $columns $Fail $duration $Yellow$testname$Reset;;
esac
```

**RC capture**: `cmd && rc=$? || rc=$?` preserves exit code that `set -e` would otherwise lose. Safe under `set -e` because the `||` makes the overall compound command always succeed; `set -e` only triggers on unchecked failures.

```bash
output=$(eval "$cmd" 2>&1) && rc=$? || rc=$?
```

**`pipefail`**: standard for new scripts. `set -euo pipefail`.

**Strict mode escape**: `loosely()` for sourcing optional configs that may not exist or may fail benignly:

```bash
loosely() {
  set +euo pipefail
  "$@"
  set -euo pipefail
}
loosely source /etc/profile.d/optional-tool.sh
```

## 9. Dependency Injection

Assign function names to `PascalCase + suffix` variables. Override in tests:

```bash
# production default
TimeFuncQ=UnixMilli

# in test
TimeFuncQ=mockUnixMilli
```

## 10. Code Organization

**Cuddling**: group related lines together, separate concepts with blank lines. One concept per group — similar to golangci-lint's wsl rules.

**Scripts**: option parsing near bottom, `return 2>/dev/null` (debug hook), strict mode, then main call as last line.

**Libraries**: function definitions only, no main call. Consumer scripts call the entry point.

Library consumers follow boilerplate: source → IFS → noglob → return → entry point.

Standard flags: `-h`/`--help`, `-v`/`--version`, `-x`/`--trace` (`set -x` for debugging). Libraries typically provide an option handler for these.

## 11. Comments

Three placements.

**Function docs** go directly above the definition, no blank line between. Start with the function name:

```bash
# lib.Main runs any test functions in the files given as arguments.
# It outputs success or failure.
lib.Main() {
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

## 12. Testing

Test framework conventions.

**Associative array cases** define test data:

```bash
local -A case1=(
  [name]='not run when ok'
  [command]="cmd 'echo hello'"
  [ok]=true
  [wants]="(ok 'not run when ok')"
)
```

**Unpack with `Inherit`**. Unset optional fields first so missing keys don't carry over:

```bash
unset -v ok shortrun prog unchg want wanterr
eval "$(Inherit "$casename")"
```

**Run with `RunCases ${!case@}`** — pass all case variables at once:

```bash
RunCases ${!case@}
```

`RunCases` iterates its arguments internally and returns 1 if any case failed, 128 on fatal. For per-case error handling (e.g., early return on fatal), use a loop:

```bash
local failed=0 casename
for casename in ${!case@}; do
  RunCases $casename || {
    (( $? == 128 )) && return 128   # fatal
    failed=1
  }
done
return $failed
```

**Assertion failure output** shows a diff and a copy-paste line for easy test updates:

```bash
[[ $got == $want ]] || {
  echo "${NL}cmd: got doesn't match want:$NL$(Diff "$got" "$want")$NL"
  echo "use this line to update want to match this output:${NL}want=${got@Q}"
  return 1
}
```

**Assertion helpers** — the preferred pattern (replaces the manual version above):

```bash
AssertGot "$got" "$want"
AssertRC $rc 0
```

`AssertGot` compares strings, shows a diff and copy-paste update line on mismatch. `AssertRC` compares return codes. Both return 1 on failure.

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

**`MktempDir`** with deferred cleanup (cleanup is registered automatically via `Defer`; see Section 14 for the implementation):

```bash
MktempDir dir || return 128
```

**AAA structure**: `## arrange`, `## act`, `## assert` comment sections in each subtest.

## 13. FP Pipeline Helpers

Stdin-based composition: command name as first arg, applied to each line via `eval`. Core trio: `Each` (side effects), `Map` (transform), `KeepIf`/`RemoveIf` (filter). The `eval "$command $arg"` pattern assumes trusted input — callers are responsible for escaping with `printf %q` if values originate from untrusted sources.

The pattern:

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
each Ln <<'  END'
  .config         ~/config
  .local          ~/local
  .ssh            ~/ssh
  secrets/netrc   ~/.netrc
END
```

Inline versions are common in standalone scripts; a shared library consolidates them with `return 0` guards to prevent error propagation from the last iteration.

## 14. Trap Handling

EXIT traps only — ERR, DEBUG, RETURN, and signal handlers are not used.

**Two patterns coexist**: single assignment (scripts) and stacked (libraries).

**Single assignment** — scripts and test functions that control their own trap:

```bash
dir=$(mktemp -d)
trap "rm -rf $dir" EXIT
```

Direct `trap "..." EXIT` overwrites any previous handler. Safe when the function or script owns its entire trap lifecycle.

**Stacked/deferred** — libraries that must not overwrite the caller's trap:

```bash
Defer() {
  local command=$1
  local NL=$'\n'
  trap "$command$NL$(existingDeferlist)" EXIT
}
```

New handlers prepend to the existing chain. `existingDeferlist` extracts the current handler via `trap -p EXIT` and strips the wrapper syntax. Commands execute in FIFO order. Use newlines (not semicolons) as separators — semicolons interact poorly with backgrounding (`&`).

**Temp directory cleanup** — the canonical pattern:

```bash
MktempDir() {
  local -n DIR=$1
  DIR=$(mktemp -d /tmp/bash.XXXXXX) || { echo 'could not create temporary directory'; return 1; }
  [[ $DIR == /*/* ]] || { echo 'temporary directory does not comply with naming requirements'; return 1; }
  [[ -d $DIR ]] || { echo 'temporary directory was made but does not exist now'; return 1; }
  Defer "rm -rf $DIR"
}
```

Validates the path before registering cleanup. The `/*/* ` guard prevents `rm -rf /` if `mktemp` returns something unexpected.

## 15. Risks and Limitations

`IFS=$'\n'` + noglob + naming conventions eliminate most bash footguns, but not all. Each risk below describes the bash mechanism, how it bites, and the mitigation.

**1. Dynamic scoping collision.** A callee that omits `local` silently modifies the caller's variable. A nameref whose name matches its target creates a circular reference:

```bash
outer() { local x=before; inner; echo $x; }   # prints "after" — inner modified outer's x
inner() { x=after; }                           # no local — writes to caller's scope

wrapper() { local -n REF=$1; REF=value; }
wrapper REF   # circular reference — bash emits "circular name reference" error
```

**Mitigation:** follow naming conventions (Section 3) — `camelCase` locals, `UPPERCASE` namerefs. Document intentional cross-scope access with `# in caller's scope`. See Section 6 for the full explanation.

**2. Eval injection.** The FP helpers execute `eval "$command $arg"` where `$arg` is a line from stdin. If `arg` contains shell metacharacters, they execute as code:

```bash
echo '; rm -rf /tmp/important' | each processLine   # eval runs: processLine ; rm -rf /tmp/important
```

**Mitigation:** only pass trusted input through FP pipelines. For untrusted values, escape with `printf -v safe '%q' "$untrusted"` before piping. The trust boundary is the `eval` call — everything reaching it must be safe to execute as shell words.

**3. `[[` RHS pattern matching.** In `[[ $x == $y ]]`, the unquoted RHS is a glob pattern — `*`, `?`, and `[` are wildcards. This is independent of `set -o noglob`, which only affects pathname expansion in command arguments. `[[` has its own pattern-matching rules:

```bash
want='file[1]'
[[ 'file[1]' == $want ]]    # false — [1] is a character class matching the single character 1
[[ 'file[1]' == "$want" ]]  # true — literal comparison
```

**Mitigation:** quote the RHS for literal comparison: `[[ $x == "$y" ]]`. Leave unquoted only for intentional pattern matching: `[[ $OSTYPE == darwin* ]]`.

**4. Trailing newline stripping.** Command substitution `$(command)` always strips trailing newlines from the output. This is a POSIX requirement, not a bash quirk:

```bash
output=$(printf 'hello\n\n')   # output is "hello" — both trailing newlines stripped
content=$(cat "$file")          # file's trailing newline(s) silently lost
```

**Mitigation:** if trailing newlines matter, append a sentinel and strip it: `output=$(command; echo x); output=${output%x}`. In practice, this rarely matters — most values are single-line identifiers or paths.

**5. `set -e` propagation.** In bash versions before 4.4, `set -e` does not propagate into command substitutions `$(...)`, so failures inside are silently swallowed. Bash 4.4 introduced `shopt -s inherit_errexit` to fix this, but it is **off by default** — you must enable it explicitly. Even with `inherit_errexit`, compound commands inside `$(...)` can still behave unexpectedly. Process substitutions `<(...)` never inherit `set -e` in any version:

```bash
set -e
result=$(false; echo "still runs")    # "still runs" executes — errexit not inherited without inherit_errexit
while read -r line; do
  process "$line"
done < <(failing_command)              # failure undetected — process substitution ignores set -e
```

**Mitigation:** don't rely on `set -e` inside command substitutions. Use explicit RC capture: `result=$(command) && rc=$? || rc=$?`. For critical operations, check `$?` after every command substitution. Alternatively, add `shopt -s inherit_errexit` to the preamble (bash 4.4+) to propagate `set -e` into command substitutions — but process substitutions remain unaffected.

**6. Pipeline subshell variable loss.** Each stage of a pipeline runs in a subshell. Variables modified inside a pipeline stage are lost when it exits:

```bash
count=0
command | while read -r line; do count+=1; done
echo $count   # still 0 — the while loop ran in a subshell
```

**Mitigation:** use process substitution instead: `while read -r line; do count+=1; done < <(command)`. This runs the loop in the current shell while the command runs in the subshell. Code following these conventions avoids piping into loops.

**7. `loosely()` hardcoded restore.** The `loosely()` wrapper does `set +euo pipefail` then `set -euo pipefail` after the command. It doesn't capture the previous shell options — it assumes the caller always uses `-euo pipefail`:

```bash
set -eu              # no pipefail yet
loosely source lib   # sets +euo pipefail, then -euo pipefail
# now pipefail is ON even though caller never set it
```

**Mitigation:** `loosely()` is safe only after `set -euo pipefail` is set. For library code that needs to temporarily relax options, save and restore with `set +o`:

```bash
local prevOpts
prevOpts=$(set +o)        # captures restore commands for all options
set +eu; set +o pipefail
command
eval "$prevOpts"           # restores exact previous state
```

`set +o` outputs `set -o`/`set +o` commands that reproduce the current option state. This handles all options including `pipefail` without fragile string matching.
