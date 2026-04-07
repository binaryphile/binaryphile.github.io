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

But the damage starts earlier than the breach. Sarah chose `Summer2024!` in
the first place *because* she knew it would expire. Why invest in memorizing
something strong when it's gone in 90 days? Rotation doesn't just fail to
stop attackers — it pressures users into choosing weaker passwords from the
start.

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

---

## Appendix: formal use cases

The scenarios above, formalized as Cockburn-style use cases. These are
designed to be cut and pasted as a standalone requirements document. Each
NIST requirement appears as the scenario that motivated it — an attacker
exploiting a weakness, a subscriber hitting a wall, or a system failing
to protect its users.

Derived from [NIST SP 800-63B Rev 4](https://pages.nist.gov/800-63-4/sp800-63b.html) (August 2025).

### System Scope

**System:** Verifier — the authentication subsystem that validates subscriber credentials, manages sessions, and enforces credential policy.

### Actors

**Subscriber:** End user who authenticates. May memorize passwords or use a password manager.

**Verifier:** The system under design. Validates credentials, manages sessions.

**Attacker:** Adversary with breach corpuses, password lists, and knowledge of common user behavior. Methods: credential stuffing, brute force, mutation guessing, phishing, session hijacking, social engineering of recovery flows.

---

### UC-1: Set an Appropriate Secret

- **Primary Actor:** Subscriber
- **Goal:** Set a password the subscriber can use to authenticate
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Subscriber creates an account or changes their password
- **Preconditions:** Identity proofed (enrollment) or authenticated session (change)
- **Stakeholders:**
  - Subscriber — wants a password they can use to get in
  - Verifier — wants a password that resists guessing even if the hash database is stolen
  - Attacker — wants subscribers to choose predictable passwords or reuse breached ones
- **Main Success Scenario:**
  1. Subscriber enters a password
  2. Verifier validates the password length (15+ for single-factor, 8+ with MFA)
  3. Verifier validates the password against the blocklist (UC-2)
  4. Verifier hashes and stores the password (UC-3)
  5. Verifier confirms the password is set
- **Extensions:**
  - 1a. *Subscriber pastes from a password manager:*
    Verifier accepts paste and autofill. The password is random and non-memorizable — the manager stores it. Continue step 2.
  - 2a. *Password is too short:*
    Verifier rejects and provides guidance. Resume step 1.
  - 2b. *Verifier imposes composition rules (uppercase, digit, special):*
    This forces predictable patterns — `Password1!`, `Company2025!`. Attacker exploits the pattern with mutation lists. Composition rules are prohibited. Verifier accepts any character mix.
  - 3a. *Password found in a breach corpus:*
    Attacker already has this password. Verifier rejects and explains why. Resume step 1.
  - 3b. *Password is a dictionary word, sequential, or contains the username:*
    Attacker tries these first. Verifier rejects. Resume step 1.
  - 3c. *Blocklist service unavailable:*
    Accepting the password would leave the account vulnerable to credential stuffing. Verifier refuses the change and asks subscriber to retry later. Fail.
  - 4a. *Storage fails:*
    No password stored. Resume step 1.
  - *a. *System requires periodic rotation (90-day policy):*
    Subscriber mutates `Summer2024!` to `Fall2024!`. Attacker who has the old password guesses the new one in a handful of tries. Forced rotation is prohibited — change only on evidence of compromise.
- **Technology & Data Variations:**
  - Password manager: subscriber generates a random, non-memorizable password. The secret is persisted, not memorized. Failure mode is lost manager, not forgotten password.
  - Unicode normalization: NFKC or NFKD before hashing
- **Minimal Guarantee:** No password is stored unless it passes all validation.
- **Success Guarantee:** Password is stored as a salted hash; subscriber can authenticate with it.

---

### UC-2: Validate Password Against Blocklist

- **Primary Actor:** Verifier (automated)
- **Goal:** Reject passwords an attacker already knows
- **Scope:** Verifier
- **Level:** Subfunction (called by UC-1)
- **Trigger:** Subscriber submits a new password
- **Preconditions:** Blocklist sources loaded
- **Stakeholders:**
  - Subscriber — wants clear feedback if rejected
  - Attacker — has breach corpuses with hundreds of millions of passwords; tries the top candidates first
- **Main Success Scenario:**
  1. Verifier normalizes the password for comparison
  2. Verifier checks against breach corpuses, dictionary words, sequential/repetitive strings, and context-specific terms (service name, username)
  3. Password not found; verifier accepts it
- **Extensions:**
  - 2a. *Password found in breach corpus:*
    This password is in the attacker's list. Verifier rejects and explains why. UC-1 resumes at step 1.
  - 2b. *Password is a common dictionary word:*
    Attacker tries dictionary words early. Verifier rejects. UC-1 resumes at step 1.
  - 2c. *Password is sequential or repetitive (`123456`, `aaaaaa`):*
    Trivially guessable. Verifier rejects. UC-1 resumes at step 1.
  - 2d. *Password contains the username or service name:*
    Attacker targets context-specific passwords. Verifier rejects. UC-1 resumes at step 1.
  - 2e. *Blocklist service unavailable, no cache:*
    Verifier cannot ensure the password isn't compromised. Rejects and asks subscriber to retry. Fail.
- **Minimal Guarantee:** No password an attacker already has is accepted.
- **Success Guarantee:** Only passwords absent from all blocklist sources proceed to storage.

---

### UC-3: Store a Password

- **Primary Actor:** Verifier (automated)
- **Goal:** Store the password so it resists offline cracking if the database is stolen
- **Scope:** Verifier
- **Level:** Subfunction (called by UC-1)
- **Trigger:** Password passed validation
- **Preconditions:** Password in memory, not yet persisted
- **Stakeholders:**
  - Subscriber — wants their credential safe even if the database is breached
  - Attacker — has stolen the hash database and will attempt offline cracking with GPU clusters
- **Main Success Scenario:**
  1. Verifier generates a random salt
  2. Verifier hashes the password using an approved hashing scheme with a high cost factor
  3. Verifier stores the hash and salt
- **Extensions:**
  - 2a. *Attacker steals the hash database:*
    With a weak hash (MD5, SHA-1, fast PBKDF2), the attacker cracks most passwords in hours. With a memory-hard scheme and high cost factor, each guess is expensive. The cost factor should be as high as practical without degrading login performance.
  - 2b. *Pepper available:*
    Verifier applies an additional keyed hash with a secret stored separately. Even if the database is stolen, the attacker also needs the pepper. Continue step 3.
  - 3a. *Database write fails:*
    Password not stored. Subscriber informed. UC-1 may retry.
- **Technology & Data Variations:**
  - Approved hashing schemes per NIST SP 800-132
  - Salt: at least 32 bits from approved random source
  - Pepper: optional, stored in HSM or separate key store
- **Minimal Guarantee:** Plaintext password is never persisted.
- **Success Guarantee:** Password stored as salted hash that resists offline cracking.

---

### UC-4: Authenticate with Password

- **Primary Actor:** Subscriber
- **Goal:** Prove identity to the verifier
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Subscriber initiates login
- **Preconditions:** Subscriber has a registered password; connection is encrypted
- **Stakeholders:**
  - Subscriber — wants to log in quickly
  - Verifier — wants to confirm identity without leaking information to attackers
  - Attacker — has breached credential lists; wants to stuff, guess, or enumerate
- **Main Success Scenario:**
  1. Subscriber submits username and password
  2. Verifier retrieves stored hash and salt
  3. Verifier validates the submitted password against the stored hash
  4. Verifier establishes an authenticated session (UC-7)
- **Extensions:**
  - 2a. *Account does not exist:*
    Attacker is enumerating usernames. Verifier performs a dummy hash computation so response time is identical to a real account. Returns generic error. UC-5 applies. Resume step 1.
  - 3a. *Password does not match:*
    Generic error — does not reveal whether the username or password was wrong. UC-5 rate limiting applies. Resume step 1.
  - 3b. *Account requires MFA (AAL2+):*
    Password alone isn't enough. Verifier prompts for second factor (UC-6). Session created after UC-6 succeeds.
  - 3c. *Account is temporarily locked (UC-5):*
    Attacker triggered the lockout with repeated guesses. Verifier informs subscriber of recovery options. Fail.
  - 3d. *Attacker uses credential stuffing (username/password pairs from another breach):*
    Rate limiting (UC-5) caps attempts per account. Attacker cannot scale beyond the threshold without triggering lockout or CAPTCHA.
- **Minimal Guarantee:** Failed attempts are logged and rate-limited. No information leaked about account existence or which factor failed.
- **Success Guarantee:** Subscriber is authenticated; session established at the required AAL.

---

### UC-5: Rate-Limit Authentication Attempts

- **Primary Actor:** Verifier (automated)
- **Goal:** Make online guessing impractical without permanently locking out legitimate subscribers
- **Scope:** Verifier
- **Level:** Subfunction (called by UC-4)
- **Trigger:** Failed authentication attempt
- **Preconditions:** Per-account failure counter maintained
- **Stakeholders:**
  - Subscriber — does not want to be permanently locked out of their own account
  - Attacker — wants unlimited guessing attempts; also wants to weaponize lockout as denial-of-service
- **Main Success Scenario:**
  1. Verifier increments the per-account failure counter
  2. Verifier evaluates the counter against the threshold and allows the attempt
  3. Subscriber eventually authenticates; counter resets
- **Extensions:**
  - 2a. *Threshold reached (100 consecutive failures):*
    Verifier applies throttling — escalating delays, CAPTCHA, or temporary lockout. Resume step 2 after throttle clears.
  - 2b. *Attacker uses lockout as denial-of-service:*
    Permanent lockout would let the attacker lock out any account by failing 100 times. Account is never permanently locked. Recovery mechanism always available.
- **Minimal Guarantee:** Account is never permanently locked.
- **Success Guarantee:** Online guessing is impractical within the rate limits.

---

### UC-6: Authenticate with Second Factor

- **Primary Actor:** Subscriber
- **Goal:** Provide a second authentication factor for AAL2+ access
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Verifier requires MFA after password verification
- **Preconditions:** First factor verified; second factor registered
- **Stakeholders:**
  - Subscriber — wants convenient but secure second factor
  - Attacker — wants to bypass the second factor via phishing, SIM swap, or device theft
- **Main Success Scenario:**
  1. Verifier prompts for second factor
  2. Subscriber provides a cryptographic assertion, OTP code, or push approval
  3. Verifier validates the second factor
  4. Verifier confirms authentication intent — subscriber consciously approved
  5. Authentication succeeds; session established (UC-7)
- **Extensions:**
  - 2a. *Subscriber's device is lost or broken:*
    Subscriber uses an alternative registered factor or initiates recovery (UC-9). Fail for this UC.
  - 3a. *OTP code reused (replay):*
    Attacker intercepted a valid code and replays it. Each code is single-use. Verifier rejects. Resume step 1.
  - 3b. *Attacker phishes the second factor:*
    At AAL2, phishing may succeed with OTP codes. At AAL3, hardware cryptographic authenticators with verifier impersonation resistance make phishing structurally impossible.
  - 3c. *Attacker SIM-swaps to intercept SMS OTP:*
    SMS OTP is permitted at AAL2 but restricted — should not be the sole option where alternatives exist. Prohibited at AAL3.
  - 4a. *No authentication intent:*
    Subscriber must consciously approve, not just possess the device. Verifier rejects without intent. Resume step 1.
- **Technology & Data Variations:**
  - AAL2: password + any second factor (TOTP, hardware key, push)
  - AAL3: password + hardware cryptographic authenticator providing verifier impersonation resistance
  - SMS OTP: permitted at AAL2 (restricted), prohibited at AAL3
- **Minimal Guarantee:** Authentication does not succeed without a valid second factor at AAL2+.
- **Success Guarantee:** Two distinct factors verified; authentication intent confirmed.

---

### UC-7: Use an Authenticated Session

- **Primary Actor:** Subscriber
- **Goal:** Maintain authenticated access for the duration of a work session
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Successful authentication
- **Preconditions:** Authentication completed at the required AAL
- **Stakeholders:**
  - Subscriber — wants persistent access; wants to log out when done
  - Attacker — wants to steal, replay, or fixate session tokens
- **Main Success Scenario:**
  1. Verifier generates a session token with enough randomness to be unguessable
  2. Verifier delivers the token over an encrypted connection
  3. Subscriber makes authenticated requests
  4. Subscriber logs out
  5. Verifier invalidates the session server-side
- **Extensions:**
  - 3a. *Subscriber walks away (inactivity timeout):*
    Session expires. Subscriber must reauthenticate (UC-4). Resume step 1.
  - 3b. *Absolute timeout reached (e.g., 12 hours):*
    Session expires regardless of activity. Prevents stolen tokens from being useful indefinitely. Resume step 1.
  - 3c. *Attacker steals the session token:*
    Token was embedded in a URL and leaked via referrer header, or extracted via XSS. Token must never be in URLs. Session tokens must be delivered only over encrypted connections.
  - 3d. *Attacker replays token from different context:*
    Verifier flags anomalous IP or user-agent. May invalidate session or require reauthentication.
  - 5a. *Subscriber only deletes the cookie client-side:*
    Session remains valid server-side. Attacker who obtained the token can still use it. Logout must invalidate server-side.
- **Minimal Guarantee:** Session is always invalidated on logout or timeout. Server-side invalidation.
- **Success Guarantee:** Session is maintained while active, terminated cleanly on logout or timeout.

---

### UC-8: Restore Account Security After Compromise

- **Primary Actor:** Subscriber
- **Goal:** Replace a compromised password and restore the account to a secure state
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Subscriber is informed their password must be changed
- **Preconditions:** Verifier has flagged the password as compromised
- **Stakeholders:**
  - Subscriber — wants to regain security without losing access
  - Attacker — wants to use the compromised credential before it's changed; may have already changed it
- **Main Success Scenario:**
  1. Subscriber attempts to log in
  2. Verifier authenticates the subscriber
  3. Verifier forces password change before granting session
  4. Subscriber chooses a new password (UC-1)
  5. Verifier invalidates the compromised password and prevents its reuse
  6. Verifier grants session with new password
- **Extensions:**
  - 1a. *Attacker already changed the password:*
    Subscriber is locked out. Account recovery (UC-9) required. Fail for this UC.
  - 1b. *Subscriber doesn't log in for weeks:*
    Flag persists. Forced change applies whenever they return.
  - 4a. *Subscriber tries to reuse the compromised password:*
    Attacker who obtained the old password could guess the subscriber would try to keep it. Reuse is prohibited. Resume step 4.
  - *a. *System triggers this change on a 90-day timer instead of breach evidence:*
    This is forced rotation — it produces the mutation problem described in UC-1 ext *a. Change is forced only on evidence of compromise, never on a calendar.
- **Minimal Guarantee:** Compromised password cannot be used after the forced-change login.
- **Success Guarantee:** New password set; compromised credential permanently invalidated.

---

### UC-9: Recover Account

- **Primary Actor:** Subscriber
- **Goal:** Regain access when the primary authenticator is lost or forgotten
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Subscriber cannot authenticate
- **Preconditions:** Recovery mechanism registered
- **Stakeholders:**
  - Subscriber — wants to regain access without excessive friction
  - Attacker — wants to hijack the account by social-engineering the recovery flow
- **Main Success Scenario:**
  1. Subscriber initiates recovery
  2. Verifier presents recovery challenge appropriate to the account's AAL
  3. Subscriber provides recovery codes or alternative second factor
  4. Verifier validates and grants limited access (password change only)
  5. Subscriber sets new password (UC-1) and registers new authenticators if needed
  6. Verifier notifies subscriber that authenticators were changed
- **Extensions:**
  - 2a. *AAL2+ account, attacker tries email-only recovery:*
    Email alone would bypass the second factor. Recovery must match the account's assurance level. AAL2 requires recovery codes or alternative MFA. Fail for email-only at AAL2+.
  - 3a. *Recovery code already used:*
    Codes are single-use. Attacker who obtained one code cannot reuse it. Resume step 3 with another code.
  - 3b. *All recovery codes exhausted:*
    Subscriber contacts support. Re-enrollment at original identity proofing level. Fail for automated recovery.
  - 3c. *Attacker attempts social-engineering:*
    Recovery requires a registered mechanism, not human judgment. Automated flow rejects. Fail.
  - 6a. *Subscriber did not initiate the change:*
    Notification alerts subscriber to potential takeover. Subscriber can lock account.
- **Technology & Data Variations:**
  - AAL1: email-based recovery acceptable
  - AAL2+: recovery codes or alternative MFA required
- **Minimal Guarantee:** Recovery never downgrades the account's assurance level.
- **Success Guarantee:** Subscriber regains access with fresh credentials at the original AAL.

