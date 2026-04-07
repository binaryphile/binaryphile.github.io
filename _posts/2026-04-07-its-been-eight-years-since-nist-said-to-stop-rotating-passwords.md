---
layout: post
title: "It's Been Eight Years Since NIST Said to Stop Rotating Passwords"
category: security
---

In June 2017, NIST published [SP 800-63B Rev 3][rev3] and told the world to
stop requiring periodic password changes. Eight years later, most
organizations still do it. In August 2025, NIST published [Rev 4][rev4] and
upgraded that guidance from "you should stop" to "you must stop."

This is the story of what changed, what it means for systems you build, and
what the actual requirements look like when you turn them into use cases.

## The old world

Before 2017, password policy was a checklist everyone knew by heart:

- Change your password every 90 days
- Must contain uppercase, lowercase, digit, and special character
- Minimum 8 characters
- Can't reuse any of your last 12 passwords

Security teams enforced it. Auditors checked for it. Users hated it. And it
made passwords worse, not better.

Forced rotation produces predictable patterns. `Summer2024!` becomes
`Fall2024!` becomes `Winter2025!`. Composition rules produce `Password1!` and
its infinite variants. Users optimize for the minimum bar that satisfies the
machine, not for actual entropy.

## Rev 3: stop doing harmful things

NIST's Rev 3 was the first major reversal:

- **SHOULD NOT** require periodic password changes
- **SHOULD NOT** impose composition rules
- **SHALL** check passwords against breach corpuses and blocklists
- **SHOULD** permit paste (endorsing password managers)
- Minimum 8 characters

The word "SHOULD" in NIST means "recommended unless you have a documented
reason not to." It's strong guidance but not mandatory. Organizations could
read Rev 3 and keep rotating passwords if they wanted to justify it.

Many did. Eight years later, many still do.

## Rev 4: you must stop

[Rev 4][rev4], published August 2025, removes the wiggle room:

- **SHALL NOT** require periodic password changes *(upgraded from SHOULD NOT)*
- **SHALL NOT** impose composition rules *(upgraded from SHOULD NOT)*
- **SHALL** require minimum **15 characters** for single-factor passwords *(was 8)*
- **SHALL** allow password managers and autofill *(new)*
- **SHALL** offer password strength guidance *(upgraded from SHOULD)*
- **SHALL NOT** permit hints or knowledge-based security questions
- **SHALL** verify the entire password — no truncation

"SHALL NOT" means prohibited. There is no documented-exception path. If you
follow NIST, you stop rotating passwords. Period.

The 15-character minimum for single-factor authentication is the other big
change. If your users log in with just a password (no MFA), that password
must now be at least 15 characters. Passwords used alongside a second factor
can still be 8 characters minimum.

## What this looks like as requirements

I turned the Rev 4 guidance into [Cockburn-style use cases][usecases] to see
what an implementation team actually needs to build. Ten use cases cover the
full credential lifecycle. Here's what falls out.

### Setting a password

The subscriber enters a password. The verifier checks length and validates it
against a blocklist of breached passwords, dictionary words, sequential
characters, and context-specific words (the service name, the username). If it
passes, it gets salted and hashed with an approved scheme.

What the verifier **must not** do: require uppercase, lowercase, digits,
special characters, or any other composition rule. Must not truncate the
password. Must not require periodic rotation.

What the verifier **must** do: allow password managers and autofill. Accept at
least 64 characters. Reject passwords that appear in breach corpuses.

### The password manager question

NIST calls passwords "memorized secrets," but that's increasingly a fiction.
When a subscriber uses a password manager, they generate a random,
non-memorizable string and delegate storage to the manager. The secret is
persisted, not memorized. The subscriber's goal shifts from "choose something
I can remember" to "generate something strong."

The failure modes differ too. A forgotten password is recovered through the
account recovery flow. A lost password manager is a different kind of
emergency — every credential is gone at once.

NIST classifies both as "memorized secrets." The verifier doesn't care which
path the subscriber took. But any system designer should.

### Authentication

The subscriber submits their password. The verifier hashes it and validates
against the stored hash. If it doesn't match, the verifier returns a generic
error — it must not reveal whether the username exists or which factor failed.
Rate limiting kicks in after repeated failures, up to a maximum of 100
consecutive attempts before requiring additional verification. The account
must never be permanently locked.

For AAL2 and above, a second factor is required. Rev 4 cares about
authenticator properties, not brand names — it requires hardware
cryptographic authenticators with verifier impersonation resistance at AAL3,
but doesn't mandate any specific product.

### Sessions

After authentication, the verifier generates a session token with at least 64
bits of entropy, delivered only over TLS, never embedded in URLs. Inactivity
and absolute timeouts are AAL-dependent. Logout invalidates the session
server-side — deleting the cookie client-side is not enough.

### Compromise response

When a password appears in a breach corpus or the subscriber reports
compromise, the verifier forces a change at next login. This is the **only**
time a password change should be forced. The compromised password cannot be
reused.

The progression from Rev 3 to Rev 4 on this point is clear: NIST moved from
"stop doing harmful things" to "you must stop doing harmful things."

## What's still missing from most organizations

Eight years after Rev 3, here's what I still see:

- 90-day rotation policies
- Composition rules (uppercase + digit + special)
- Paste disabled in password fields
- 8-character minimums with no blocklist checking
- "Security questions" as account recovery

Every one of these is now explicitly prohibited or deprecated by the current
NIST standard. Not "not recommended." Prohibited.

If your organization follows NIST — and if you're a federal agency or
contractor, you must — Rev 4 leaves no room for interpretation. If you don't
follow NIST but use it as a reference, Rev 4 is still the strongest signal
available that these practices are counterproductive.

## The use cases

The full set of [Cockburn-style use cases derived from Rev 4][usecases] covers:

1. **Set an Appropriate Secret** — length, blocklist, storage
2. **Validate Against Blocklist** — breach corpuses, dictionary, sequential, context
3. **Store a Password** — salted hash with approved scheme
4. **Authenticate with Password** — hash validation, generic errors, MFA handoff
5. **Rate-Limit Attempts** — max 100 failures, no permanent lockout
6. **Authenticate with Second Factor** — property-based AAL requirements
7. **Use an Authenticated Session** — tokens, timeouts, server-side invalidation
8. **Restore Account Security After Compromise** — forced change, no rotation
9. **Recover Account** — must not bypass assurance level
10. **Manage API/Machine Credentials** — companion material, not 800-63B scope

Each use case includes compliance constraints traced to specific Rev 4
sections, so a team can map requirements to implementation and audit against
the standard.

The document is [available here][usecases] and licensed for reuse.

## References

- [NIST SP 800-63B Rev 4][rev4] (August 2025) — the current standard
- [NIST SP 800-63B Rev 3][rev3] (June 2017) — the paradigm shift
- [Password Verifiers section][passwordver] — the specific requirements

[rev3]: https://pages.nist.gov/800-63-3/sp800-63b.html
[rev4]: https://pages.nist.gov/800-63-4/sp800-63b.html
[passwordver]: https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver
[usecases]: https://github.com/binaryphile/binaryphile.github.io/blob/main/_sources/nist-secret-use-cases.md
