# Mistake #99: Not understanding how the GC works

#### TL;DR

Understanding the Go garbage collector helps write more efficient applications. The GC uses a concurrent, tri-color mark-and-sweep algorithm. Reducing heap allocations and understanding the `GOGC` tuning parameter are key.

Go uses a concurrent garbage collector based on the tri-color mark-and-sweep algorithm. Understanding how it works helps write performance-sensitive applications:

* **Mark phase**: The GC traverses the object graph starting from roots (stacks, globals) and marks all reachable objects.
* **Sweep phase**: Unreachable objects are freed.
* The GC runs concurrently with the application, minimizing stop-the-world pauses.

Key tuning parameters:
* `GOGC` (default 100): Controls the GC target percentage. A value of 100 means the GC triggers when heap size doubles since the last collection. Lower values trigger more frequent GC (less memory, more CPU); higher values trigger less frequent GC (more memory, less CPU).
* `GOMEMLIMIT` (Go 1.19+): Sets a soft memory limit for the Go runtime, helping prevent OOM situations.

To optimize GC performance:
* Reduce heap allocations (see mistake #96).
* Use value types instead of pointer types where possible.
* Pre-allocate slices and maps when the size is known.
* Consider `sync.Pool` for frequently allocated objects.
