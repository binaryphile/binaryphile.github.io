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
what the actual requirements look like when you play them out as scenarios.

## The old world

Before 2017, password policy was a checklist everyone knew by heart:

- Change your password every 90 days
- Must contain uppercase, lowercase, digit, and special character
- Minimum 8 characters
- Can't reuse any of your last 12 passwords

Security teams enforced it. Auditors checked for it. Users hated it. And it
made passwords worse, not better.

## Why it made passwords worse

Every one of those rules has a specific failure mode. Here's what actually
happens when you enforce them.

### Forced rotation breeds predictable mutations

A company requires 90-day password changes. Sarah, an account manager, has
been through this twelve times. Her current password is `Summer2024!`. In
October, the system forces a change. She types `Fall2024!`. In January,
`Winter2025!`.

An attacker obtains `Summer2024!` from a breach. They don't try it directly —
they try the obvious seasonal mutations. `Fall2024!`, `Winter2024!`,
`Summer2025!`. They're in within a handful of guesses.

NIST's response: **SHALL NOT** require periodic password changes. Change only
on evidence of compromise.

### Composition rules produce a monoculture

A site requires uppercase, lowercase, digit, and special character. The
minimum is 8 characters. What does the average user type?

`Password1!`

Or `Welcome1!`. Or `Company1!`. Composition rules don't increase entropy — the randomness that makes
a password hard to guess — they constrain the search space into a predictable shape. Attackers know the
shape. They try `[Word][Digit][Special]` patterns first.

NIST's response: **SHALL NOT** impose composition rules.

### Short minimums invite brute force

An 8-character password using the full ASCII printable set has about 52 bits
of entropy. That sounds like a lot until you consider that a modern GPU
cluster can test billions of password guesses per second against a
stolen password database. 8 characters falls in hours.

NIST's response: **SHALL** require minimum 15 characters for single-factor
authentication. 8 characters only if a second factor is also required.

### Blocking paste punishes the right behavior

A site disables paste in the password field "for security." The subscriber
who was about to paste a 40-character random string from their password
manager now has to type something they can remember. The security outcome
gets worse, not better.

NIST's response: **SHALL** allow password managers and autofill. **SHOULD**
permit paste.

### No blocklist means the attacker's job is easy

A subscriber picks `123456` or `password` or `qwerty`. The system accepts it
because it meets the 8-character minimum (well, `password` does) and the
composition rules (it doesn't, but many systems don't actually enforce them
consistently).

Meanwhile, an attacker with a collection of 500 million passwords leaked from
previous breaches tries
the top 10,000. Most systems have at least a few accounts using them.

NIST's response: **SHALL** compare prospective passwords against a blocklist
of breached passwords, dictionary words, sequential characters, and
context-specific terms.

## Rev 3 vs Rev 4: from recommendation to mandate

Rev 3 (June 2017) said "SHOULD NOT" — recommended unless you have a
documented reason. Rev 4 (August 2025) says "SHALL NOT" — prohibited, no
exceptions.

| Requirement | Rev 3 (2017) | Rev 4 (2025) |
|---|---|---|
| Periodic rotation | SHOULD NOT | **SHALL NOT** |
| Composition rules | SHOULD NOT | **SHALL NOT** |
| Minimum length (single-factor) | 8 characters | **15 characters** |
| Password managers | SHOULD permit paste | **SHALL allow** managers + autofill |
| Blocklist checking | SHALL | SHALL |
| Strength guidance | SHOULD offer | **SHALL offer** |

The progression: "stop doing harmful things" became "you must stop doing
harmful things."

## What the requirements look like as scenarios

I turned the Rev 4 guidance into use cases to see what a team actually needs
to build. Not a checklist of SHALLs — a set of scenarios showing what
happens when things go right and wrong, driven by how real subscribers and
real attackers behave.

NIST defines three Authentication Assurance Levels. AAL1 is password-only.
AAL2 requires two factors — a password plus something like a time-based one-time-password (TOTP)
app or a hardware security key. AAL3 requires two factors where one is a hardware cryptographic
device that resists phishing.

### Setting a password

**The happy path:** A subscriber opens the password field and pastes a
64-character random string from their password manager. The system accepts it,
hashes it, stores the hash. Done.

