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

I formatted the Rev 4 requirements as Cockburn-style use cases — the kind you
can hand to an implementation team and trace through to audit. Each use case
includes compliance constraints linked to specific Rev 4 sections.

The use cases add a non-standard "Compliance Constraints" field to the
Cockburn template. NIST's SHALL/SHALL NOT rules don't fit cleanly into
extensions or technology variations — they're normative rules governing the
use case. They need their own home.

## System Scope

**System:** Verifier — the authentication subsystem that validates subscriber credentials, manages sessions, and enforces credential policy.

**In scope:**
- Password creation, validation, and storage
- Blocklist enforcement
- Multi-factor authentication
- Rate limiting and lockout
- Session management
- Credential compromise response
- Account recovery

**Adjacent (CSP scope, separate system):**
- Identity proofing (SP 800-63A)
- Credential issuance and lifecycle administration
- API/machine credential management

**Out of scope:**
- Federation and assertions (SP 800-63C)
- Application-level authorization
- Network security (TLS configuration, firewall rules)

---

## Actors

### Subscriber
End user who authenticates to a system. Varying technical skill — may use passwords, password managers, MFA devices, or recovery codes. Wants to get in with minimum friction. Trusts the system to protect them.

### Verifier
The system component that validates subscriber credentials. Automated. Responsible for storage, rate limiting, session management, blocklist enforcement. The system under design.

### CSP (Credential Service Provider)
Organization that issues, manages, and revokes credentials. May operate the verifier. Has compliance and audit obligations. Adjacent actor — some UCs touch CSP boundary.

### Attacker
Adversary attempting unauthorized access. Methods: credential stuffing, brute force, phishing, SIM swap, database compromise, social engineering. Assumed to have breach corpuses and common password lists.

---

## Actor-Goal List

| Actor      | Goal                                                    | Level       |
| ---------- | ------------------------------------------------------- | ----------- |
| Subscriber | Set an appropriate secret (memorized or manager-stored) | User goal   |
| Subscriber | Authenticate with password                              | User goal   |
| Subscriber | Authenticate with second factor                         | User goal   |
| Subscriber | Use an authenticated session                            | User goal   |
| Subscriber | Restore account security after compromise               | User goal   |
| Subscriber | Recover account                                         | User goal   |
| Verifier   | Validate password against blocklist                     | Subfunction |
| Verifier   | Store a password                                        | Subfunction |
| Verifier   | Rate-limit authentication attempts                      | Subfunction |
| CSP        | Manage API/machine credentials                          | Summary     |

---

## Related Use Cases

```
UC-1 Set an Appropriate Secret
 ├── UC-2 Validate Password Against Blocklist (subfunction)
 └── UC-3 Store a Password (subfunction)

UC-4 Authenticate with Password
 ├── UC-5 Rate-Limit Authentication Attempts (subfunction, on failure)
 ├── UC-6 Authenticate with Second Factor (AAL2+)
 └── UC-7 Use an Authenticated Session (on success)

UC-8 Restore Account Security After Compromise
 ├── UC-1 Set an Appropriate Secret (for new password)
 └── UC-9 Recover Account (if locked out)

UC-9 Recover Account
 └── UC-1 Set an Appropriate Secret (after recovery)

UC-10 Manage API/Machine Credentials (summary)
 ├── UC-10a Issue Credential
 ├── UC-10b Rotate Credential
 └── UC-10c Revoke Credential
```

---

## Use Cases

### UC-1: Set an Appropriate Secret

