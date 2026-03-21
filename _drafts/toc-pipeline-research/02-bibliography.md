# Bibliography

## Primary Theory

- Goldratt, Eliyahu. *The Goal* (1992). The Herbie story. Five Focusing Steps. DBR.
- Goldratt, Eliyahu. *Critical Chain* (1997). TOC for project scheduling. Resource contention. Buffer management.
- Tendon, Steve. *Hyper-Productive Knowledge Work* (TameFlow). Ch 12: Herbie and Kanban. Ch 18: DBR with visible replenishment signal.
- Tendon, Steve. *Standing on Bits* (2022). TOC + Agile for software at scale. Three constraint types: Work Flow, Work Process, Work Execution.

## Case Studies

- Forte Labs. [TOC 105-106: DBR at Microsoft XIT](https://fortelabs.com/blog/theory-of-constraints-105-drum-buffer-rope-at-microsoft/). Worst to best in 9 months. Constraint was management, not engineering.
- Dumitriu, Dragos. [From Worst to Best in 9 Months (PDF)](http://images.itrevolution.com/images/kanbans/From_Worst_to_Best_in_9_Months_Final_1_3-aw.pdf). The original paper.

## Production Implementations

- [OpenTelemetry Collector memorylimiterprocessor](https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/memorylimiterprocessor/README.md). Soft/hard memory limits. Drop + force GC. DBR without naming it.
- [bradenaw/backpressure](https://pkg.go.dev/github.com/bradenaw/backpressure). AdaptiveThrottle: TCP-style capacity learning. Closest Go analog to adaptive rope.
- [einride/pid-go](https://github.com/einride/pid-go). PID controller with anti-windup, derivative filter, feed-forward.
- [newcloudtechnologies/memlimiter](https://pkg.go.dev/github.com/newcloudtechnologies/memlimiter/backpressure). P-controller memory budget tracking.
- [KimMachineGun/automemlimit](https://github.com/KimMachineGun/automemlimit). cgroup-aware GOMEMLIMIT.

## Our Implementation

- [fluentfp/toc](https://github.com/binaryphile/fluentfp) -- toc package: Stage, Pipe, Start, Tee, Join, WeightedBatcher. Per-stage stats.
- [era](https://codeberg.org/binaryphile/era) -- the code indexer. Pipeline 1+2+3. Memory rope. Disk-backed buffer.

## Key Concepts for Precision

- **Constraint**: the resource currently limiting system throughput toward the goal. Not the symptom (OOM). Not the policy (concurrency limit). The resource.
- **Drum**: the constraint's achievable pace. Other stations subordinate to it.
- **Buffer**: work placed IN FRONT OF the constraint. Protects constraint utilization from upstream variability. Lost constraint time = lost system throughput forever.
- **Rope**: admission control at the system's release point, sized to the constraint. Prevents overproduction. Software engineers call this backpressure -- rope implies drum, which is the key difference.
- **Throughput**: completed useful output, not local stage speed. OOM = zero throughput.
- **Inventory (WIP)**: in-flight work between release and completion. Consumes resources (memory) without producing throughput.
- **Operating Expense**: CPU, RAM, disk, engineering complexity.