**The attacker's path:** A different subscriber types `Company2025!` — a
predictable pattern that satisfies every legacy composition rule. The system
checks it against a blocklist of breached passwords. Found. Rejected. The
system explains why and suggests trying a passphrase. The subscriber tries
`correct horse battery staple` (16 characters, no special characters, no
uppercase). The system accepts it — length and unpredictability matter more
than character variety.

**The edge case:** A subscriber tries to set a 6-character password. Rejected
— below the 15-character minimum for single-factor, or 8-character minimum
with MFA. They try `aaaaaaaaaaaaaaa` — 15 characters but sequential.
Rejected. They try their username with digits appended. Rejected —
context-specific.

**The infrastructure failure:** The blocklist service is down. The system
cannot verify the password against breached corpuses. Rather than accept a
potentially compromised password (fail-open), the system refuses the change
and asks the subscriber to try again later.

### Authentication

**The happy path:** Subscriber submits username and password. The system
runs the submitted password through the same one-way hashing process
used when the password was stored, and compares the results. Match.
Session created.

**The attacker's path — credential stuffing:** An attacker has a list of
username/password pairs from a breach at another service. They try each one.
After 100 consecutive failures on a single account, the system requires
additional verification — a CAPTCHA, a temporary lockout with recovery, or
escalating delays. The account is never permanently locked, because permanent
lockout is a denial-of-service weapon the attacker can use against legitimate
users.

**The attacker's path — user enumeration:** The attacker tries a username
that doesn't exist. The system performs a dummy hash computation so the
response time is identical to a real account. The error message is generic —
"invalid username or password." The attacker learns nothing about whether the
account exists.

**The MFA path:** Account is AAL2. Password validates. The system prompts for
a second factor. The subscriber provides a TOTP code from their authenticator
app. Valid. Session created. If the subscriber's device is lost, they use a
recovery code or alternative factor — the system doesn't fall back to
password-only.

### Sessions

**The happy path:** After authentication, the system generates a session
token — a random identifier that proves "this browser is logged in" —
with enough randomness to be unguessable. It's delivered over an encrypted connection, never
embedded in URLs. The subscriber works. When done, they log out. The system
invalidates the session server-side — not just deleting the cookie.

**The absent subscriber:** The subscriber walks away. After 30 minutes of
inactivity, the session expires. After 12 hours regardless of activity, the
session expires. Both timeouts are adjustable by assurance level — higher-risk
systems use shorter windows.

**The attacker's path — session hijacking:** An attacker obtains a session
token (perhaps through a compromised network or XSS vulnerability).
They replay it from a different IP and user-agent. The system flags
the anomaly and may invalidate the session or require reauthentication.

### Compromise response

**The detection path:** A breach monitoring service flags a subscriber's
password as appearing in a newly published breach corpus. The system marks the
account for mandatory password change.

**The subscriber's path:** Next login, the subscriber authenticates (the
compromised password works this one last time), then is forced to choose a
new password before getting a session. They cannot reuse the compromised
password. The system does not just suggest a change — it requires one.

**The absent subscriber:** The subscriber doesn't log in for weeks. The
account stays flagged. Whenever they return, the forced change applies. The
system doesn't age out the flag.

**The worst case:** The attacker already used the compromised password to
change it. The subscriber can't log in. Account recovery kicks in — and
recovery must not bypass the account's assurance level. An AAL2 account
requires two-factor recovery, not just an email link.

### Why rotation doesn't appear here

Notice what's absent from every scenario: periodic expiration. No 90-day
timer. No "your password is about to expire" banner. The only forced change
is on evidence of compromise — a specific, concrete signal that the current
password is no longer secret.

Rotation is absent because it makes every other scenario worse. It makes
subscribers choose weaker passwords. It makes their passwords more
predictable. It trains them to make minimal changes. And it provides zero
protection against the actual threat — an attacker who already has the
password.

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

The standard is [free and online][rev4]. The [password verifier
section][passwordver] is the part that matters most. Read it. Then go check
what your systems actually enforce.

## References

- [NIST SP 800-63B Rev 4][rev4] (August 2025) — the current standard
- [NIST SP 800-63B Rev 3][rev3] (June 2017) — the paradigm shift
- [Password Verifiers section][passwordver] — the specific requirements

[rev3]: https://pages.nist.gov/800-63-3/sp800-63b.html
[rev4]: https://pages.nist.gov/800-63-4/sp800-63b.html
[passwordver]: https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver
