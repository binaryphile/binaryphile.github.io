---
layout: post
title: "Adding a Plugin System to ShellCheck"
date: 2026-05-19 09:00:00 -05:00
categories: [ bash, shellcheck, haskell ]
---

I wanted shellcheck to catch a class of mistakes it wasn't designed to catch — conventions specific to my bash style. Naming rules. Quoting under `IFS=$'\n'; set -o noglob`. Docstring shape. Things upstream would (rightly) never accept as core checks, because they're house rules, not bash mistakes.

ShellCheck has no plugin system. The options are: fork it, vendor a patch, or stop wanting the thing.

So I forked it. The fork is [binaryphile/shellcheck](https://github.com/binaryphile/shellcheck) and it now loads `.so` files at startup. This post is about how the plugin loader works and the one parser change I had to make to keep my docstring checks honest.

## The plugin shape

A plugin is a shared library exporting two C entry points:

```haskell
foreign export ccall plugin_api_version :: IO CInt
foreign export ccall plugin_init        :: IO (StablePtr [CustomCheck])
```

`plugin_api_version` returns an integer. The host (the shellcheck binary) refuses to load a plugin whose version doesn't match. `plugin_init` returns a list of `CustomCheck` values — each is a function `Parameters -> Token -> Writer [TokenComment] ()`, the same type as a built-in check.

At startup, shellcheck scans `$XDG_DATA_HOME/shellcheck/plugins/` for `*.so` files, `dlopen`s each one, calls `plugin_api_version`, then `plugin_init`, then registers the returned checks alongside the built-ins. They run as part of the same analysis pass. The error reporter has no idea they came from a plugin.

```
$ shellcheck script.bash
Loaded plugin: libconvention-checks.so (9 check(s))
script.bash:3:1: warning: SC9001: ...
```

The plugin can use any of the AST helpers shellcheck exports — `getLiteralString`, the sugared pattern aliases like `T_Literal id str`, the whole shape-matching kit. From the plugin's perspective, it's writing the same code as a built-in check. It just lives in a separate package.

## The catch: same compiler, careful linking

The plugin and the host are both Haskell. Haskell linking is not stable across GHC versions, so the plugin and host must be built with the same compiler. The plugin must not link the runtime (the host already has one), and the host must build with `-rdynamic` so the plugin can see its symbols.

```
# host: shellcheck
ghc-options: -threaded -rdynamic

# plugin: convention-checks
ghc-options: -shared -fPIC -dynamic
ld-options:  -Wl,--unresolved-symbols=ignore-all
```

The `ignore-all` says the plugin's references to host symbols don't have to resolve at link time — they'll resolve at `dlopen` time, when the host is loaded in the same process.

For nix users this is straightforward — both packages pin the same GHC and the lockfile keeps them in sync. For everyone else: build the host and the plugin from the same machine on the same day.

## The wrinkle: shellcheck's parser drops comments

I was building a docstring-shape check — flag a function whose first body statement isn't a `# description` comment. Standard convention check. Trivial to write.

Except shellcheck's parser drops comments. The lexer matches them, the parser discards them, and the AST has no `T_Comment` node. Comments simply do not exist downstream of parsing.

This is fine for shellcheck's purposes — comments don't affect shell behavior, so a static analyzer that produces warnings about behavior can ignore them. It's not fine for a plugin author writing a docstring check.

The fix is a splice: keep comments around, attach them to their nearest following AST node, and expose them through an accessor for plugin authors.

## The splice

Three pieces:

1. A new AST node, `T_Comment id text`, with all the standard `Token` machinery (positions, IDs).
2. A post-parse pass — `attachComments` — that walks the comment list and the AST in parallel and slips `T_Comment` nodes into the body lists they belong to.
3. An accessor — `getDocCommentsBefore :: Token -> [Token]` — that returns the comments immediately preceding a given token, with no blank line separating them from the token.

The splice is post-parse rather than mid-parse because the parser is Parsec-based and rewiring the existing rules to thread comments around would touch hundreds of productions. A post-pass that walks the AST once is cheap and isolated.

## Two bugs in the splice

The first version of the splice passed all unit tests but produced reordered output for any function with more than one statement.

```haskell
-- buggy: collisions combine new-on-left
Map.fromListWith (++) [(parent, [a]), (parent, [b])]
-- result: parent → [b, a]
```

`fromListWith f` applies `f new old` on key collision, so `(++)` runs as `[b] ++ [a] = [b, a]`. Two siblings inserted in order ended up reversed in the output.

```haskell
-- fix: flip the combine so old-on-left
Map.fromListWith (flip (++))
```

Order preserved.

The second bug was sneakier. The splice descended through the AST looking for nodes whose source range contained a comment, and stopped when it found a containing node. But some node types report a point range (start == end) for nodes whose children span a larger region — `T_Redirecting` is one. The check `posInRange pos node` returned false at the point-range node, so descent stopped, and the comment never reached its real target.

The fix was to remove the range filter entirely. Descend unconditionally, attach the comment at the deepest matching child, and let the absence of a matching child be the stop condition.

Both bugs survived the unit tests I wrote first. They surfaced when I ran the splice against real fixtures — a function body with three statements and a comment before the second one. The first time I saw the comment land before the wrong sibling, I knew the data structure was wrong. The second time I saw a comment disappear entirely, I knew the descent was wrong.

It took me longer to root-cause than to fix. That's the usual ratio for problems in code you wrote yesterday.

## Where this leaves the fork

ShellCheck-the-fork now has:

- A `pluginApiVersion` constant the host and plugin agree on (currently 2; bumped from 1 when `getDocCommentsBefore` was added).
- Dynamic loading from `$XDG_DATA_HOME/shellcheck/plugins/`.
- Docs at `docs/use-cases.md`, `docs/design.md`, and `docs/plugins.md` covering the three personas: plugin author, plugin user, fork maintainer.
- A worked example plugin in a separate repo — [binaryphile/shellcheck-convention-plugin](https://github.com/binaryphile/shellcheck-convention-plugin). That plugin is the subject of [the next post](/bash/shellcheck/haskell/2026/05/19/codifying-a-bash-style-guide-as-shellcheck-plugins.html).

I haven't pitched any of this upstream. ShellCheck's value to most users is its curated check set, and a plugin ecosystem fragments that — I'd be asking the maintainers to take on a maintenance surface that benefits a minority of users. The fork is fine. It exists so I can write checks for *my* conventions without convincing anyone else they're worth maintaining.

If your conventions look like mine, both repos are on GitHub. If they don't — write your own plugin. The ABI is two functions.