- **Primary Actor:** Subscriber
- **Goal:** Set a password that the subscriber can use to authenticate
- **Scope:** Verifier
- **Level:** User goal
- **Secondary Actors:** Blocklist service (breach corpus provider), password manager (client-side)
- **Trigger:** Subscriber creates an account or changes their password
- **Preconditions:** Subscriber has an authenticated session (for change) or identity has been proofed (for enrollment)
- **Stakeholders:**
  - Subscriber — wants a password they can use to get in
  - Verifier — wants the password to resist offline and online guessing
  - CSP — wants compliance with SP 800-63B [§3.1.1](https://pages.nist.gov/800-63-4/sp800-63b.html#password)
  - Attacker — wants subscribers to choose predictable passwords
- **Main Success Scenario:**
  1. Subscriber enters a password of their choice
  2. Verifier validates the password length
  3. Verifier validates the password against the blocklist (UC-2)
  4. Verifier hashes and stores the password (UC-3)
  5. Verifier confirms the password is set
- **Extensions:**
  - 2a. *Password shorter than minimum length:*
    Verifier rejects and provides guidance. Resume step 1.
  - 3a. *Password appears on blocklist:*
    Verifier rejects and provides guidance. Resume step 1.
  - 4a. *Storage fails:*
    Verifier informs subscriber. No password stored. Resume step 1.
  - *a. *Connection drops mid-submission:*
    No password stored. Subscriber retries. Resume step 1.
- **Technology & Data Variations:**
  - Unicode normalization: NFKC or NFKD before hashing
  - Input method: keyboard entry, paste from password manager, autofill
  - Display: show/hide toggle for password field
  - Password manager: subscriber generates a random, non-memorizable password and delegates storage to the manager. The secret is persisted, not memorized. The subscriber's goal shifts from "choose something I can remember" to "generate something strong." NIST classifies both as "memorized secrets" but the interaction and failure modes differ — a lost manager means a lost password, not a forgotten one.
- **Compliance Constraints (SP 800-63B [§3.1.1](https://pages.nist.gov/800-63-4/sp800-63b.html#password)):**
  - SHALL require minimum 15 characters (single-factor); 8 characters (MFA-combined)
  - SHOULD permit at least 64 characters
  - SHOULD accept all printing ASCII and Unicode, including spaces
  - SHALL allow password managers and autofill; SHOULD permit paste
  - SHALL NOT impose composition rules (no forced uppercase, digit, special character)
  - SHALL NOT truncate the password
  - SHALL NOT require periodic rotation
  - SHOULD allow show/hide toggle
- **Minimal Guarantee:** No password is stored unless it passes all validation.
- **Success Guarantee:** Password is stored hashed and salted; subscriber can authenticate with it.

---

### UC-2: Validate Password Against Blocklist

- **Primary Actor:** Verifier (automated)
- **Goal:** Reject passwords known to be weak or compromised
- **Scope:** Verifier
- **Level:** Subfunction (called by UC-1)
- **Secondary Actors:** Breach corpus provider
- **Trigger:** Subscriber submits a new password
- **Preconditions:** Blocklist is loaded and current
- **Stakeholders:**
  - Subscriber — wants clear feedback if rejected
  - Verifier — wants to prevent use of known-compromised credentials
  - Attacker — wants blocklisted passwords to be accepted
- **Main Success Scenario:**
  1. Verifier normalizes the password for comparison
  2. Verifier validates the password against all blocklist sources
  3. Password is not found in any source; verifier accepts it
- **Extensions:**
  - 2a. *Password found in breach corpus:*
    Verifier rejects, informs subscriber. UC-1 resumes at step 1.
  - 2b. *Password is a dictionary word:*
    Verifier rejects and provides guidance. UC-1 resumes at step 1.
  - 2c. *Password is sequential or repetitive:*
    Verifier rejects. UC-1 resumes at step 1.
  - 2d. *Password contains context-specific words (service name, username):*
    Verifier rejects. UC-1 resumes at step 1.
  - 2e. *Blocklist service unavailable:*
    Verifier uses cached blocklist. If no cache available, verifier rejects password change and informs subscriber to retry later. Fail.
- **Technology & Data Variations:**
  - Breach corpus source (previous breach corpuses per NIST)
  - Dictionary: language-appropriate word list
  - Comparison: case-insensitive, optionally handling common substitutions
- **Compliance Constraints (SP 800-63B [§3.1.1.2](https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver)):**
  - SHALL check against breach corpuses, dictionary words, repetitive/sequential strings, and context-specific words
  - SHALL inform subscriber when rejected and provide guidance
- **Minimal Guarantee:** No blocklisted password is accepted. If blocklist is unavailable and no cache exists, password setting is refused rather than bypassed.
- **Success Guarantee:** Only passwords not on the blocklist proceed to storage.

---

### UC-3: Store a Password

- **Primary Actor:** Verifier (automated)
- **Goal:** Store the password so it resists offline attack if the database is compromised
- **Scope:** Verifier
- **Level:** Subfunction (called by UC-1)
- **Secondary Actors:** HSM or key management service (if pepper is used)
- **Trigger:** Password has passed validation and blocklist
- **Preconditions:** Password is in memory, not yet persisted
- **Stakeholders:**
  - Subscriber — wants their credential safe even in a breach
  - CSP — wants defense-in-depth against database compromise
  - Attacker — wants to crack hashes if database is stolen
- **Main Success Scenario:**
  1. Verifier generates a random salt from an approved random source
  2. Verifier normalizes and hashes the password using an approved hashing scheme
  3. Verifier stores the hash and salt
- **Extensions:**
  - 2a. *Pepper available:*
    Verifier applies HMAC with a secret key stored separately. Continue step 3.
  - 3a. *Database write fails:*
    Password not stored. Subscriber informed. UC-1 may retry.
- **Technology & Data Variations:**
  - Approved hashing schemes: per SP 800-132 or updated NIST guidelines (e.g., Argon2id, bcrypt, scrypt, PBKDF2)
  - Pepper: optional HMAC key stored outside the database
  - Implementation note: plaintext should be zeroed from memory after hashing
- **Compliance Constraints (SP 800-63B [§3.1.1.2](https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver)):**
  - SHALL salt and hash using approved one-way KDF
  - Salt SHALL be at least 32 bits from approved random source
  - SHALL NOT store in plaintext or with reversible encryption
  - Cost factor SHOULD be as high as practical; for PBKDF2, at least 10,000 iterations
- **Minimal Guarantee:** Plaintext password is never persisted.
- **Success Guarantee:** Password stored as salted hash using approved KDF.

---

### UC-4: Authenticate with Password

- **Primary Actor:** Subscriber
- **Goal:** Prove identity to the verifier using their password
- **Scope:** Verifier
- **Level:** User goal
- **Secondary Actors:** Password manager (client-side)
- **Trigger:** Subscriber initiates login
- **Preconditions:** Subscriber has a registered password; connection is over TLS
- **Stakeholders:**
  - Subscriber — wants to log in quickly; wants password manager support
  - Verifier — wants to confirm identity; wants to prevent brute force
  - Attacker — wants to guess or stuff credentials
- **Main Success Scenario:**
  1. Subscriber submits username and password
  2. Verifier retrieves stored hash and salt for the account
  3. Verifier validates the submitted password against the stored hash
  4. Verifier establishes an authenticated session (UC-7)
- **Extensions:**
  - 2a. *Account does not exist:*
    Verifier performs dummy hash computation (constant-time). Generic error. UC-5 applies. Resume step 1.
  - 3a. *Password does not match:*
    Generic error. UC-5 rate limiting applies. Resume step 1.
  - 3b. *Account requires MFA (AAL2+):*
    Verifier prompts for second factor (UC-6). Session created after UC-6 succeeds.
  - 3c. *Account is temporarily locked (UC-5):*
    Verifier informs subscriber of lockout and recovery options. Fail.
- **Compliance Constraints (SP 800-63B [§3.1.1](https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver), [§3.2.2](https://pages.nist.gov/800-63-4/sp800-63b.html#throttle)):**
  - SHALL allow password managers; SHOULD permit paste
  - SHALL NOT reveal which factor failed or whether account exists
  - SHALL implement rate limiting (UC-5)
- **Minimal Guarantee:** Failed attempts are logged and rate-limited. No information leaked about which factor failed or whether the account exists.
- **Success Guarantee:** Subscriber is authenticated; session is established at the required AAL.

---

### UC-5: Rate-Limit Authentication Attempts

- **Primary Actor:** Verifier (automated)
- **Goal:** Prevent online guessing attacks without permanently locking out legitimate users
- **Scope:** Verifier
- **Level:** Subfunction (called by UC-4)
- **Trigger:** Failed authentication attempt on an account
- **Preconditions:** Per-account failure counter is maintained
- **Stakeholders:**
  - Subscriber — wants to eventually succeed; does not want permanent lockout
  - Verifier — wants to stop brute force within feasible attempt budget
  - Attacker — wants unlimited guessing attempts
- **Main Success Scenario:**
  1. Verifier increments the per-account failure counter
  2. Verifier evaluates the counter against the threshold and allows the attempt
  3. Subscriber eventually authenticates; counter resets
- **Extensions:**
  - 2a. *Threshold reached:*
    Verifier applies throttling (CAPTCHA, temporary lockout, or exponential backoff). Resume step 2 after throttle clears.
  - 2b. *Temporary lockout applied:*
    Verifier provides recovery mechanism. Resume when lockout expires or recovery completes.
- **Technology & Data Variations:**
  - Throttling: increasing delays, CAPTCHA, proof-of-work, temporary lockout
  - Supplementary: IP-based rate limiting (not sole mechanism due to shared IPs/VPNs)
- **Compliance Constraints (SP 800-63B [§3.2.2](https://pages.nist.gov/800-63-4/sp800-63b.html#throttle)):**
  - SHALL limit consecutive failures to no more than 100 before additional verification
  - SHALL NOT permanently lock the account
  - SHALL provide a recovery mechanism
  - SHOULD NOT reveal which factor failed
- **Minimal Guarantee:** Account is never permanently locked. Recovery path always exists.
- **Success Guarantee:** Online guessing is infeasible within rate limits.

---

### UC-6: Authenticate with Second Factor

- **Primary Actor:** Subscriber
- **Goal:** Provide a second authentication factor for AAL2+ access
- **Scope:** Verifier
- **Level:** User goal
- **Secondary Actors:** Hardware cryptographic authenticator, OTP authenticator app
- **Trigger:** Verifier requires MFA after password verification (UC-4 ext 3b)
- **Preconditions:** First factor verified; second factor registered to the account
- **Stakeholders:**
  - Subscriber — wants convenient but secure second factor
  - Verifier — wants phishing resistance at AAL3; wants authentication intent
  - Attacker — wants to bypass via phishing, SIM swap, or device theft
- **Main Success Scenario:**
  1. Verifier prompts for second factor
  2. Subscriber provides second factor (cryptographic assertion, OTP code, or push approval)
  3. Verifier validates the second factor
  4. Verifier confirms authentication intent (subscriber consciously approved)
  5. Authentication succeeds; session established (UC-7)
- **Extensions:**
  - 2a. *Subscriber's registered device is lost or broken:*
    Subscriber uses alternative registered factor or initiates recovery (UC-9). Fail for this UC.
  - 3a. *Second factor invalid or expired:*
    Verifier rejects. Rate limiting applies (UC-5). Resume step 1.
  - 3b. *TOTP code reused (replay):*
    Verifier rejects. Each code single-use within its time window. Resume step 1.
  - 4a. *No authentication intent established:*
    Verifier rejects. Subscriber must consciously approve. Resume step 1.
- **Technology & Data Variations:**
  - AAL2: password + any second factor (TOTP, FIDO2, push)
  - AAL3: password + hardware cryptographic authenticator providing verifier impersonation resistance
  - SMS OTP: permitted at AAL2 (restricted due to SIM-swap/SS7 vulnerabilities), prohibited at AAL3
- **Compliance Constraints (SP 800-63B [§§2.2-2.3](https://pages.nist.gov/800-63-4/sp800-63b.html#AAL_SEC4)):**
  - SHALL establish authentication intent (conscious subscriber approval)
  - SHALL NOT use SMS OTP at AAL3
  - SHOULD support phishing-resistant authenticators (FIDO2/WebAuthn)
- **Minimal Guarantee:** Authentication does not succeed without valid second factor at AAL2+.
- **Success Guarantee:** Two distinct factors verified; authentication intent confirmed.

---

### UC-7: Use an Authenticated Session

- **Primary Actor:** Subscriber
- **Goal:** Maintain authenticated access for the duration of a work session
- **Scope:** Verifier
- **Level:** User goal
- **Trigger:** Successful authentication (UC-4 or UC-6 completion)
- **Preconditions:** Subscriber has completed authentication at the required AAL
- **Stakeholders:**
  - Subscriber — wants persistent access within reasonable bounds; wants to log out when done
  - Verifier — wants to limit session exposure window
  - Attacker — wants to steal, replay, or fixate session tokens
  - Relying application — depends on valid session for downstream authorization
- **Main Success Scenario:**
  1. Verifier generates a session token
  2. Verifier delivers the token to the subscriber's client over TLS
  3. Subscriber makes authenticated requests
  4. Subscriber logs out
  5. Verifier invalidates the session server-side
- **Extensions:**
  - 3a. *Inactivity timeout reached (30 minutes):*
    Verifier invalidates session. Subscriber reauthenticates (UC-4). Resume step 1.
  - 3b. *Absolute timeout reached (12 hours):*
    Verifier invalidates session regardless of activity. Subscriber reauthenticates (UC-4). Resume step 1.
  - 3c. *AAL2+ periodic reauthentication required:*
    Verifier prompts for both factors. Resume step 3 on success.
  - 3d. *Session token replayed from anomalous context:*
    Verifier flags anomaly. May invalidate session (fail) or require reauthentication (resume step 1).
- **Technology & Data Variations:**
  - Token delivery: cookie, bearer token header
  - Timeout values adjustable by risk assessment
- **Compliance Constraints (SP 800-63B [§4](https://pages.nist.gov/800-63-4/sp800-63b.html#session)):**
  - Session token SHALL have at least 64 bits of entropy from approved random source
  - Token SHALL be sent only over TLS
  - Token SHALL NOT be embedded in URLs
  - Logout SHALL invalidate session server-side (not just client deletion)
  - Inactivity and absolute timeouts are AAL-dependent (see reauthentication requirements per §2.2-2.3)
- **Minimal Guarantee:** Session is always invalidated on logout, inactivity timeout, or absolute timeout. Server-side invalidation.
- **Success Guarantee:** Session is maintained while active, terminated on logout or timeout. Server-side state is always cleaned up.

---

### UC-8: Restore Account Security After Compromise

- **Primary Actor:** Subscriber
- **Goal:** Replace a compromised password and restore account to a secure state
- **Scope:** Verifier
- **Level:** User goal
- **Secondary Actors:** Breach monitoring service (triggers the flow)
- **Trigger:** Subscriber is informed their password must be changed (at login, via notification, or by their own initiative after suspected compromise)
- **Preconditions:** Account exists; verifier has flagged the password as compromised
- **Stakeholders:**
  - Subscriber — wants to regain security without losing access
  - Verifier — wants compromised credential invalidated promptly
  - CSP — wants audit trail of compromise response
  - Attacker — wants to use the credential before it's changed
- **Main Success Scenario:**
  1. Subscriber attempts to log in
  2. Verifier authenticates the subscriber
  3. Verifier forces password change before granting session
  4. Subscriber chooses a new password (UC-1)
  5. Verifier invalidates the compromised password and prevents its reuse
  6. Verifier grants session with new password
- **Extensions:**
  - 1a. *Attacker already changed the password:*
    Subscriber cannot authenticate. Account recovery required (UC-9). Fail for this UC.
  - 1b. *Subscriber doesn't log in for extended period:*
    Account remains flagged. Forced change applies on next login. Resume step 1 when subscriber returns.
  - 4a. *Subscriber attempts to reuse compromised password:*
    Verifier rejects. Resume step 4.
- **Compliance Constraints (SP 800-63B [§3.1.1](https://pages.nist.gov/800-63-4/sp800-63b.html#password)):**
  - SHALL force change only on evidence of compromise or subscriber request
  - SHALL NOT require periodic/arbitrary rotation
  - SHALL NOT allow the compromised password to be reused
  - SHALL force change at next login when compromise is detected
- **Minimal Guarantee:** Compromised password cannot be used after forced-change login completes.
- **Success Guarantee:** New password set; compromised credential permanently invalidated; account at full security.

---

### UC-9: Recover Account

- **Primary Actor:** Subscriber
- **Goal:** Regain access when the primary authenticator is lost or forgotten
- **Scope:** Verifier
- **Level:** User goal
- **Secondary Actors:** Email service (AAL1 only), alternative MFA device
- **Trigger:** Subscriber cannot authenticate
- **Preconditions:** Subscriber's identity was previously proofed; recovery mechanism registered
- **Stakeholders:**
  - Subscriber — wants to regain access without excessive friction
  - CSP — wants to prevent unauthorized takeover via recovery bypass
  - Attacker — wants to social-engineer the recovery flow
  - Help desk — may be involved if all automated recovery paths fail
- **Main Success Scenario:**
  1. Subscriber initiates recovery
  2. Verifier presents recovery challenge appropriate to the account's AAL
  3. Subscriber provides recovery codes or alternative second factor
  4. Verifier validates and grants limited access (password change only)
  5. Subscriber sets new password (UC-1) and registers new authenticators if needed
  6. Verifier notifies subscriber that authenticators were changed
- **Extensions:**
  - 3a. *Recovery code already used:*
    Verifier rejects (single-use). Subscriber uses another code. Resume step 3.
  - 3b. *All recovery codes exhausted:*
    Subscriber contacts support. Re-enrollment at original identity proofing level. Fail for automated recovery.
  - 3c. *Attacker attempts social-engineering recovery:*
    Automated flow rejects — requires registered mechanism, not human judgment. Fail.
  - 6a. *Subscriber did not initiate the change:*
    Notification alerts subscriber to potential takeover. Subscriber can lock account. Separate success (account secured via lock).
- **Technology & Data Variations:**
  - AAL1: email-based recovery link acceptable
  - AAL2+: recovery codes or alternative MFA required (email alone insufficient)
- **Compliance Constraints (SP 800-63B [§3.2.8](https://pages.nist.gov/800-63-4/sp800-63b.html#recovery)):**
  - Recovery SHALL NOT bypass the account's assurance level
  - Recovery codes: ≥ 20 bits entropy each, hashed before storage, single-use
  - Subscriber SHALL be notified when authenticators are added, removed, or changed
  - Re-enrollment SHALL require same identity proofing level as initial enrollment
- **Minimal Guarantee:** Recovery never downgrades the account's assurance level. Subscriber always notified of changes.
- **Success Guarantee:** Subscriber has regained access with fresh credentials at the original AAL.

---

### UC-10: Manage API/Machine Credentials (Companion — not derived from 800-63B)

- **Primary Actor:** CSP / System Administrator
- **Goal:** Maintain secure machine-to-machine authentication throughout the credential lifecycle
- **Scope:** CSP (adjacent to verifier)
- **Level:** Summary
- **Secondary Actors:** Secrets manager, OAuth2 authorization server
- **Trigger:** A service needs to authenticate to another service
- **Preconditions:** Services registered; credential management infrastructure exists
- **Stakeholders:**
  - System administrator — wants credentials managed without manual intervention
  - Services — depend on valid credentials for operation
  - Attacker — wants to extract long-lived credentials
  - Auditor — wants credential lifecycle traceable and compliant
- **Main Success Scenario:**
  1. Administrator issues a credential for the service (UC-10a)
  2. Service authenticates using the credential
  3. Administrator rotates the credential on a risk-based schedule (UC-10b)
  4. When the credential is no longer needed or is compromised, administrator revokes it (UC-10c)
- **Extensions:**
  - 2a. *Credential found in source code or logs:*
    Treat as compromise. Immediate revocation (UC-10c) and re-issuance (UC-10a). Resume step 1 with new secret.
  - 2b. *Secrets manager unavailable:*
    Service cannot authenticate. Failover or manual intervention required.
- **Technology & Data Variations:**
  - Long-lived shared secrets vs short-lived OAuth2 tokens (prefer tokens)
  - Storage: secrets manager (never source code, never plaintext env vars)
- **Compliance Constraints (SP 800-63B):**
  - Shared secrets SHALL have ≥ 112 bits of entropy
  - Credentials SHALL NOT be embedded in source code
  - Rotation SHALL be risk-based, not arbitrary calendar
- **Minimal Guarantee:** Secrets are never in source code. Revocation is always possible. Lifecycle is auditable.
- **Success Guarantee:** Machine credentials are high-entropy, securely stored, rotatable, revocable, and auditable.

**Child use cases** (UC-10a Issue, UC-10b Rotate, UC-10c Revoke) would be written as separate user-goal UCs if this summary is decomposed for implementation.

---

## Evolution of NIST Password Guidance

Password rotation was retired as a recommendation in **Rev 3 (June 2017)** — the first major departure from decades of conventional wisdom. Key changes since:

**Rev 3 (SP 800-63B, June 2017)** — the paradigm shift:
- SHOULD NOT require periodic password changes (first time this was reversed)
- SHOULD NOT impose composition rules (mixed case, digits, symbols)
- SHALL check passwords against breach corpuses and blocklists
- SHOULD permit paste (endorsing password managers)
- SHOULD accept Unicode
- Minimum 8 characters
- Memory-hard hashing SHOULD be used

**Rev 4 (SP 800-63B-4, August 2025)** — hardened the Rev 3 guidance:
- SHALL NOT require periodic changes (upgraded from SHOULD NOT)
- SHALL NOT impose composition rules (upgraded from SHOULD NOT)
- SHALL require minimum **15 characters** for single-factor authentication (was 8)
- SHALL allow password managers and autofill (new requirement)
- SHALL offer password strength guidance (upgraded from SHOULD)
- SHALL NOT permit hints or KBA security questions
- SHALL verify the entire password (no truncation, no subset)

The progression shows NIST moving from "stop doing harmful things" (Rev 3) to "you must stop doing harmful things" (Rev 4), while also raising the minimum bar for password length.

---

## References

- NIST SP 800-63B Rev 4 (August 2025): [https://pages.nist.gov/800-63-4/sp800-63b.html](https://pages.nist.gov/800-63-4/sp800-63b.html)
  - Password Verifiers: [https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver](https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver)
- NIST SP 800-63-4: Digital Identity Guidelines (parent)
- NIST SP 800-63A-4: Enrollment and Identity Proofing
- NIST SP 800-63C-4: Federation and Assertions
- NIST SP 800-207: Zero Trust Architecture


## References

- [NIST SP 800-63B Rev 4][rev4] (August 2025) — the current standard
- [NIST SP 800-63B Rev 3][rev3] (June 2017) — the paradigm shift
- [Password Verifiers section][passwordver] — the specific requirements

[rev3]: https://pages.nist.gov/800-63-3/sp800-63b.html
[rev4]: https://pages.nist.gov/800-63-4/sp800-63b.html
[passwordver]: https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver
