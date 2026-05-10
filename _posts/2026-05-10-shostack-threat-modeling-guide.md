---
layout: post
title: "Shostack Threat Modeling Guide"
date: 2026-05-10 12:00:00 -05:00
categories: [ security, software-engineering, threat-modeling ]
---

A practical guide to threat modeling principles, extracted from Adam Shostack's *Threat Modeling: Designing for Security* (2014).

Threat modeling replaces reactive security ("whack-a-mole") with systematic, focused defense. This guide distills Shostack's comprehensive framework into actionable patterns for software teams.

**What this guide covers:**
- The four-question framework for all threat models
- STRIDE mnemonic for systematic threat discovery
- Data flow diagrams for visualizing systems
- Mitigations mapped to each threat category
- Practical worked examples and checklists

**What it doesn't cover:**
- Extended case studies (Acme-DB)
- Full appendices and attack trees
- STRIDE variants in detail (STRIDE-per-interaction, DESIST)
- Extended privacy framework coverage
- Historical context

---

## 1. The Goal: Focused Defense Over Whack-a-Mole

Security without structure is firefighting. You patch one vulnerability, another appears. You chase the latest exploit, missing the architectural flaw. Threat modeling breaks this cycle.

> "Threat modeling is the key to a focused defense. Without threat models, you can never stop playing whack-a-mole."

> "In short, threat modeling is the use of abstractions to aid in thinking about risks."

**What threat modeling accomplishes:**

| Outcome | How It Helps |
|---------|--------------|
| Find bugs early | Design issues found before code is written |
| Clarify requirements | "Is that really a requirement?" becomes answerable |
| Better products | Fewer redesigns, predictable schedules |
| Unique discoveries | Finds issues other tools miss (omissions, novel threats) |

> "If you think about building a house, decisions you make early will have dramatic effects on security. Wooden walls and lots of ground-level windows expose you to more risks than brick construction. Once you've chosen, changes will be expensive."

**Who it's for:** Software developers, architects, operations, security professionals. You don't need to be a security expert to benefit.

**The real value:** Threat modeling finds issues other techniques won't find—errors of omission like forgetting to authenticate a connection. Code analysis tools can't find these. Your unique design may have unique threats that only systematic analysis will reveal.

---

## 2. The Four Questions

Every threat model answers four questions:

```
┌─────────────────────────────────────────┐
│ 1. What are you building?               │
│    → Draw diagrams, identify components │
├─────────────────────────────────────────┤
│ 2. What can go wrong?                   │
│    → Use STRIDE, attack trees, etc.     │
├─────────────────────────────────────────┤
│ 3. What should you do about it?         │
│    → Mitigate, accept, transfer         │
├─────────────────────────────────────────┤
│ 4. Did you do a decent job?             │
│    → Validate completeness              │
└─────────────────────────────────────────┘
```

You start and end with familiar tasks: drawing on a whiteboard and managing bugs. Everything in between is structured analysis.

**Why these four questions work:**
- Question 1 (what are you building?) forces shared understanding
- Question 2 (what can go wrong?) finds threats systematically
- Question 3 (what to do?) produces actionable bugs
- Question 4 (did we do a good job?) validates completeness

The framework is recursive: you can apply it to a whole system, a component, a feature, or even a single function.

---

## 3. Drawing Your System (Data Flow Diagrams)

> "All models are wrong. Some models are useful."

Data flow diagrams (DFDs) are the foundation. They show:

| Element | Symbol | Description |
|---------|--------|-------------|
| External Entity | Rectangle | People, systems outside your control |
| Process | Circle/Rounded | Code that transforms data |
| Data Store | Parallel lines | Databases, files, caches |
| Data Flow | Arrow | Movement of data |
| Trust Boundary | Dashed line | Where privilege changes |

**Trust boundaries** are critical—they show where threats concentrate. A trust boundary exists wherever:
- Privilege levels change
- Different principals interact
- Data crosses network/machine/process limits

> Trust boundaries and attack surfaces are very similar views of the same thing. An attack surface is a trust boundary plus a direction from which an attacker could launch an attack.

**Diagram rules:**
- Number each process, data flow, and data store
- Data can't move itself—show the process that moves it
- If a component has a trust boundary, it's a candidate for its own diagram
- Don't draw an eye chart—break complex systems into sub-diagrams
- The diagram should tell a story and support you telling stories while pointing at it

