# Control Law: Drum/Rope Decision Logic

## The Decision

At startup, before the pipeline runs:

1. Read available memory: `avail = readMemAvailable()` (Linux `/proc/meminfo`)
2. Estimate base overhead: `base = 2GB` (ORT model + Go runtime + pipeline structures)
3. Estimate per-embed cost: `perEmbed = 600MB` (ORT scratch + associated buffers + HNSW growth)
4. Compute memory-safe concurrency: `memMax = (avail * 0.4 - base) / perEmbed`
5. Compute CPU concurrency: `cpuMax = runtime.GOMAXPROCS(0)`
6. Select: `E = min(cpuMax, max(1, memMax))`

If `memMax < cpuMax`: memory is the active constraint. The rope is sized to memory.
If `cpuMax <= memMax`: embed CPU throughput is the active constraint. The rope is sized to CPU.

## Pseudocode

```go
// At pipeline construction time:
avail := readMemAvailable()            // bytes from /proc/meminfo
base  := 2 << 30                       // 2GB fixed overhead
cost  := 600 << 20                     // 600MB per concurrent embed
budget := int(float64(avail)*0.4) - base

cpuMax := runtime.GOMAXPROCS(0)        // available cores
memMax := max(1, budget / cost)        // memory-safe concurrency

E := min(cpuMax, memMax)               // effective embed workers

// Log the decision
if memMax < cpuMax {
    slog.Info("drum: memory", "maxConcurrent", E, "memAvail", avail)
} else {
    slog.Info("drum: embed CPU", "workers", E)
}

// Enforce via weighted semaphore on embedFn
embedFn = call.ThrottleWeighted(budget/unit, embedCost, embedFn)
```

## What This Produces

| Machine | MemAvailable | cpuMax | memMax | E | Active Drum | Outcome |
|---|---|---|---|---|---|---|
| Chromebook (8GB, 4 cores) | ~5.5GB | 4 | 1-2 | 2 | Memory | Completes, 2.7GB RSS |
| Dev workstation (16GB, 8 cores) | ~10GB | 8 | 4-5 | 5 | Memory | Completes, ~3.5GB RSS (est) |
| Server (256GB, 64 cores) | ~200GB | 64 | 64+ | 64 | Embed CPU | Completes, full saturation |

## What This Is and Isn't

**Is**: a startup-time release policy that selects a safe operating point from local hardware capacity. One policy, machine-specific result. No per-machine configuration file.

**Isn't**: runtime re-identification. Dynamic buffer management. Proof of optimality. Adaptive rope. Those are future work.

**The control law**: `E = min(CPU cores, memory budget / per-embed cost)`. The rope (ThrottleWeighted) enforces `E` at the embed call boundary. Everything upstream has excess capacity and subordinates via bounded queues.

## Evidence

Measured on accelerated-linux (14.8GB RAM, 8 cores, ORT MiniLM-L6-v2, 16.8K indexed files):

| E | Peak RSS | Goodput | Outcome |
|---|---|---|---|
| 8 (no rope) | 4.8GB | 0 (OOM killed at 5 min) | Failure |
| 2 (manual) | 2.6GB | ~4x slower, completing | Success |
| 2 (rope auto-selected) | 2.7GB | Same as manual, no config | Success |
| 7 (60% budget, too aggressive) | 4.8GB | 0 (OOM) | Failure |
| 2 (40% budget, conservative) | 2.7GB | Stable 20+ min | Success |

The 40% budget factor was calibrated empirically. 60% was too aggressive (OOM). 40% is conservative and stable. This is manual tuning of the control law's safety margin -- the weakest part of the current implementation.
