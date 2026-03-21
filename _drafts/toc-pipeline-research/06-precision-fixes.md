# Precision Fixes from Final /g Review (B)

## Vocabulary Tightening

| Sloppy | Precise |
|---|---|
| "memory is THE constraint" | "after CPU was elevated, safe resident memory became the active system constraint" |
| "OOM is the limiter" | "OOM revealed we were exceeding the memory-constrained WIP limit" |
| "same code, any machine" | "same control policy, machine-specific operating point" |
| "optimal goodput" | "better stable goodput without hand-tuning" |
| "buffer and rope are conflated" | "our implementation collapses two conceptually distinct DBR roles into one control mechanism" |
| "the model works as-is" | "the TOC model did not need extension; our implementation needed to catch up with it" |

## Required Additions

1. **Define goal and system boundary early.** System: document ingestion through chunking, embedding, persistence. Goal: maximize stable completed embeddings per hour on fixed hardware. T = successful completed items/hr. I = queued chunks, in-flight docs, resident tensors. OE = CPU, RAM, disk, retries, ops toil. Note: Goldratt's T is money through sales; ours is engineering throughput.

2. **OOM is symptom, not constraint.** The constraint is available resident memory. OOM is what happens when release policy violates it.

3. **Policy vs physical constraint.** The machine had a memory limit (physical). Our release policy ignored it (policy). The intervention was subordinating release to the physical limit. Both are real; naming them separately is sharper.

4. **What the drum is at each phase.** Before ORT: embed stage CPU service rate. After ORT: memory-limited admission rate (how many concurrent embeds fit in RAM).

5. **Assumptions under which the model works.** Single dominant constraint per workload phase. Mostly linear pipeline. Work cost estimable. Machine reasonably dedicated. Startup memory representative or conservative.

6. **Container/cgroup caveat.** readMemAvailable() is Linux-only, doesn't respect cgroup limits by default. One paragraph.

7. **Goodput defined.** Successful completed items per unit time, excluding retries/crashes. OOM = zero goodput. This is why the memory constraint matters even though the pipeline is "fast."

## Section-Specific Fixes

### "Same Binary, Any Machine" -> "One Policy, Machine-Specific Operating Points"

Reduce claim. What we have: startup environment sensing + static concurrency sizing. What we DON'T have: runtime re-identification, dynamic buffer management, proof of optimality. Honest claim: "a safe near-saturation starting point without manual tuning, portable across hardware classes."

### Five Steps Applied to Memory

Tighten step labels:
- Exploit = reduce waste IN the constrained resource (free temps, stream instead of materialize, reuse buffers). Disk-backed buffer is exploit if it reduces resident pressure; subordination if it controls WIP.
- Subordinate = pace release so total in-flight stays within safe memory headroom. ThrottleWeighted belongs here.
- Elevate = add capacity or fundamentally change the resource (more RAM, lighter model).

### Buffer Management

We don't have real buffer management (green/yellow/red zones, penetration monitoring). Say so. What we have: fixed capacity. What we'd want: adaptive buffer sizing based on upstream variability and constraint throughput rate. That's future work and the post should be honest about the gap.
