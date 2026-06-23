# Bash Style Guide

Default-IFS bash is a field of footguns. `for f in $files` breaks on filenames with spaces; `[[ $x == $y ]]` accidentally glob-matches; defensive quoting becomes universal and obscures which expansions actually need protection. The bash you write fights you, and the noise it generates fights the reader. This guide describes a disciplined alternative — `IFS=$'\n'` and `set -o noglob` as a floor, plus the naming, quoting, comment, and layout conventions that the floor makes possible. Once the floor is in place, code can drop noise quoting, lean on visible naming for safety contracts, and use shape and whitespace to make structure legible at a glance. The unifying theme is visual expressiveness: bash code is communication to the reader's eye before it is instruction to the parser.

## The frame: visual expressiveness

A reader scanning a well-written bash function sees, in this order: blank-line stanzas marking conceptual seams; cuddled near-duplicate lines whose differing token is the only column that doesn't repeat; aligned columns of `)`, `=`, `#`, or `&&` that turn parallel structure into a visual table; and one-line predicates whose syntactic shape matches their semantic meaning. Words come last. The aesthetic conventions below — naming suffixes, comment placement, file order, layout choices — exist to support that reading order. Correctness rules (quoting, error handling, scoping) sit alongside; they derive from bash semantics rather than aesthetics, but the same discipline of "let the visible shape carry intent" runs through both.

Harmony has two paths to one goal: let the eye lock into a frame so only the variations register.

**Cuddling** works when lines can be made structurally similar. The repeated parts become a chorus the eye stops reading after the first instance; the differing token leaps out as the only column that doesn't repeat. Three siblings stacked vertically with one varying token communicate their relationship before the reader parses any of it.

**Breathing** works when lines must differ — different operations, different shapes. A blank line tells the eye "different thought, reset your frame." The reader accepts each line on its own terms instead of hunting for a chorus that isn't there.

Three failure modes break harmony, all testable by inspection. **False cuddling** — adjacent lines share visual layout but not semantic role, forcing the reader to re-parse each line individually because the chorus turns out to be misleading. **Missing breathing** — branches with materially different structure pack into one visual block instead of being separated by blank lines. **Broken symmetry** — an established pattern is violated without semantic justification, like one entry in an aligned data structure using a different shape. If none of these failure modes applies to a piece of code being criticized, the criticism is aesthetic intuition, not analysis.

## Shebang and bash version

`#!/usr/bin/env bash`. Bash 4.4 or newer (for `${var@Q}`). Libraries use the `.bash` extension; executables have no extension.

## Safety preamble

**Libraries** leave strict mode and IFS to their callers. Library files themselves don't set `set -e`, `IFS=$'\n'`, or noglob; consumers do that after sourcing. This lets a library be sourced into a shell whose error policy the library has no business overriding.

**Scripts** defer strict mode until after option parsing. Option parsing inspects `${1:-}` and uses unquoted `$*`; both interact poorly with `set -eu` before args are validated. The standard for a new script is `set -euo pipefail`. Add `f` (equivalent to `set -o noglob`) if noglob isn't already on.

Place the sourcing-test guard before strict mode. Tests source the script and call individual functions; functions written under IFS+noglob+`set -u`+pipefail behave differently without those settings, so testing without them gives false confidence. But `set -e` after a source call kills an interactive shell on any failed command, and most failed commands in interactive use are intentional probes. Split the boilerplate: function-correctness discipline above the `return 2>/dev/null` guard, interactive-shell-killer below.

Script bottom (sourceable for testing):

```bash
IFS=$'\n'
set -o noglob
set -uo pipefail

return 2>/dev/null    # stop here if sourced — tests get the functions without set -e

set -e
main "$@"
```

Library-consumer boilerplate mirrors the shape:

```bash
source ~/.local/lib/mylib.bash 2>/dev/null || { echo 'fatal: mylib.bash not found' >&2; exit 1; }

IFS=$'\n'
set -o noglob

return 2>/dev/null
main $*
```

## Naming

Names are the documentation. A reader who sees a name should know what discipline applies without grepping. A `_` suffix means "may contain newlines or be empty; must quote on expansion." A `*List` suffix means "serialized list in a single string, IFS-separated." An UPPERCASE name in a nameref position means "this is a cross-scope return slot, never collides with a camelCase local." A `cmd.PascalCase` function in an mk.bash script is the framework's marker for a user-invocable subcommand.

### Functions

Libraries use `namespace.PascalCase` for public functions and `namespace.camelCase` for private ones, where the namespace is the project name lowercased (e.g. `lib.`). The namespace prevents collisions when two libraries are sourced together.

Standalone scripts skip the namespace. mk.bash entry points use `cmd.PascalCase`; everything else — helpers in mk.bash scripts, all functions in non-mk.bash standalone tools — uses plain camelCase. The mk.bash `cmd.` prefix is a framework affordance, not a general pattern. Do not introduce script-local sub-namespaces like `forward.*` or `module.*` in a standalone script. The script's name on disk is already the namespace; an extra dot-prefix ornaments the surface for nothing.

### Locals

camelCase, lowercase initial. Compound words that name a single semantic concept stay lowercase: `filename`, `testname`, `fieldname` — not `fileName`, `testName`. Arrays use plural names (`testnames`, `requestedTests`); scalars use singular. Unpack positional parameters on one `local` line: `local got=$1 want=$2`, `local msg=$1 rc=${2:-$?}`.

### Globals

PascalCase, uppercase initial. Libraries append a randomly chosen project-specific suffix letter — `DebugQ`, `ShowProgressQ` — to prevent collisions when multiple libraries are sourced together. Standalone scripts omit the suffix.

Mutability is encoded in case. Default globals are *bootstrap-initialized*: written once at startup (sourced registries, function-populated lookup tables, parsed-arg arrays) and never mutated afterward. They stay PascalCase. The rare *mutable* global — counters, accumulators, caches written from multiple sites during normal execution — uses `ALL_CAPS_SNAKE_CASE`. The case difference is visible at every call site, so a reader knows whether a name can change under them without grepping for writers. A `(C)`-marked Calculation may read PascalCase globals freely; reading `ALL_CAPS_SNAKE_CASE` disqualifies. Where the contract can be locked at the shell level, use `declare -Agr`, `declare -agr`, `declare -gr`, or `readonly NAME` on the declaration.

### Cross-scope return variables

When a function writes to a caller-supplied variable name — via `local -n`, `printf -v "$outVar"`, `eval "$outVar=..."`, or any other mechanism — the caller's variable name should be UPPERCASE. The convention borrows the environment-variable namespace so cross-scope names can't collide with the caller's locals (always camelCase) or the function's own locals.

The collision risk is general, not specific to `local -n`. If the helper has a `local tmpDir` and does `printf -v "$1" '%s' "$tmpDir"`, and the caller passed `tmpDir` as the out-param name, the printf writes to the helper's local; the caller's variable is never set. Using `TMP_DIR` for the caller's variable eliminates the collision because no function should declare a local in that case style.

### List suffixes

`*List` (singular) holds a serialized list in one string, IFS-separated: `commandList`, `groupList`. Quote on expansion. Initialize as `local xList=''`, never `local xList=()` (the parens form is the array variant; see `*Lists` below).

`*Lists` (plural) holds a true bash array whose elements may contain IFS characters: `commandLists`, `groupLists`. Quote element accesses and the `"${arr[@]}"` expansion to preserve boundaries.

Plain plural holds a true bash array of plain scalars with no IFS hazard: `testnames`, `filenames`. No suffix needed; safe unquoted under IFS+noglob.

The `_` suffix is for things that aren't lists but still need quoting: single multi-line blobs, optional flag values that may be empty, trap output. `_` is mutually exclusive with both `*List` and `*Lists` on the same variable.

The decision criterion: is this conceptually a list of items? Scalar serialized blob → `*List`. True array of IFS-bearing elements → `*Lists`. Single thing that happens to contain newlines or be optional → `_`. Array of plain scalars → plain plural.

### Injectable dependencies

Use the command name directly, lowercase, with underscores replacing hyphens: `ssh_keygen=${ssh_keygen:-ssh-keygen}`. Despite being global declarations, they follow local naming because callers override them with `local` declarations in tests: `local ssh_keygen=mockSshKeygen`. The lowercase signals "this is designed to be shadowed." Libraries append the namespace suffix letter: `ssh_keygenQ`.

### Standard exceptions

`NL=$'\n'` for string interpolation in double quotes. `Prog=$(basename "$0")` for scripts that report their own name. These conventional exceptions skip the namespace-suffix rule even in libraries.

### Naming policy header