**Updating diagrams (validation questions):**
1. Can we tell a story without changing the diagram?
2. Can we tell that story without using "sometimes" or "also"?
3. Can we see exactly where the software makes security decisions?
4. Does the diagram show all trust boundaries (UIDs, roles, network interfaces)?
5. Does it reflect current or planned reality?
6. Can we see where all data goes and who uses it?

---

## 4. Where to Start: Three Approaches

```
What drives your analysis?
  │
  ├─ ASSETS → "What are we protecting?"
  │           Best when: Clear valuable targets
  │           Risk: May miss stepping-stone assets
  │
  ├─ ATTACKERS → "Who's attacking us?"
  │              Best when: Known threat actors
  │              Risk: Attackers not on list still attack
  │
  └─ SOFTWARE → "What are we building?"
                Best when: Development teams
                Risk: May miss operational context
```

**Recommendation:** Start with software (what you're building), use STRIDE to find threats, then validate against known attacker motivations. This combines the benefits of all three.

### The Cautionary Tale of Zero-Knowledge Systems

> "Zero-Knowledge Systems didn't have a clear answer to 'what's your threat model?' Because there was no clear answer, there wasn't consistency in what security features were built."

Without a clear threat model, the company invested heavily in preventing governments from spying—a fun technical challenge but one that had significant performance impacts. The emotional appeal of fighting government surveillance made it hard to make practical business decisions. Eventually, a clearer threat model let them invest in mitigations that all addressed the same subset of threats.

**The lesson:** Without answering "what's your threat model?", you may build elaborate defenses against unlikely attacks while ignoring common ones.

### Standard Answers to "What's Your Threat Model?"

| Answer | Meaning |
|--------|---------|
| "A thief who could steal your money" | Financial motivation, external |
| "Untrusted network" | Assume network traffic can be read/modified |
| "Malicious insiders" | Employees, contractors with access |
| "An attacker who could steal your cookie" | Session hijacking, web app threats |
| "Script kiddie" | Low-skill attacker using automated tools |
| "Nation-state actor" | High-skill, well-resourced attacker |

Having a clear answer focuses your defense investments.

---

## 5. STRIDE: The Six Threat Categories

STRIDE is a mnemonic for finding threats. It was developed at Microsoft and has been refined over more than a decade of use. Each letter represents a threat that violates a security property:

| Threat | Property Violated | Definition | Typical Victims |
|--------|-------------------|------------|-----------------|
| **S**poofing | Authentication | Pretending to be something/someone else | Processes, external entities, people |
| **T**ampering | Integrity | Modifying data (disk, network, memory) | Data stores, data flows, processes |
| **R**epudiation | Non-repudiation | Claiming you didn't do something | Processes |
| **I**nfo Disclosure | Confidentiality | Exposing data to unauthorized parties | Processes, data stores, data flows |
| **D**enial of Service | Availability | Absorbing resources needed for service | Processes, data stores, data flows |
| **E**levation of Privilege | Authorization | Doing things you're not authorized to do | Processes |

> "STRIDE is a tool to guide you to threats, not to ask you to categorize what you've found; it makes a lousy taxonomy, anyway."

**Usage:** Walk through each element in your diagram and ask "How could an attacker achieve S? T? R? I? D? E?" Don't worry about categorization—if you find a threat, record it.

### Detailed Threat Examples

**Spoofing:**
- Spoofing a process on the same machine (creating a file before the real process)
- Spoofing a file (creating in local directory, changing links)
- Spoofing a machine (ARP, IP, DNS spoofing)
- Spoofing a person (phishing, account takeover)
- Spoofing a role (declaring themselves to be that role)

**Tampering:**
- Tampering with a file (modify files on disk, servers, or remote includes)
- Tampering with memory (modify running code or API data by reference)
- Tampering with a network (redirect traffic, modify packets, especially wireless)

**Repudiation:**
- Claiming to have not clicked/received/ordered
- Claiming to be a fraud victim
- Attacking the logs (no logs, filling logs, injecting attacks into logs)

**Information Disclosure:**
- Extracting secrets from error messages
- Reading files with inappropriate ACLs
- Finding crypto keys on disk or in memory
- Reading network traffic (sniffing)
- Analyzing traffic metadata (DNS, social network connections)

**Denial of Service:**
- Absorbing memory (RAM or disk)
- Absorbing CPU
- Using process as an amplifier
- Filling data stores
- Consuming network resources

**Elevation of Privilege:**
- Sending inputs the code doesn't handle properly (buffer overflow, injection)
- Gaining inappropriate memory access
- Bypassing authorization checks
- Data/code confusion (treating data as executable code)

### Focus on Feasible Threats

> "Along the way, you might come up with threats like 'someone might insert a back door at the chip factory.' These are real possibilities but not very likely compared to using an exploit to attack a vulnerability for which you haven't applied the patch."

Good threat modeling focuses on threats you can actually address. If you can't do anything about motherboard backdoors, acknowledge them and move on.

---

## 6. STRIDE-per-Element

Not all threats apply to all elements. This matrix focuses your analysis:

| Element | S | T | R | I | D | E |
|---------|---|---|---|---|---|---|
| External Entity | ✓ | | ✓ | | | |
| Process | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Data Flow | | ✓ | | ✓ | ✓ | |
| Data Store | | ✓ | ? | ✓ | ✓ | |

*(? = Logs are data stores involved in addressing repudiation)*

**Exit criteria:** You have at least one threat per checked cell in your diagram.

**Customization:** This matrix is somewhat Microsoft-specific. Adapt it to your context. For example, if privacy matters, add "Information Disclosure by External Entity."

**STRIDE-per-element weaknesses:**
1. Similar issues crop up repeatedly in a given threat model
2. The chart may not represent your specific issues

> "If you want to be comprehensive, this is helpful; if you want to focus on the most likely issues, it may be a distraction."

**Variants:**
- **STRIDE-per-interaction:** Consider (origin, destination, interaction) tuples. Same number of threats but may be easier to understand.
- **DESIST:** Dispute, Elevation, Spoofing, Information disclosure, Service denial, Tampering. Same concepts, different acronym.

---

## 7. Attack Trees

Attack trees decompose a goal into sub-goals:

```
Goal: Steal credentials
├─ [OR] Phish user
│   ├─ [AND] Create fake login page
│   └─ [AND] Send convincing email
├─ [OR] Compromise database
│   ├─ [OR] SQL injection
│   └─ [OR] Stolen backup
└─ [OR] Intercept network traffic
    └─ [AND] Man-in-the-middle attack
```

**OR nodes:** Any child achieves the goal
**AND nodes:** All children required

**When to use:**
- Organizing threats found with STRIDE
- Deep-diving a specific attack scenario
- Communicating threats to stakeholders

Trees can be created per-project or reused across similar systems.

**Creating an attack tree:**
1. Decide on a representation (AND or OR tree, most are OR)
2. Create a root node (the attacker's goal)
3. Create subnodes (ways to achieve that goal)
4. Consider completeness (are there other paths?)
5. Prune the tree (remove irrelevant branches)
6. Check the presentation (is it understandable?)

**Exit criteria:** When you have threats for each leaf node that applies to your system.

---

## 8. Attack Libraries (CAPEC, OWASP)

Attack libraries provide pre-built threat catalogs:

| Library | Scope | Best For |
|---------|-------|----------|
| CAPEC | 475+ attack patterns | Comprehensive coverage, training |
| OWASP Top Ten | Web application risks | Web projects, quick reference |

**CAPEC trade-off:** Comprehensive but time-intensive (40+ hours for full review). Consider category-level review instead of entry-by-entry.

**CAPEC exit criteria:** At least one issue per categories 1-11:
1. Data Leakage
2. Resource Depletion
3. Injection
4. Spoofing
5. Time and State
6. Abuse of Functionality
7. Probabilistic Techniques
8. Exploitation of Authentication
9. Exploitation of Privilege/Trust
10. Data Structure Attacks
11. Resource Manipulation

Categories 12-15 (Network Reconnaissance, Social Engineering, Physical Security, Supply Chain) may be relevant depending on your system.

**OWASP Top Ten (2013 example):**
1. Injection
2. Broken Authentication/Session Management
3. Cross-Site Scripting
4. Insecure Direct Object References
5. Security Misconfiguration
6. Sensitive Data Exposure
7. Missing Function-Level Access Control
8. Cross-Site Request Forgery
9. Components with Known Vulnerabilities
10. Unvalidated Redirects and Forwards

> "CAPEC is a classification of common attacks, whereas STRIDE is a set of security properties. CAPEC may have more promise than STRIDE for many populations of threat modelers."

**Using OWASP for threat modeling:**

The OWASP Top Ten works well as an adjunct to STRIDE for web projects. To turn it into a methodology:
- Create a "Top Ten per Element" approach (like STRIDE-per-element)
- Look for risks at each point where data crosses a trust boundary

**Trade-off:** Cross-site scripting and CSRF may be overly specific for threat modeling—better as input to test planning. The Top Ten changes yearly based on volunteer input, so its value varies over time.

### When to Use Which

| Situation | Approach |
|-----------|----------|
| New system design | STRIDE (comprehensive, principle-based) |
| Web application | OWASP Top Ten + STRIDE |
| Deep-dive on specific attack | Attack trees |
| Unknown domain | CAPEC categories (structured exploration) |
| Privacy-sensitive | LINDDUN or Solove taxonomy |
| Quick review | STRIDE-per-element on key components |

---

## 9. Privacy Threats (Brief Overview)

Privacy threat modeling is an emergent field. Key frameworks:

**LINDDUN** (mirror of STRIDE for privacy):
- Linkability, Identifiability, Non-repudiation, Detectability, Disclosure of information, Unawareness, Non-compliance

**Solove's Taxonomy:**
- Information collection (surveillance, interrogation)
- Information processing (aggregation, identification, secondary use)
- Information dissemination (disclosure, breach)
- Invasion (intrusion, decisional interference)

**Practical approach:** Treat privacy as complementary to security threat modeling. Focus on data flows involving personal information.

**The nymity slider (Ian Goldberg):**
```
Less Privacy ←────────────────────────────→ More Privacy
Verinymity    Persistent    Linkable    Unlinkable
(Gov't ID,    Pseudonym     Anonymity   Anonymity
Credit Card)  (Pen name)    (Prepaid    (Tor, mixnets)
                            phone)
```

Key insight: It's easy to move toward more nymity (more identifying), extremely difficult to move toward less. Design for privacy from the start.

**Where to look for privacy threats:**
| Solove Category | Where to Focus |
|-----------------|----------------|
| Identifier creation | Wherever your system creates or assigns IDs |
| Surveillance | Data collection points, especially broad collection |
| Interrogation | "Required" fields on forms |
| Aggregation | Inbound data flows from external entities |
| Identification | Where data is matched to real people |
| Exclusion | Decision points, especially fraud management |
| Information dissemination | Outbound data flows crossing trust boundaries |

---

## 10. From Threats to Bugs

Every threat needs action. Track them as bugs in your existing system. The key question: "Did I do something with each unique threat I found?"

> "You really don't want to drop stuff on the floor. This is 'turning the crank' sort of work. It's rarely glamorous or exciting until you find the thing you overlooked."

**Bug template:**
```
Title: [STRIDE category] [Element] - [Threat description]
Description: [How the attack works]
Mitigation: [Proposed defense]
Priority: [Based on impact and likelihood]
```

**Prioritization approaches:**

| Method | Complexity | Best For |
|--------|------------|----------|
| Simple triage | Low | Most teams |
| DREAD scoring | Medium | Quantitative comparison |
| Bug bars | Medium | Consistent thresholds |
| Risk matrices | High | Compliance requirements |

Shostack recommends simple approaches. Elaborate risk scoring often provides false precision.

**Validation checklist:**
1. Have we written down or filed a bug for each threat?
2. Is there a proposed/planned/implemented way to address each threat?
3. Do we have a test case per threat?
4. Has the software passed the test?

---

## 11. The Three Responses

```
How do you respond to a threat?
  │
  ├─ MITIGATE → Make attack harder
  │             Your go-to approach
  │             Example: Add authentication
  │
  ├─ ACCEPT → Acknowledge the risk
  │           When: Low probability OR low impact
  │           Warning: Can't accept on behalf of users
  │
  └─ TRANSFER → Let someone else handle it
                To: OS, framework, customer, insurer
                Warning: Transferred risk still exists
```

**Anti-pattern: IGNORE**
> "A traditional approach to risk in information security is to ignore it... This approach is becoming less effective as contracts, lawsuits, and laws increase the risk of ignoring risks."

**Decision guidance:**
- If there's an easy fix, just fix it (skip strategizing)
- Mitigation is generally easiest and best for customers
- Document accepted risks explicitly

**The "ignoring risks" trap:**

> "A traditional approach to risk in information security is to ignore it... This approach is becoming less effective as contracts, lawsuits, and laws increase the risk of ignoring risks."

If you create a list of security problems you decide not to address, be aware:
- Breach disclosure laws may require action
- Whistleblowers may expose the list
- Legal discovery in lawsuits may reveal it
- Regulatory requirements continue to increase

> "If you are threat modeling and create a list of security problems that you decide not to address, please send a copy of the list to the author, care of the publisher. There will be quarterly auctions to sell them to plaintiff's attorneys."

---

## 12. Mitigations Mapped to STRIDE

| Threat | Mitigation Strategy | Techniques |
|--------|---------------------|------------|
| **Spoofing** | Authentication | Passwords, tokens, biometrics, digital signatures, HTTPS/SSL |
| **Tampering** | Integrity protection | ACLs, digital signatures, MACs, HTTPS/SSL |
| **Repudiation** | Logging/Auditing | Comprehensive logs, protected log storage, log over TCP/SSL |
| **Info Disclosure** | Confidentiality | Encryption (SSL, IPsec), ACLs, careful API design |
| **Denial of Service** | Availability | Elastic resources, rate limiting, quotas |
| **Elevation** | Authorization | Type-safe languages, sandboxing, input validation, prepared statements |

### Detailed Mitigation Techniques

**Addressing Spoofing:**
- Spoofing a person → Unique usernames + authentication (passwords, tokens, biometrics)
- Spoofing a file → Use full paths (not `./file`), check ACLs after opening
- Spoofing a network address → DNSSEC, SSL, IPsec
- Spoofing a program → Leverage OS application identifiers

**Addressing Tampering:**
- Tampering with a file → ACLs, digital signatures, keyed MACs
- Racing to create a file → Protected directories, private directory structures
- Tampering with network packets → HTTPS/SSL, IPsec
- Anti-pattern: Network isolation doesn't work long-term
  - "The isolated United States SIPRNet was thoroughly infested with malware, and the operation to clean it up took 14 months."

**Addressing Repudiation:**
- No logs → Log all security-relevant information
- Logs under attack → Send over network (TCP/SSL, not UDP), use ACLs
- Logs as attack channel → Tightly specify log format early in development

**Addressing Information Disclosure:**
- Network monitoring → Encryption (HTTPS/SSL, IPsec)
- Sensitive filenames → Create innocuous parent directory with ACLs
- File contents → ACLs or file/disk encryption
- APIs revealing info → Be selective about what you return

**Addressing Denial of Service:**
- Network flooding → Elastic resources, ensure attacker effort ≥ yours, network ACLs
- Program resources → Careful design, proof of work, require work before expensive operations
- System resources → Use OS quotas and limits

**Addressing Elevation of Privilege:**
- Data/code confusion → Prepared statements, clear separators, late validation
- Memory corruption → Type-safe languages, ASLR, sandboxes (AppArmor, AppContainer)
- Command injection → Validate input size and form; don't sanitize—log and discard weird input

**Key principles:**

> "Validate, don't sanitize. Know what you expect to see, how much you expect to see, and validate that that's what you're receiving. If you get something else, throw it away."

> "Trust the operating system. The OS provides security features so you can focus on your unique value proposition."

---

## 13. ⚠️ Taking It Too Far

### Over-modeling
Threat modeling every component of a well-understood framework wastes effort. Focus on your unique code and architecture, not commodity components.

### Paralysis by Analysis
Don't wait for the "complete" threat model. Start with what you know, iterate as you learn. An 80% threat model today beats a 100% model never delivered.

### Category Obsession
> "If you've already come up with the attack, why bother putting it in a category? The goal of STRIDE is to help you find attacks. Categorizing them might help you figure out the right defenses, or it may be a waste of effort."

If you find yourself debating whether "unauthorized database access" is spoofing or information disclosure, stop. Record the threat and move on. STRIDE is a finding tool, not a taxonomy.

### Security That Creates Insecurity

Shostack dedicates an entire chapter (Chapter 15) to human factors because cumbersome security creates its own vulnerabilities.

> "People are not, as is often claimed, the weakest link, or beyond help. The weakest link is almost always a vulnerability in Internet-facing code."

**The compliance budget:** Angela Sasse's research found that workers allocate a limited "budget" to security tasks. They spend time and energy until exhausted, then move on. Exceed the budget, and compliance drops.

> "People do listen. They don't act on security advice because it's often bizarre, time consuming, and sometimes followed by, 'Of course, you'll still be at risk.' You need to craft advice that works for the people who are listening to you."

**Warning fatigue:**
> "Given a choice between ignoring a warning that they've clicked through a thousand times before without apparent ill effects and without being entertained, people will bypass a warning every time."

**The fix:** Minimize what you ask of people. They should only be involved when they have information the system can't determine (e.g., "Is this a home or coffee shop network?").

> "You can also transfer risk to customers, for example, by asking them to click through lots of hard-to-understand dialogs before they can do the work they need to do. That's obviously not a great solution."

### Ignoring Easy Fixes
> "When there is an easy way to address a problem, you should skip strategizing and just address it."

> "The diagram is intended to help ensure that you understand and can discuss the system. Don't ask 'Is this the right way to do it?' Ask 'Does this help me think about what might go wrong?'"

### Letting Perfect Be the Enemy of Good
Start practicing now. You're not going to get good at threat modeling by reading—you have to do it.

> "You're not going to get to Carnegie Hall if you don't practice, practice, practice."

Pick a system you're working on and threat model it:
1. Draw a diagram
2. Use STRIDE to find threats
3. Address each threat in some way
4. Check your work with checklists
5. Celebrate and share your work

**What to threat model next:**
- What you're working on now (if it has trust boundaries)
- Something not too simple (trivial systems won't be satisfying)
- Something not too complex (don't chew off more than you can handle)
- Something you can collaborate on with trusted colleagues

**Starting small:** If you're working on a large team or across organizational boundaries, start with a component you own. Build your skills before tackling complex cross-team systems.

---

## 14. Worked Example: Login Flow

**Context:** Web application login endpoint

**Step 1: Draw the diagram**
```
[Browser] --(credentials)--> [Login Process] --(query)--> [User DB]
                                    |
                                    v
                             [Session Store]

Trust Boundary: -------- Internet --------
```

**Step 2: Apply STRIDE to Login Process**

| Threat | Question | Finding |
|--------|----------|---------|
| S | Can someone pretend to be a legitimate user? | Yes—stolen credentials, session hijacking |
| T | Can data be modified? | Yes—MITM attack on credentials |
| R | Can user deny actions? | Yes—if no session logging |
| I | Can credentials leak? | Yes—error messages, timing attacks |
| D | Can login be blocked? | Yes—flood attacks, account lockout abuse |
| E | Can attacker gain admin? | Yes—SQL injection in query |

**Step 3: Prioritize and mitigate**

| Threat | Priority | Mitigation |
|--------|----------|------------|
| Credential theft | High | HTTPS, MFA, session timeouts |
| SQL injection | High | Prepared statements |
| Session hijacking | High | Secure cookies, session binding |
| Account lockout abuse | Medium | Captcha, IP rate limiting |
| Credential timing | Low | Constant-time comparison |

**Step 4: Validate**
- Did we address every STRIDE threat for every element?
- Do we have tests for each mitigation?
- Is anything still concerning?

**Why this worked:**
- The diagram made the system concrete and discussable
- STRIDE provided systematic coverage (no guessing what to look for)
- Each threat got a specific mitigation (not "improve security generally")
- Tests will verify mitigations work

**What could go wrong with this threat model:**
- Missing trust boundaries (are there admin roles we didn't show?)
- Missing data flows (are there logs, metrics, or debugging interfaces?)
- Assumptions about network security (is HTTPS really used everywhere?)

---

## 15. Quick Reference

### The Four Questions
1. What are you building?
2. What can go wrong?
3. What should you do about it?
4. Did you do a decent job?

### STRIDE Threats

| Letter | Threat | Property | Defense |
|--------|--------|----------|---------|
| S | Spoofing | Authentication | Auth tokens, signatures |
| T | Tampering | Integrity | MACs, ACLs |
| R | Repudiation | Non-repudiation | Logging |
| I | Info Disclosure | Confidentiality | Encryption, ACLs |
| D | Denial of Service | Availability | Rate limits, quotas |
| E | Elevation | Authorization | Sandboxing, validation |

### STRIDE-per-Element Quick Check

| Element | Check For |
|---------|-----------|
| External Entity | S, R |
| Process | All (S, T, R, I, D, E) |
| Data Flow | T, I, D |
| Data Store | T, I, D (R for logs) |

### Threat Response Checklist

- [ ] Can we eliminate the feature?
- [ ] Can we mitigate with standard patterns?
- [ ] Is the risk acceptable? (Document why)
- [ ] Can we transfer to a trusted component?
- [ ] Is our mitigation testable?

### DFD Validation

- [ ] All trust boundaries marked
- [ ] All processes numbered
- [ ] No data moving without a process
- [ ] External entities identified
- [ ] Data stores labeled

### Validation Checklist

- [ ] Diagram tells a story without "sometimes" or "also"
- [ ] All trust boundaries, data flows, and stores visible
- [ ] STRIDE checked for each element
- [ ] Bug filed for each threat
- [ ] Test case per threat

---

## 16. Connection to Go Development Guide

| Shostack (Threat Modeling) | Go Development Guide |
|---------------------------|----------------------|
| Tampering with memory | Value semantics prevent unexpected mutation |
| Data/code confusion (EoP) | Type safety, prepared statements |
| Input validation | "Validate, don't sanitize" |
| Trust the OS | Use Go's standard library security features |
| Information disclosure | Careful API design, minimal return values |
| Denial of service | Bounded resources, context timeouts |

**Shared insight:** Both emphasize leveraging existing, trusted infrastructure rather than custom solutions.

**Why trust the OS:**
- The OS provides security features so you can focus on your unique value proposition
- The OS runs with privileges not available to your program or attacker
- If the attacker controls the OS, you're in a world of hurt anyway

STRIDE maps directly to defensive coding:
- **S → Authentication** handled by OS/framework, not custom code
- **T → Integrity** through immutability (value semantics)
- **I → Confidentiality** through minimal exposure (return only needed data)
- **E → Authorization** through type safety and sandboxing

**Example: Context timeouts and DoS:**

Go's `context.Context` with deadlines directly addresses denial-of-service threats:

```go
// Without timeout: vulnerable to slow clients
func handleRequest(r *Request) {
    result := expensiveOperation(r.Data)
    // ...
}

// With timeout: bounded resource consumption
func handleRequest(ctx context.Context, r *Request) error {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    result, err := expensiveOperationWithContext(ctx, r.Data)
    if err != nil {
        return err // context deadline exceeded = DoS mitigated
    }
    // ...
}
```

---

## 17. Glossary

| Term | Definition |
|------|------------|
| **Attack surface** | Trust boundary + direction of potential attack |
| **Attack tree** | Hierarchical decomposition of attack goals |
| **DFD** | Data Flow Diagram—visual model showing data movement |
| **STRIDE** | Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation |
| **Trust boundary** | Where more than one principal interacts |
| **Principal** | Entity that can take action (user, process, system) |
| **Mitigation** | Action that makes an attack harder |
| **Threat** | Potential violation of a security property |
| **Vulnerability** | Specific weakness that enables a threat |
| **CAPEC** | Common Attack Pattern Enumeration and Classification |
| **LINDDUN** | Privacy threat framework (STRIDE mirror for privacy) |
| **Elevation of Privilege** | Both a STRIDE threat and a card game for threat modeling |

---

## 18. Key Quotes

> "Threat modeling is the key to a focused defense. Without threat models, you can never stop playing whack-a-mole."

> "In short, threat modeling is the use of abstractions to aid in thinking about risks."

> "Your instincts are insufficient, and you'd need tools to help tackle the questions."

> "If you think about building a house, decisions you make early will have dramatic effects on security."

> "STRIDE is a tool to guide you to threats, not to ask you to categorize what you've found."

> "Validate, don't sanitize. Know what you expect to see... If you get something else, throw it away."

> "Trust the operating system. The OS provides security features so you can focus on your unique value proposition."

> "When there is an easy way to address a problem, you should skip strategizing and just address it."

> "Any technical professional can learn to threat model. Threat modeling involves the intersection of two models: a model of what can go wrong (threats), applied to a model of the software you're building."

> "With a whiteboard diagram and a copy of Elevation of Privilege, developers can threat model software that they're building, systems administrators can threat model software they're deploying, and security professionals can introduce threat modeling to those with skillsets outside of security."

> "The question 'what's your threat model?' is a great one because in just four words, it can slice through many conundrums to determine what you are worried about."