Libraries begin with a Naming Policy header comment that names the conventions in play; consumers need it to source the library correctly. A CLI script can use a much shorter header or skip the policy block entirely — the bash style guide is the source of truth for naming, and replicating it per-script is mini-style-guide-for-this-file noise.

Library header:

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

Standalone-script header (minimal — operator-facing orientation lives in the usage message):

```bash
# evtctl publishes events to era streams. See docs/evtctl.md.
```

### Enforcement

Many of these conventions are mechanically checked by the [shellcheck-convention-plugin](https://github.com/binaryphile/shellcheck-convention-plugin).

- **SC9001–SC9004** — IFS/noglob taint discipline and `_` / `*List` suffix rules (this section and Quoting below).
- **SC9005** — numeric comparisons in `[[ ]]` / `[ ]` (Conditionals).
- **SC9006** — inclusive language in identifiers and comments (cross-cutting).
- **SC9007** — docstring shape (Comments).
- **SC9008** — `*List` initialized as an IFS-serialized string, not an array.
- **SC9009** — uninitialized-then-appended variable (Variable Scoping).

Per-check rationale, severity, opt-in `cdName`, and source-rule citations live in the plugin's [`docs/design.md` §3 check catalog](https://github.com/binaryphile/shellcheck-convention-plugin/blob/main/docs/design.md). Suppress per site with `# shellcheck disable=SC9xxx`; opt in to optional checks with `enable=<cdName>` in `~/.shellcheckrc` or `--enable=<cdName>` per invocation.

## Quoting

Quoting carries intent. Under IFS+noglob, most scalar expansions are safe unquoted, so a quote signals "this value needs protection — either it contains IFS characters or the context demands exact word boundaries." Quoting every expansion adds noise without adding safety and obscures which values actually require care. When a reviewer sees quotes, they should trust that those quotes are there for a reason.

The `_` suffix is the ongoing contract. A variable name ending in `_` says "may contain IFS characters, may be empty; must quote on every expansion outside no-split contexts."

The suffix applies in either of two cases. **IFS content** — the variable may contain newlines (under `IFS=$'\n'`); unquoted expansion would split it into multiple words. **Emptiness** — the variable may be empty; unquoted expansion would disappear entirely as a positional arg, shifting downstream args. `set -u` catches unset, not empty.

Prefer non-empty initialization over the `_` suffix when emptiness can be eliminated by construction. A counter `local i=0` is better than `local i_` — `0` is non-empty, so unquoted expansion is safe. But `local s=''` is NOT better than `local s_` — empty-string initialization leaves the variable empty, so unquoted expansion still disappears. The `_` suffix is for cases where emptiness is *load-bearing*: an optional flag that's absent, a parsed field that may be missing, a trap that captures whatever output exists, a builder string that starts empty. Marking variables that could be initialized non-empty as `_` defeats the discipline's purpose — it creates a forest of `_` suffixes that obscures the truly-quote-required cases.

Integer types drop the `_` suffix entirely. `local -i n=$(cmd)` coerces every assignment to an integer; the variable can't hold IFS content. Use `-i` for counters, loop indices, exit codes, byte sizes, PIDs — anything whose semantic type is integer. `local -i parallel=0`, `local -i rc=0`, `local -i bucket`. Arithmetic context (`(( parallel == 0 ))`, `return $rc`) needs no quoting because the value's type rules out IFS-bearing content. The `_` rule applies to STRINGS that may be empty or may contain IFS characters; typed ints and fixed-shape string locals don't qualify.

In practice: `commands_` (trap output — emptiness is load-bearing), `content_` (user input, may contain newlines), `usage_` (multiline heredoc), `tags_` (optional flag, empty when not provided).

### Promote after validation

After validating a `_`-suffixed value, rebind to a non-`_` name. The same discipline applies to empty-possible values, not just IFS-bearing ones:

```bash
local foo_
foo_=$(maybeEmptyOp)
[[ -n $foo_ ]] || return 0

local foo=$foo_       # foo is now trusted scalar; use unquoted hereafter
local jsonl=$dir/$foo/data.jsonl
```

Carrying `_` past the validation point blurs the distinction between "still possibly empty" and "validated." The suffix system loses signal when every variable that was ever uncertain stays `_`-marked forever.

The same discipline applies to IFS-content validation: before promoting an untrusted value to a non-`_` name, check it explicitly (`[[ $value_ == *$'\n'* ]] && fatal "newline in path"`). The check is the sanitization; assigning to a non-`_` name is the claim that sanitization has been done. After that, do not defensively re-quote a non-`_` variable.

### Eval-safe quoting

`printf %q` escapes a value for shell re-evaluation:

```bash
printf -v output '%q ' "$@"    # output is safe to eval
```

`${var@Q}` renders a human-readable quoted literal, useful for debug output and test copy-paste lines:

```bash
CMD="sudo -u ${RunAsUser@Q} bash -c ${CMD@Q}"    # readable in logs
echo "want=${got@Q}"                              # tests — paste to update expected value
```

### read -r discipline

Always use `read -r` to avoid backslash interpretation. Use `IFS='' read -r` when consuming raw lines where leading and trailing whitespace are significant. Use `IFS=' ' read -r` when lines may be indented (heredoc or otherwise) and whitespace should be stripped before the value is used — see `map` in FP Pipeline Helpers.

### Braces in expansion

`$var`, not `${var}` — braces add noise when the variable name is unambiguous. For disambiguation when text follows the name, prefer quotes over braces: `"$var"Suffix` concatenates the quoted expansion with the literal. Use braces when the variable is embedded mid-string and quotes can't delimit it: `"prefix${var}suffix"`.

### Array and positional expansion

`"${array[@]}"` and `"$@"` preserve element boundaries — each element stays a separate word. `"$*"` joins elements with the first character of IFS (useful for serialization). Unquoted, both `${array[@]}` and `$@` undergo word splitting on IFS, so elements containing newlines get broken apart. Under `set -u`, an empty array needs `${args[@]:-}` as fallback.

### Quoting decision tree

For any expansion you're unsure about, walk this:

1. **No-split context?** Assignment RHS, `[[ ]]` (except RHS of `==` and `=~`), `(( ))`, `case`, array subscripts, `${...}` operators, redirections, here-strings — quoting is unnecessary. These contexts never split or glob regardless of IFS/noglob settings.
2. **`_`-suffixed variable?** Must quote in non-assignment contexts: `echo "$Usage_"`, `eval "$testSource_"`.
3. **Required-quoting context?** Array expansion (`"${arr[@]}"`), RHS of `==` in `[[` for literal match, `eval` arguments, `trap` strings, process substitution with multi-line content — must quote.
4. **Otherwise** — safe unquoted under IFS+noglob. The variable has no `_` suffix (newline-free by convention), and the context is a command invocation with scalar arguments.

### Single vs double quotes

Single quotes are the default for string literals; reach for double only when the value contains a single quote or you need parameter, command, or arithmetic expansion. Single quotes guarantee the string is taken verbatim — no `$var`, no `$(cmd)`, no `\`-escapes, no surprise expansion. Reserve double quotes for cases where one of those behaviors is intended.

```bash
fatal 'op-run: not in a git repo' 64           # no expansion, single quotes
fatal "op-run: realpath failed for $raw" 1     # $raw expanded, double quotes
echo 'literal $foo, no expansion'              # $foo stays literal
```

### Heredoc terminator

`END` by default. Use `END` consistently across the codebase so terminator search and grep are uniform. Quote it (`<<'END'`) by default; only use unquoted (`<<END`) when the body needs `$var` or `$(cmd)` expansion. Unquoted heredocs are a risk when the body is content the author didn't fully parse — pasted markdown can introduce backtick command-substitutions by accident, and `$` sequences expand silently. Quoted terminators take the body verbatim with no exceptions.

### Multi-line echos use heredocs

A sequence of `echo` statements emitting a multi-line message is a heredoc waiting to happen. Replace with `cat <<'END' ... END` (or `cat <<END ... END` when expanding variables). The heredoc form is fewer lines, avoids quote-juggling for embedded apostrophes or double quotes, lets the message be edited as a block, and preserves embedded blank lines naturally.

```bash
# Avoid:
echo 'BLOCKED: foo'
echo
echo 'See docs.'
echo "Match: $hits"

# Prefer:
cat <<END
BLOCKED: foo

See docs.
Match: $hits
END
```

### When to quote

Quotes are required in these contexts.

**Trust boundaries.** User input must be presumed to contain IFS characters until sanitized. Assign untrusted input to a `_`-suffixed variable and quote it on use. Validate, then promote (see Promote after validation above).

**`"${array[@]}"` / `"$@"` / `"$*"`** — preserve element boundaries. Unquote only when IFS splitting is intentional: `local arr=( $(command) )`.

**RHS of `==` in `[[`** — `[[ $x == "$y" ]]` for literal match. Unquoted RHS is a glob pattern: `*`, `?`, `[` become wildcards. Leave unquoted for intentional pattern matching: `[[ $OSTYPE == darwin* ]]`. Embedded literals between glob anchors (`[[ $output == *WARNING:* ]]`) don't need quoting unless the embedded literal contains whitespace, in which case quote for readability: `[[ $output == *"docs refreshed"* ]]`.

**RHS of `=~` in `[[`** — quoting disables regex metacharacter interpretation. Leave unquoted for regex matching. For complex patterns, store in a variable: `local pattern='^[0-9]+$'; [[ $x =~ $pattern ]]`.

**`_`-suffixed variables** in non-assignment contexts.

**`eval` arguments** — `eval "$CMD"`. Without quotes, newlines become argument separators.

**Command substitution as argument** — judgment call. `func "$(command)"` when the result should be a single word; unquoted `$(command)` splits on newlines when that's desired (`local arr=( $(listItems) )`).

**`trap` command strings** — `trap "$command$NL$(existing)" EXIT`. The string is stored for later eval; must be a single coherent argument.

**Process substitution with multi-line content** — `diff <(echo "$got") <(echo "$want")`. Unquoted `echo $var` splits on newlines, destroying line structure.

**Positional pairing arguments** — APIs that consume arguments in key-value pairs (`jq --arg name value`, custom key-value functions) break when an empty variable expands to nothing, shifting subsequent pairs. Quote empty-possible values: `--arg t "$type_"`.

### When quoting is unnecessary

These contexts never split or glob:

- **Assignment RHS** — `local var=$value`, `var=$(command)`, `var=${1:-default}`.
- **`[[ ]]` operands** (except RHS of `==` and `=~`) — `[[ -e $file ]]`, `[[ $var == pattern ]]` (LHS).
- **`(( ))` arithmetic** — `(( rc == 0 ))`, `(( ${#array[@]} ))`.
- **`case` word** — `case $var in`.
- **Array subscripts** — `${map[$key]}`, `array[$idx]=val`.
- **Inside `${...}` operators** — `${1:-$default}`, `${var#$prefix}`.
- **Redirection targets** — `>$file`, `<$file`, `<<<$var`. Bash takes the single word. Cuddle the operator with its target: `>$file`, not `> $file`; `>>"$path"`, not `>> "$path"`. The space-free form binds the redirection visually with its argument, parallels stdin/stderr forms (`2>&1`, no space), and avoids implying the target is a separate command argument. Same rule for `<`, `<<<`, `>>`, `<>`.
- **Scalar command arguments** — `func $simplevar`, `mkdir -p $dir`. Under IFS+noglob, splitting only occurs on newlines and globbing is disabled. This applies identically to functions, builtins, and external commands. This is the default for variables without the `_` suffix.

### Outside the IFS+noglob discipline

The rules above assume `IFS=$'\n'; set -o noglob` is in effect. That assumption fails in several common contexts where bash code runs under tooling that controls the shell environment:

- **Home Manager activation scripts** (`home.activation.<name>`) — activated by HM's bash without IFS or noglob.
- **Nix builders** (`mkScriptBin`'s wrapper, `pkgs.writeShellScript`, `pkgs.runCommand`'s `buildCommand`) — Nix's build sandbox bash runs with default settings.
- **systemd unit ExecStart with inline shell** (`bash -c '...'`) — systemd executes with default bash.
- **Embedded shell snippets in YAML, TOML, or Nix attribute values** consumed by tools you don't control.
- **Heredocs that get extracted and run separately** — the surrounding script's discipline doesn't transfer.

In these contexts, apply standard bash quoting: quote every expansion. Treat all variables as if `_`-suffixed regardless of their actual name. The `_` and `*List` conventions are an optimization enabled by IFS+noglob; without that floor, the safe default is universal quoting. `"$var"` everywhere it would be expanded; `"$@"` and `"${array[@]}"` for positional and array expansion; `"$(cmd)"` for command substitution; globs disabled defensively where filename expansion isn't wanted.

If the embedded snippet is more than a few lines, consider opening with the safety preamble (`IFS=$'\n'; set -o noglob; set -uo pipefail`) so the IFS+noglob discipline applies inside the snippet. For short snippets, universal quoting is simpler than entering the discipline.

A reviewer reading bash code under unknown discipline should default to expecting universal quoting. If a snippet uses unquoted expansions and isn't under a documented IFS+noglob preamble, treat it as a quoting bug regardless of variable naming.

## Variable scoping

Bash has dynamic scoping: a function can read and modify variables in its caller's scope, even `local` variables. This is the opposite of lexical scoping in C, Python, or Go, where a function can only see its own locals and globals.

### Array declaration

Use parens to declare arrays, and skip `declare` for indexed arrays unless `-g` is needed:

```bash
Arr=( a b c )    # indexed, populated — no declare needed
Arr=()           # indexed, empty — no declare needed; parens signal "array, currently empty"
```

The parens convey "this is an array" visually and let you skip `declare` for indexed arrays. For empty arrays especially, `Arr=()` is preferable to `declare -a Arr`; the parens are a strong visual reminder that the variable is an array AND that it's currently empty.

### declare -g for globals declared inside functions

`declare` without `-g` always creates a *local* variable when executed inside a function scope, including scalars, arrays, and associative arrays. A plain assignment (`Var=value`) creates or modifies a global, but `declare Var=value` in a function scope is local. The same trap applies to files sourced from within a function: the source call inherits the caller's scope, so every `declare` in the sourced file creates a local to the calling function.

```bash
declare -g  Scalar=value        # scalar global — use -g when declare is needed
declare -ag Arr=( a b c )       # indexed array global
declare -Ag Map=( [k]=v )       # associative array global — -A also required
Arr=( a b c )                   # plain assignment: global if no enclosing local
```

Indexed arrays often don't need `declare` at all — plain assignment with parens creates or modifies a global. Associative arrays *do* need `declare -A` (or `-Ag`) because bash requires the `-A` flag to allocate the hash structure; without it, brackets parse as indexed subscripts and silently misbehave.

This is load-bearing whenever a sourced file declares state intended to outlive the source call. If `projects.bash` declares `declare -A ProjectPath=(...)` and is sourced from inside `main()`, `ProjectPath` is local to `main` — visible to functions called by `main` via dynamic scoping, but gone after `main` returns. Make the global intent explicit with `-Ag`.

### Bare $ArrayVar for known-single-element arrays

Bash flags expanding an array without an index (SC2128) — "expanding an array without an index only gives the first element." For well-known single-element-in-practice arrays like `$BASH_SOURCE` (always at least one element; index 0 is the running script's path), the bare form reads as a scalar and matches reader intuition. Prefer the bare form for these cases and suppress shellcheck per site:

```bash
# shellcheck disable=SC2128 # BASH_SOURCE always has at least one element
Here=$(dirname "$BASH_SOURCE")
```

For arrays where multi-element semantics matter, use the explicit `${Arr[0]}` form.

### Initialize at declaration

Declare and initialize together. A `local x` with no `=` initializer creates a variable whose value is the empty string, but the intent is ambiguous — is `x` supposed to be a string, an array, a sentinel for "not yet computed", or an unfinished thought? Subsequent appends or assignments force the reader to scan ahead to learn the variable's shape.

The operative case is the **uninitialized-then-appended** antipattern (SC9009): within a single scope (function body, file top-level, compound block), if every path between the variable's declaration and its first read uses `+=` and never uses a plain `=` assignment, the variable's first materialization is an append mutation. The fix is to initialize at declaration:

| Antipattern | Preferred | Container shape |
|---|---|---|
| `local arr` then `arr+=( ... )` | `local arr=()` | array |
| `local content` then `content+="..."` | `local content_=""` | string (empty-init is empty-able) |
| `local xList` then `xList+="..."` | `local xList=""` | `*List` serialized string |
| `local arr; [[ cond ]] && arr+=( ... )` | `local arr=()` | array (conditional append) |
| `declare Arr` then `Arr+=( ... )` elsewhere | `Arr=()` at declaration | array (global) |

Canonical recommended forms:

```bash
local content_=''           # string, initially empty (_ per Quoting — empty-init is empty-able)
local args=( "$@" )         # array, populated from positional params
local items=()              # array, initially empty
local docList=''            # *List-suffix string (IFS-serialized list, initially empty)
local -A cache=()           # associative array, initially empty (needs -A)
local -i count=0            # integer scalar, default 0 (-i marker makes the type explicit)
local result_=$(someCmd)    # string from cmdsub — always assigns, empty on no output
```

Exceptions — declaration-coincident initializers — a bare declaration is acceptable when the variable is fully populated in an adjacent statement *and* the populating command is guaranteed to assign the variable:

```bash
local result_=$(some-command)             # cmdsub initializer (always assigns)
local arr=( a b c )                       # array literal initializer
local arr; mapfile -t arr < <(cmd)        # mapfile/readarray always assigns
local line_=""; read -r line_             # explicit empty-init guards against read rc=1
local line; read -r line < file           # UNSAFE under set -u — read on EOF may not assign
```

`mapfile` always assigns the target array, even on empty input. Bare `read` on EOF may not assign the target at all — a subsequent `$line` reference under `set -u` raises unbound-variable. Use the explicit empty-init form for `read`.

Other exceptions — intentional unset or sentinel (rare; document at the site): a genuine "not yet computed" sentinel where downstream code checks `[[ -v x ]]` or `[[ -n $x ]]` deliberately; an out-param nameref (`local -n REF=$1`) whose "value" is the binding rather than a value.

### Mechanism

When bash resolves a variable name, it walks up the call stack. A callee's `local x` shadows the caller's `x`, but without `local`, the callee accesses the caller's variable directly. This applies to both reads and writes.

A test runner can exploit dynamic scoping intentionally for callback counting. The callback modifies `passCount` and `failCount`, which are locals in the calling function:

```bash
passCount+=1   # in caller's scope
```

The comment `# in caller's scope` documents the intentional cross-scope access. Without this pattern, the runner would pass counters through return values or globals.

The collision risk is the inverse case. If a callee declares `local x` and the caller also has `local x`, the callee gets its own copy. But if the callee *doesn't* declare `local` and uses `x`, it silently modifies the caller's `x`. The risk is highest with namerefs: `local -n REF=$1` — if `$1` is `REF`, the nameref points to itself (circular reference).

Naming conventions are the primary protection: camelCase locals and PascalCase+suffix globals occupy separate namespaces, so two callees in the same chain are unlikely to collide if they follow conventions. UPPERCASE namerefs (`local -n ARRAY=$1`) borrow the environment-variable namespace, which never collides with camelCase locals in the caller. Subshell `()` function bodies provide hard isolation when dynamic scoping is unwanted; changes to variables, working directory, and shell options are discarded when the subshell exits:

```bash
createCloneRepo() (     # () not {} — subshell isolates side effects
  git init clone
  cd clone              # doesn't affect caller's pwd
  echo hello >hello.txt
  git add hello.txt && git commit -m init
) >/dev/null
```

Use `()` when a helper needs to `cd` or modify shell state; use `{}` (the default) when the caller needs to see the function's side effects.

### Returning multiple values via stdout

When a function needs to return multiple values, namerefs (`local -n PROJ=$2 SID=$3`) are one option but couple the function's signature to the caller's local-variable names and reintroduce the dynamic-scoping shadowing risk. An alternative for small tuples: emit a delimited string via stdout and parse at the call site:

```bash
# resolveSession echoes "<proj>:<sid>" or empty for cold start.
resolveSession() {
  local path=$1
  ...
  echo $sanitized:$latest
}

# Caller:
local resolution_
resolution_=$(resolveSession $pathReal)
[[ -n $resolution_ ]] || { coldStart; return; }
local proj=${resolution_%%:*} sid=${resolution_#*:}
```

This works when the components are guaranteed not to contain the delimiter (sanitized paths and UUID-like ids are safe with `:`). The trade-offs: no signature coupling, the function follows bash's natural "echo the result, return rc" idiom, no dynamic-scoping shadowing risk, but the delimiter is an implicit contract that must be documented, and there's an extra subshell from `$(...)`.

For wider tuples (4+ values), nameref out-params are usually clearer than parsing a longer delimited string. For 2-3 values where the delimiter is safe, stdout return is often the simpler choice.

## Conditionals

`[[` exclusively for string and file tests. `[[` is bash's compound command with pattern matching, no word splitting, and `&&`/`||` inside.

### (( )) for arithmetic and booleans

Boolean flags are 0/1 integers tested bare: `(( failed )) && return 1`, `(( hasSubtests )) && echo ...`. Numeric variables use explicit comparison: `(( rc == 0 ))`, `(( pid != 0 ))`. Arithmetic expansion: `$(( endTime - startTime ))`.

Avoid switch-style numeric comparisons in `[[ ]]` — numeric comparisons belong in `(( ))`:

```bash
(( $# > 0 ))         # any positional args present
(( $# == 0 ))        # no positional args
(( count == 0 ))     # no count
(( rc != 0 ))        # nonzero rc
(( a > b ))          # numeric comparison
```

over `[[ $# -gt 0 ]]` / `[[ $count -eq 0 ]]` / `[[ $rc -ne 0 ]]`. Arithmetic context is more idiomatic for numbers — operators (`>`, `>=`, `==`, `!=`) match math notation, no `$` needed inside `(( ))`, and there's no implicit string-vs-int conversion to reason about.

The switch-style operators that DO belong in `[[ ]]` are string-emptiness and file/path tests: `-z` / `-n` (string emptiness), `-f` / `-e` / `-d` / `-r` / `-w` / `-x` (file/path predicates). These have no `(( ))` equivalent.

### C-style for loops live in (( )) arithmetic context

When iterating with a numeric counter:

```bash
for (( i = 0; i < n; i++ )); do
  ...
done
```

over `for i in $(seq 0 $((n-1)))`. C-style is more idiomatic for numeric iteration, doesn't fork a subprocess, and keeps the bounds explicit at the loop head.

### (( i++ )) is a set -e trap

`(( expr ))` exits 1 when the arithmetic result is zero. Post-increment `(( i++ ))` returns the *old* value, so when `i=0` it exits 1 — silently aborting the script under `set -e`. The `i++` in a C-style `for (( ...; i++ ))` header is safe because the for-loop ignores the increment expression's exit code, but standalone `(( i++ ))` as a statement is not.

Preferred idiom for while-loop counters:

```bash
declare -i i=0   # (local -i inside functions) — arithmetic type, no (( )) needed
while (( i < ${#args[@]} )); do
  ...
  i+=1           # arithmetic add; never falsy-exits; reads cleanly
done
```

If you need `(( ))` and can't use `declare -i`, prefer pre-increment `(( ++i ))` (returns new value, truthy for any i≥0) over post-increment `(( i++ ))`.

### Case statements as tabular dispatch

A `case` with N branches that differ only in their pattern and action reads best as a two-column table: pattern on the left, action on the right. Pad shorter patterns so the `)` falls in the same column across all arms; the actions then column up too, and the case reads as data, not as a list of irregular branches.

```bash
case ${1:-} in
  -h|--help ) echo "$Usage"; exit;;
  --version ) exit;;
  --trace   ) shift; set -x;;
esac
```

`--trace` gets two extra spaces so its `)` lines up with the others. The eye reads three options and what each does in three lines.

## Error handling

### fatal()

```bash
fatal() {
  local msg=$1 rc=${2:-$?}
  echo "fatal: $msg"
  exit $rc
}
```

Libraries namespace this (`lib.Fatal`) and typically print to stderr.

### Return code 128 as fatal signal

A test framework can detect 128 and report "fatal" distinct from regular failure:

```bash
case $rc in
  0   ) printf $columns $Pass $duration $testname; passCount+=1;;
  128 ) printf $columns $Fatal $duration $Yellow$testname$Reset;;
  *   ) printf $columns $Fail $duration $Yellow$testname$Reset;;
esac
```

### RC capture

`cmd && rc=$? || rc=$?` preserves the exit code that `set -e` would otherwise lose. Safe under `set -e` because the `||` makes the overall compound always succeed; `set -e` only triggers on unchecked failures.

```bash
output=$(eval "$cmd" 2>&1) && rc=$? || rc=$?
```

### The trailing && bug

A function whose last command is `[[ test ]] && cmd` returns the test's exit code when the test is false. Under `set -e` at the call site, that propagates as a non-zero return and terminates the caller — even when the function did exactly what it was meant to do (skip the conditional action).

```bash
# Bug: when $stashRef is empty, the [[ -n ]] test fails (rc 1), the
# function returns 1, and a caller under set -e aborts.
gitUpdate() {
  local stashRef
  stashRef=$(git stash list | head -1)
  [[ -n $stashRef ]] && git stash drop $stashRef
}

# Fix 1 (preferred): invert the test so the no-op branch returns success.
[[ -z $stashRef ]] || git stash drop $stashRef

# Fix 2: explicit conditional.
if [[ -n $stashRef ]]; then git stash drop $stashRef; fi

# Fix 3: catch-all trailing return.
[[ -n $stashRef ]] && git stash drop $stashRef
return 0
```

Any compound where the failure branch is "do nothing" needs the function to still return zero. Inverting the test with `||` is usually the cleanest form — the conditional reads as "skip unless" rather than "do if."

### Expected non-zero exits under set -e

Many tools return non-zero for normal and expected outcomes — `grep` exits 1 on no-match, `diff` exits 1 on differences, `era query` exits 2 on silent-truncation. Under `set -e` these abort the script even when the caller's logic is fine with the outcome.

`! cmd` blocks `set -e` on either outcome (success OR failure of the inverted command). Bash's `set -e` documentation explicitly excludes `!`-inverted commands from the trigger list. The negator works as a general suppressor in any position, not just conditional heads:

```bash
# Standalone: ignore cmd's exit entirely
! grep -q "$pattern" "$file"

# In an `if` head: branch on cmd's failure case (the natural reading)
if ! grep -q "$pattern" "$file"; then
  echo "no match in $file"
fi
```

The `!`-exclusion applies only to the inverted compound itself, NOT to enclosing constructs. `var=$(! cmd)` — the `!` blocks `set -e` within the substitution, but the assignment statement's exit IS the substitution's inverted exit (rc=1 when cmd succeeded); `set -e` then fires on the assignment. For variable capture, use `||:`. Function-tail pipelines whose rc would propagate to a `set -e` caller need either `||:` at the function tail or an explicit `return 0`.

`cmd ||:` — `:` is the shell's no-op builtin that returns 0; the `||` makes the compound always succeed. `cmd`'s stdout is preserved. Use this when `!`'s scope-limitation rules out the `!` form: variable captures inside `$(...)`, function-tail pipelines, any case where the compound's overall exit must be 0:

```bash
hits=$(grep -cF "$pattern" "$file" ||:)   # always-0 if no match
```

Precedence gotcha: `||` binds LOOSER than `|`. `cmd1 ||: | cmd2` parses as `cmd1 || (: | cmd2)`. For "tolerate cmd1 AND pipe to cmd2," group with braces:

```bash
cmd1 ||: | cmd2          # WRONG: cmd1 succeeds → cmd1's stdout goes to outer fd
{ cmd1 ||:; } | cmd2     # grouped: cmd1 ALWAYS pipes to cmd2
```

Antipattern: `cmd || echo 0` for "default on failure". When `cmd` itself emits output BEFORE its non-zero exit, `|| echo 0` appends a SECOND value, yielding a multi-line result that breaks downstream parsing. `grep -c` is the classic case — it always prints the count to stdout (even "0" for no-match) AND exits 1 on no-match:

```bash
hits=$(grep -cF X file ||:)       # always-0 if no match (grep prints 0, ||: yields 0)
hits=$(grep -cF X file || echo 0) # "0\n0" on no-match (grep prints 0, fallback prints 0)
```

Don't reach for `set +e` or `loosely()` to silence individual commands. The strict-mode escape is for sourcing whole optional configs or running unbounded scripts. For one expected-fail command, `cmd ||:` or `! cmd` is precise and local.

### pipefail

Standard for new scripts: `set -euo pipefail`.

### loosely() — strict-mode escape

For sourcing optional configs that may not exist or may fail benignly:

```bash
loosely() {
  set +euo pipefail
  "$@"
  set -euo pipefail
}
loosely source /etc/profile.d/optional-tool.sh
```

## Dependency injection

DI variables are lowercase in standalone scripts, matching the local-naming convention so override sites read consistently with other locals. Libraries append the namespace suffix letter.

Two common shapes:

```bash
# Command DI: variable holds a command path or name; call site is `$tmux args`.
tmux=${tmux:-tmux}
date=${date:-date}

# Tests override locally:
test_main_endToEnd() {
  local tmux=$dir/mock-tmux
  local date=$dir/mock-date
  ...
}
```

```bash
# Function-pointer DI: variable holds a function name; call site is `$timeFunc args`.
# Library form — lowercase + suffix letter.
timeFuncQ=${timeFuncQ:-mylib.UnixMilli}

# Tests override locally:
test_someFeature() {
  local timeFuncQ=mockUnixMilli
  ...
}
```

The lowercase signals "designed to be shadowed." A bare-name call site (`tmux list-panes` instead of `$tmux list-panes`) defeats the DI — every reference to an injected dependency must use `$`-expansion.

Historical note: older libraries (tesht, task.bash, mk.bash) use `PascalCase + suffix` for DI variables (e.g., `UnixMilliFuncT`). New code follows the lowercase convention; existing libraries aren't blocked from updating but the migration isn't gated.

## File organization

A bash file is a story told top to bottom. The reader opens it wanting to know what it is, how to use it, and what it does — in that order. Boilerplate doesn't precede the story.

### File order

For CLI scripts, the order is: header → usage heredoc → `main` → workhorses → globals and defaults → option-parsing boilerplate → sourcing-test guard → strict mode → `main` invocation. The reader who stops after the top quarter still understands what the script does.

```bash
#!/usr/bin/env bash
# evtctl publishes events to era streams. See docs/evtctl.md.

Prog=$(basename "$0")

read -rd '' Usage <<END
Usage:
  $Prog [OPTIONS] COMMAND
  ...
END

main() { ... }

# other functions — call-graph descent if maintainable, alphabetical otherwise
# (alphabetical wins when call-graph order is too fiddly to keep updated)

# globals, defaults, option-parsing boilerplate

# sourcing-test guard
return 2>/dev/null

# strict mode + main invocation
set -euo pipefail
main "$@"
```

For libraries, no `main` and no usage heredoc; the header carries the setup story:

```bash
#!/usr/bin/env bash
# Naming Policy: (full block; consumers need it to source correctly)

# function definitions only

# globals — namespace-suffixed
```

### Library vs CLI-script headers

Libraries need substantive header blocks because consumers must learn setup conventions (sourcing, IFS-discipline, naming policy, the boilerplate to copy) that have no operator-facing analog — there's no `-h` to print, only a programmer-with-an-editor who needs the contract for using the file.

CLI scripts need much less. The operator-facing usage message printed at `-h` largely fills the role Go's package-doc-comment occupies — it tells the reader what this thing is and how to call it with more density and more relevance than a prose header could. The header can shrink to one orienting line; the usage heredoc carries the operator-facing story. Replicating a full Naming Policy block in every CLI script is mini-style-guide-for-this-file noise; the bash style guide is the source of truth.

### Sourcing-test guard

The `return 2>/dev/null` line near the bottom lets tests source the script and call individual functions without running `main`. It's part of the visual story, not a hidden afterthought — it sits at a defined seam between "what tests get when they source" and "what running the script does."

## Comments

### Function docs

Mandatory for every function. Go-inspired style: directly above the definition, no blank line between. Minimum one short sentence; more text if behavior is non-obvious.

The form borrows from godoc but doesn't inherit Go's tooling-specific rules by authority. The portable rules carry over because they aid human readers regardless of language.

The function name leads the comment as the grammatical subject — not "this function..." or "Returns the...". The verb is present-tense and direct: `returns`, `writes`, `publishes`, `resolves`. Avoid "will return", "is used to", or "can be called to" — they bury the action under modal scaffolding.

The summary sentence fits on one line. If the function needs more, keep the summary as the one-liner and add the explanation as following prose, separated from the summary by a blank `#` line — summary for scanning, prose for understanding. For boolean-returning functions, the canonical form is "reports whether": `# isReady reports whether the agent has finished loading.` This signals "0 or 1, not the value itself" at a glance.

Algorithm details don't belong in the docstring. Internal implementation belongs in comments inside the function body; the docstring states the contract — what the caller observes. Algorithm enumeration and incident anchors like `(#27937)` belong inline next to the branch they explain, where a reader scanning that branch actually needs them.

Reference arguments by name in backticks — `` `path` ``, not "the first argument" or "the path argument." The names are the contract; using them in prose keeps the prose synchronized with the signature. Document significant side effects: mutating globals, exporting env vars, calling `exec`, calling `fatal`/`exit`. Add a usage example only when the calling pattern is non-obvious — nameref out-params, multi-step compositions, callback-style arguments. Ordinary functions don't need examples.

#### (C) and (D) markers, per Grokking Simplicity (Eric Normand)

Default to assuming a function is an Action; flag the rare exceptions with `(C)` or `(D)` at the end of the first sentence.

A **Calculation** `(C)` is a pure function: same inputs always produce the same output, no side effects, no I/O. Safe to call repeatedly, parallelize, refactor freely. Several carve-outs preserve `(C)` status despite shell features that look like side effects.

Nameref out-params do not disqualify. Bash function returns are integer exit codes only, and `$()` capture runs in a subshell with its own pitfalls (swallowed `exit`, lost `set -e`). Writing the result into a caller-supplied nameref is the bash idiom for "return a value" — conceptually equivalent to returning, just expressed in the language we have.

Reads of immutable-by-convention globals do not disqualify. Bash's "constants" are written once at bootstrap and never mutated thereafter (sourced registries, DI globals, lookup tables, configuration arrays). From the function's perspective those are additional inputs whose values are stable for the program's lifetime. The discipline required: the global is initialized before any reading caller runs; no code path mutates it after initialization; reviewers police this because bash gives no enforcement.

Deterministic-transformation subprocesses do not disqualify. `sort`, `awk` as a data filter, `grep`, `jq` on a known string, `tr`, `cut`, `comm`, `printf`, `head`, `tail`, `sed` as a stream editor on explicit input — these are pure transformations whose output is fully determined by their input. Subprocesses that probe the world (`date`, `git`, `op`, `ssh`, `curl`, `mktemp`, anything reading filesystem state or generating randomness) ARE Actions. Open-ended interpreters (`python -c`, `perl -e`) should be treated as Actions by default; mark `(C)` only if the embedded code is verifiably a pure transformation.

Beyond determinism, watch exit semantics. A deterministic transform can still be operationally hazardous: `grep` exits 1 on zero matches, which under `set -euo pipefail` aborts the calling script. That's a separate axis from purity.

**Data** `(D)` is a function whose body is effectively a constant — a heredoc-emitter or lookup table with no inputs that change the output. Treat as configuration.

An **Action** depends on or affects the world: reads time, mutates state (globals other than its own out-param), reads mutable state, runs subprocesses, exec/exits, writes files, exports env vars. Anything where "what" depends on "when" or "how often" is an Action. No marker — this is the default; tagging every Action would be noise.

Marker placement and prose references: `(C)` and `(D)` belong only at the end of the summary line of a definition's docstring, where they classify *that* function. Don't repeat the marker inline when prose refers to another function — write "delegates to `buildAuditPayload`" rather than "delegates to `buildAuditPayload` (C)." The reader can look up the referenced function's classification at its definition site.

Examples:

```bash
# add returns the sum of `x` and `y`. (C)
add() {
  echo $(( $1 + $2 ))
}

# fatal prints `msg_` to stderr and exits with `rc` (default 1).
fatal() {
  local msg_=$1 rc=${2:-1}
  echo "$msg_" >&2
  exit $rc
}

# lib.Main runs the test functions in the files given as `args`.
#
# Outputs success or failure to stdout. Returns 0 if all tests pass, 1 if
# any test fails, 128 if any test reports fatal.
lib.Main() { ... }

# isReady reports whether `pid` has finished its bootstrap probe.
isReady() { ... }

# canonicalToplevel writes $PWD's canonical git toplevel into the nameref `OUT`.
#
# Fatals with exit 64 outside a git repo, exit 1 if realpath fails. Uses a
# nameref instead of stdout because a $() subshell would swallow fatal's
# exit, leaving the caller with an empty value.
canonicalToplevel() { ... }
```

### Inline annotations

Inline at the end of the line when the comment is a short annotation tied to one specific line's content, and the comment fits without disrupting alignment of related lines:

```bash
local tmpname=$(mktemp -u)   # -u doesn't create a file, just a name
(( $? == 128 )) && return 128 # fatal
local NL=$'\n' # newline — works with backgrounding (&) and legal semicolons; semicolon doesn't
```

When two related single-line settings sit together and both want inline comments, pad the shorter line so the `#` columns align. The eye then reads two settings plus their explanations as one unit:

```bash
IFS=$'\n' # disable word splitting on most whitespace
set -uf   # unset variables fail; turn off globbing
```

The inline-vs-above choice is deliberate. Inline preserves the visual cuddling of adjacent settings. Above introduces a new block — for godoc-shape function headers, multi-line explanations, or section intros.

### Section markers

`##` is the backward-compatible super-comment. `#` is for individual comments; `##` is for group headers and section markers. The choice of `##` (the heavier form) for the rarer case lets you sprinkle `#` freely without committing to any structure, then add `##` group headers later when structure emerges. Existing `#` comments still work; nothing needs to be upgraded.

The convention is the inverse of Markdown's (`#` = biggest header) because the density inverts: in code, individual comments are the common case and section headers are the rare case, so the lightweight form belongs to the common case.

```bash
# strict mode          ← low-level annotation

## library functions   ← major section

## logging             ← major section
```

`##` is preceded by a blank line. Rarely more than `##` in practice.

## Testing

Test framework conventions.

### Associative array cases

Define test data as associative arrays:

```bash
local -A case1=(
  [name]='not run when ok'
  [command]="cmd 'echo hello'"
  [ok]=true
  [wants]="(ok 'not run when ok')"
)
```

### Inherit unpacks

`Inherit` unpacks case fields into locals. Unset optional fields first so missing keys don't carry over from a previous case:

```bash
unset -v ok shortrun prog unchg want wanterr
eval "$(Inherit "$casename")"
```

### RunCases iterates

`RunCases ${!case@}` passes all case variables at once and iterates internally. Returns 1 if any case failed, 128 on fatal. For per-case error handling, use a loop:

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

### Assertion failure output

The preferred pattern uses `AssertGot` and `AssertRC`:

```bash
AssertGot "$got" "$want"
AssertRC $rc 0
```

`AssertGot` compares strings, shows a diff, and emits a copy-paste line for easy test updates. `AssertRC` compares return codes. Both return 1 on failure.

The manual equivalent (for reference; prefer the helpers above):

```bash
[[ $got == $want ]] || {
  echo "${NL}cmd: got doesn't match want:$NL$(Diff "$got" "$want")$NL"
  echo "use this line to update want to match this output:${NL}want=${got@Q}"
  return 1
}
```

### Subshell isolation for setup

A subshell `()` body isolates `cd` and shell-state changes in setup helpers:

```bash
createCloneRepo() (
  git init clone
  cd clone
  echo hello >hello.txt
  git add hello.txt
  git commit -m init
) >/dev/null
```

### MktempDir for temp-dir cleanup

```bash
MktempDir dir || return 128
```

Cleanup is registered automatically via `Defer`; see Trap Handling.

### AAA structure

`## arrange`, `## act`, `## assert` comment sections in each subtest, matching the canonical arrange/act/assert decomposition.

### Test what should be true, not what is

Don't pin known-broken behavior. A test that asserts "this bug currently does X" actively resists the fix — when someone correctly repairs the bug, the test fails and signals "broken behavior is desired." Two defensible alternatives: skip or xfail the test until the bug is fixed, or document an explicit compatibility contract with rationale. Otherwise, delete the test and let the bug remain documented in code comments or an issue tracker.

### Assert semantic contracts, not formatting artifacts

A test that asserts the literal output `'has\ space'` couples to bash's current `printf %q` strategy — if bash later renders the same value as `'has space'` (single-quoted) or `$'has space'` (ANSI-C), the test fails despite both forms being equally shell-safe. Prefer asserting the underlying contract: extract the emitted command, eval it in a subshell, observe the result:

```bash
# Brittle: locks bash's current %q output
[[ $got_ == *'has\ space && claude'* ]] || ...

# Robust: tests "the cd line lands at the expected path"
local cdLine
cdLine=$(echo $got_ | grep -E '^cd .* && claude --resume sess-x$' | head -1)
local cdPart=${cdLine%' && claude --resume '*}
local landedAt
landedAt=$(eval "$cdPart && pwd")
[[ $landedAt == "$expectedPath" ]] || ...
```

### Cover the executable-mode startup path

Tests that source the script (`__TESTING=1 source ./script`) hit the test guard before strict mode and `main "$@"` run. Bugs that surface only under strict mode — `set -u` violations during DI defaulting, `pipefail` interactions with `grep`-no-match (see Risks below) — are invisible to source-mode tests. Include at least one subprocess-invocation case:

```bash
test_main_executableInvocation() {
  local dir
  tesht.MktempDir dir || return 128
  # ... stage env ...
  local got_
  got_=$(projectsDir=$dir/projects tmux=$dir/mock-tmux $ScriptPath 2>&1)
  [[ $got_ == *expected* ]] || ...
}
```

## FP pipeline helpers

Stdin-based composition: command name as first arg, applied to each line via `eval`. Core trio: `Each` (side effects), `Map` (transform), `KeepIf` / `RemoveIf` (filter). The `eval "$command $arg"` pattern assumes trusted input; callers are responsible for escaping with `printf %q` if values originate from untrusted sources.

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
  while IFS=' ' read -r "$VARNAME"; do
    eval "echo \"$EXPRESSION\""
  done
}
```

`map` uses `IFS=' '` (not `IFS=''`) so that leading and trailing spaces are stripped from each line on read. This lets the heredoc body be indented for readability without embedding spaces in the substituted value. `each` and `keepIf` use `IFS=''` because their leading spaces land before the first argument in `eval "$command $arg"` — shell parsing treats them as harmless whitespace. In `map`, the variable value is substituted into an expression (e.g., `$HOME/projects/$path`), so spaces in the value become embedded mid-string rather than stripped as argument separators.

Call site:

```bash
each Ln <<'  END'
  .config         ~/config
  .local          ~/local
  .ssh            ~/ssh
  secrets/netrc   ~/.netrc
END
```

```bash
map path '$HOME/projects/$path' <<'  END'
  era
  jeeves
  tesht
END
```

Inline versions are common in standalone scripts; a shared library consolidates them with `return 0` guards to prevent error propagation from the last iteration.

## Trap handling

§14 governs lifecycle and shutdown handling. Application-specific signals (HUP for config-reload, QUIT for diagnostic dumps, USR1/USR2 for app-defined events, CHLD for process supervision) encode app semantics rather than generic lifecycle and are out of scope here.

EXIT traps for cleanup. **ERR, DEBUG, and RETURN are strict no-go** (rationale below).

INT/TERM handlers are justified for long-running supervisory loops, daemons, and retry-watchers. For short batch scripts, EXIT alone is sufficient.

### When INT/TERM handlers are justified

**Immediate clean termination.** Trap converts the signal-driven stop into a normal-completion exit. Use when the caller contract treats signal-driven shutdown as a successful expected outcome — daemons under systemd whose service policy treats SIGTERM as a clean stop, supervised long-polls invoked by parent scripts, batch jobs that should ignore SIGTERM during rotation. Do NOT use to mask Ctrl-C from an interactive operator who wants to know about the abort — when INT specifically means "user pressed Ctrl-C in a context where the operator wants to see exit 130," let it propagate.

```bash
# Bare form: caller treats both signals as clean-stop
trap 'exit 0' INT TERM

# With audit: logs the signal first so the journal records WHY the process stopped
trap 'echo "<name>: <signal> received; exiting cleanly" >&2; exit 0' TERM INT
```

Before adopting `trap 'exit 0' ...`, name the caller and write down why signal-driven exit is a success for that caller. If you can't, the trap is probably wrong — let the default 130/143 propagate.

**Cooperative shutdown at iteration boundaries.** Trap sets a flag; the protected work unit completes; the loop breaks at the next defined safe-point check.

```bash
Interrupted=false
trap 'Interrupted=true' INT TERM
while :; do
  work || :                            # work unit must satisfy obligation below
  [[ $Interrupted == true ]] && break
done
```

The flag check is `[[ $Interrupted == true ]]`, not `$Interrupted && break`. The latter would execute the variable's contents as a command — works by coincidence when the value is `true` (which IS a builtin), but breaks for any other truthiness convention.

What this pattern does NOT guarantee: the trap does not interrupt `work`. If `work` is blocked on a syscall or hung, the loop won't break until `work` returns. Operators using this pattern must either make `work` *idempotent* (re-running on retry is safe even if a prior call was interrupted mid-stream — read-only probes, GET requests, status checks) OR make it *interruption-tolerant* (handles mid-call abort without state corruption — transactional writes that commit-or-rollback, work units that hold no shared mutable state across the boundary). And they must check `$Interrupted` at every defined safe point — typically once per iteration, after `work` returns. Calling `work` many times before any check defeats the pattern.

### Why ERR / DEBUG / RETURN are no-go

**ERR** — propagation is unpredictable. The handler doesn't fire reliably inside pipelines (modified by `pipefail` / `set -E` / `errtrace` in non-obvious ways), inside `[[ ]]` / `[ ]`, or after `&&` / `||`. Operators usually want explicit `if/then` (or `||` with explicit handler) at each fallible call site — the locality outweighs the centralization benefit.

**DEBUG** — fires before every command, creating highly non-local control flow that's hard to reason about. Perf cost (linear in command count) is a secondary concern.

**RETURN** — fires on function return, creating hidden cleanup coupling between caller and callee. Use `local`-scoped cleanup or `local -A registry` patterns instead.

### EXIT-trap patterns

**Single assignment** — scripts and test functions that control their own trap:

```bash
dir=$(mktemp -d)
trap "rm -rf $dir" EXIT
```

Direct `trap "..." EXIT` overwrites any previous handler. Safe when the function or script owns its entire trap lifecycle.

**Stacked / deferred** — libraries that must not overwrite the caller's trap:

```bash
Defer() {
  local command=$1
  local NL=$'\n'
  trap "$command$NL$(existingDeferlist)" EXIT
}
```

New handlers prepend to the existing chain. `existingDeferlist` extracts the current handler via `trap -p EXIT` and strips the wrapper syntax. Commands execute in FIFO order. Use newlines (not semicolons) as separators — semicolons interact poorly with backgrounding (`&`).

### Temp directory cleanup

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

### EXIT trap with status capture

When a cleanup function must preserve the original exit code:

```bash
cleanup() {
  local _status
  _status=$?        # split from local: local resets $? to 0 in some bash versions
  trap - EXIT       # prevent recursive trap if cleanup calls exit
  # ... cleanup actions ...
  exit "$_status"   # re-raise original code
}
trap cleanup EXIT
```

The `local _status` and `_status=$?` must be on separate lines. `local _status=$?` captures the return code of the `local` builtin itself (always 0), not the exit trigger. `trap - EXIT` before `exit` prevents the EXIT trap from firing again when cleanup calls `exit`.

### Dynamic file descriptor allocation

Requires bash 4.1+. The `{varname}>` syntax lets bash pick an unused fd (always ≥10) and write it into `varname`:

```bash
exec {_LOCK_FD}>"$lock_file" || { echo "FAIL: cannot open lock file"; exit 1; }
flock -n "$_LOCK_FD" || { echo "FAIL: lock held by another process"; exit 1; }
```

Prefer `{varname}>` over a hard-coded fd like `9>`. Hard-coded low fds (0–9) may conflict with the parent shell's own redirections; bash uses 10+ for internal purposes, so `{varname}>` safely avoids both zones.

### Lock fd isolation in interactive shells

`exec {FD}>file` in an interactive shell leaks the fd to the shell session for its lifetime. Wrap lock acquisition in a subshell so the fd closes automatically when the subshell exits:

```bash
(
  set -euo pipefail
  exec {_LOCK_FD}>"$lock_file"
  flock -n "$_LOCK_FD" || { echo "FAIL: lock held"; exit 1; }
  # ... protected work ...
) || { echo "FAIL: initialization failed"; exit 1; }
# fd closed here — no leak to parent shell
```

This pattern is required when the code block will be pasted into an interactive shell or sourced multiple times.

### TOCTOU-safe temp directory for git worktrees

`mktemp -u` (dry-run) generates a name without creating the path, introducing a race between name generation and use. Use the parent-dir pattern instead:

```bash
PARENT=$(mktemp -d "${TMPDIR:-/tmp}/prefix-${ID}.XXXXXX") \
  || { echo "FAIL: mktemp failed"; exit 1; }
TARGET="$PARENT/worktree"
git worktree add "$TARGET" "$ref"
```

`mktemp -d` creates the parent directory atomically; the worktree or subdir is created inside it. Cleanup removes the parent:

```bash
[[ -n "${PARENT:-}" ]] && rm -rf -- "$PARENT"
```

Add a guard against removing unexpected paths:

```bash
case "$PARENT" in
  "${TMPDIR:-/tmp}"/prefix-*) rm -rf -- "$PARENT" ;;
  *) echo "WARN: refusing to remove unexpected path: $PARENT" ;;
esac
```

## Risks and limitations

IFS+noglob plus naming conventions eliminate most bash footguns, but not all. Each risk below describes the bash mechanism, how it bites, and the mitigation.

**1. Dynamic scoping collision.** A callee that omits `local` silently modifies the caller's variable. A nameref whose name matches its target creates a circular reference:

```bash
outer() { local x=before; inner; echo $x; }   # prints "after" — inner modified outer's x
inner() { x=after; }                           # no local — writes to caller's scope

wrapper() { local -n REF=$1; REF=value; }
wrapper REF   # circular reference — bash emits "circular name reference" error
```

Mitigation: follow naming conventions — camelCase locals, UPPERCASE namerefs. Document intentional cross-scope access with `# in caller's scope`. See Variable Scoping for the full explanation.

**2. Eval injection.** The FP helpers execute `eval "$command $arg"` where `$arg` is a line from stdin. If `arg` contains shell metacharacters, they execute as code:

```bash
echo '; rm -rf /tmp/important' | each processLine   # eval runs: processLine ; rm -rf /tmp/important
```

Mitigation: only pass trusted input through FP pipelines. For untrusted values, escape with `printf -v safe '%q' "$untrusted"` before piping. The trust boundary is the `eval` call — everything reaching it must be safe to execute as shell words.

**3. `[[` RHS pattern matching.** In `[[ $x == $y ]]`, the unquoted RHS is a glob pattern — `*`, `?`, and `[` are wildcards. This is independent of `set -o noglob`, which only affects pathname expansion in command arguments. `[[` has its own pattern-matching rules:

```bash
want='file[1]'
[[ 'file[1]' == $want ]]    # false — [1] is a character class matching the single character 1
[[ 'file[1]' == "$want" ]]  # true — literal comparison
```

Mitigation: quote the RHS for literal comparison: `[[ $x == "$y" ]]`. Leave unquoted only for intentional pattern matching: `[[ $OSTYPE == darwin* ]]`.

**4. Trailing newline stripping.** Command substitution `$(command)` always strips trailing newlines from the output. This is POSIX, not a bash quirk:

```bash
output=$(printf 'hello\n\n')   # output is "hello" — both trailing newlines stripped
content=$(cat "$file")          # file's trailing newline(s) silently lost
```

Mitigation: if trailing newlines matter, append a sentinel and strip it: `output=$(command; echo x); output=${output%x}`. In practice this rarely matters — most values are single-line identifiers or paths.

**5. `set -e` propagation.** In bash versions before 4.4, `set -e` does not propagate into command substitutions `$(...)`, so failures inside are silently swallowed. Bash 4.4 introduced `shopt -s inherit_errexit` to fix this, but it is off by default — you must enable it explicitly. Even with `inherit_errexit`, compound commands inside `$(...)` can behave unexpectedly. Process substitutions `<(...)` never inherit `set -e`:

```bash
set -e
result=$(false; echo "still runs")    # "still runs" executes — errexit not inherited without inherit_errexit
while read -r line; do
  process "$line"
done < <(failing_command)              # failure undetected — process substitution ignores set -e
```

Mitigation: don't rely on `set -e` inside command substitutions. Use explicit RC capture: `result=$(command) && rc=$? || rc=$?`. For critical operations, check `$?` after every command substitution. Alternatively, add `shopt -s inherit_errexit` to the preamble (bash 4.4+) to propagate `set -e` into command substitutions — but process substitutions remain unaffected.

**6. Pipeline subshell variable loss.** Each stage of a pipeline runs in a subshell. Variables modified inside a pipeline stage are lost when it exits:

```bash
count=0
command | while read -r line; do count+=1; done
echo $count   # still 0 — the while loop ran in a subshell
```

Mitigation: use process substitution instead: `while read -r line; do count+=1; done < <(command)`. This runs the loop in the current shell while the command runs in the subshell. Code following these conventions avoids piping into loops.

**7. `loosely()` hardcoded restore.** The `loosely()` wrapper does `set +euo pipefail` then `set -euo pipefail` after the command. It doesn't capture the previous shell options — it assumes the caller always uses `-euo pipefail`:

```bash
set -eu              # no pipefail yet
loosely source lib   # sets +euo pipefail, then -euo pipefail
# now pipefail is ON even though caller never set it
```

Mitigation: `loosely()` is safe only after `set -euo pipefail` is set. For library code that needs to temporarily relax options, save and restore with `set +o`:

```bash
local prevOpts
prevOpts=$(set +o)        # captures restore commands for all options
set +eu; set +o pipefail
command
eval "$prevOpts"           # restores exact previous state
```

`set +o` outputs `set -o`/`set +o` commands that reproduce the current option state. This handles all options including `pipefail` without fragile string matching.

**8. `pipefail` + assignment + non-fatal-non-zero exit.** Several common pipeline stages legitimately exit non-zero on conditions the caller doesn't consider failures: `grep` exits 1 on zero matches; `head -1` closes its pipe after one line and upstream stages (`sort`, `find -printf`) may receive SIGPIPE and exit non-zero; `awk '/pat/' | grep` chains and `comm` invocations have similar shapes.

Under `set -e` + `pipefail`, the pipeline's overall rc is the highest non-zero among stages. When that pipeline is captured by command substitution, the *enclosing assignment* propagates the rc, and `set -e` fires on the assignment:

```bash
set -euo pipefail
recorded_=$(grep -oE '"cwd":"[^"]+"' "$file" | tail -1 | sed '...')   # exits when grep finds nothing
```

The bug is invisible in test environments that source the script (skipping strict mode) — it only manifests when invoked as an executable. Always include at least one subprocess-invocation test case.

Mitigation: make the function robust to non-fatal stage failures. Two patterns:

```bash
# (A) explicit success at end of function — when the function's contract is
# "echo the result, return 0 regardless of empty/match/no-match"
recordedCwd() {
  local jsonl=$1
  [[ -f $jsonl ]] || return 0
  $grep -oE '...' $jsonl | tail -1 | sed '...'
  return 0
}

# (B) wrap the pipeline so its rc is swallowed at the capture site
latest_=$( { $find $dir ... | sort -rn | head -1 | cut -f2-; } || true )
```

Pattern A is preferable when the function is reusable. Pattern B fits one-off captures. Avoid `shopt -s inherit_errexit` here — it makes the problem worse by ensuring the rc propagates through `$()`.

## Adopting IFS+noglob in existing scripts

Adding `IFS=$'\n'; set -o noglob` to a script that previously relied on default IFS (space/tab/newline) requires auditing every code path. The following issues are non-obvious and will not produce syntax errors — they silently change behavior.

**1. Space-separated strings stop splitting.** Associative array values like `"node npm npx"` no longer split into three words on unquoted expansion. Under default IFS, `printf '%s\n' ${map[$key]}` produces three lines; under `IFS=$'\n'` it produces one.

Fix: use `IFS=' ' read -ra` to split explicitly:

```bash
commandsFor() {
  local c
  IFS=' ' read -ra c <<< ${map[$key]}
  printf '%s\n' "${c[@]}"
}
```

`IFS=' ' read -ra` sets IFS only for the duration of the `read` builtin — it does not modify the global IFS.

**2. `${array[*]}` joins with newlines.** `"${arr[*]}"` joins elements with the first character of IFS. Under `IFS=$'\n'`, this produces a newline-separated string instead of space-separated.

Fix: use a subshell command substitution extracted to a variable:

```bash
local desc=$(IFS=' '; echo ${arr[*]})
echo "packages: $desc"
```

The `$()` runs in a subshell, so the `IFS=' '` doesn't leak. Extract to a named variable to satisfy the shallow nesting rule — don't embed `$(IFS=' '; echo ...)` inside string interpolation.

**3. Glob patterns in `for` loops are dead.** `for f in *.txt; do` matches nothing because noglob disables pathname expansion. The `*` is treated as a literal character.

Fix: use a glob-restoring wrapper like `mk.WithGlob`:

```bash
for f in $(mk.WithGlob echo $dir/*.txt); do
```

`mk.WithGlob` temporarily enables globbing, runs the command, and restores the previous glob state. Do not manually toggle `set +o noglob`/`set -o noglob` — it's error-prone (easy to miss the restore on early return).

**4. `set -o noglob` requires its own line.** It cannot be chained into `set -euo pipefail`:

```bash
# WRONG — "noglob" becomes positional parameter $1
set -euo noglob pipefail

# RIGHT — separate lines
IFS=$'\n'
set -o noglob
set -euo pipefail
```

`set -euo` consumes `o` as a flag (equivalent to `set -o`), then treats the next word as the option name for `-o`. But `-euo` already consumed the `o`, so `noglob` becomes a positional parameter.

**5. Audit checklist.** When adding IFS+noglob to an existing script:

- Search for unquoted `${assoc_array[$key]}` where the value contains spaces — these relied on default-IFS word splitting.
- Search for `${array[*]}` in display/logging contexts — these now join with newlines.
- Search for `for x in` with glob patterns (`*`, `?`, `[`) — these are now literal.
- Search for `set -euo` to ensure noglob is set separately.
- Remove unnecessary quotes from scalar non-`_` expansions — they are now noise and undermine the quoting convention's signal value.
- Test all code paths, not just the happy path — glob and splitting bugs are silent.
