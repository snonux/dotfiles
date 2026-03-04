# Mistake #72: Forgetting about sync.Cond

#### TL;DR

Use `sync.Cond` to send notifications to multiple goroutines. It provides `Signal` (wake one goroutine) and `Broadcast` (wake all waiting goroutines), which can be more efficient than channel-based alternatives when broadcasting.

`sync.Cond` is a condition variable implementation that can be used to coordinate goroutines waiting for or announcing the occurrence of an event. It's useful in scenarios where multiple goroutines need to wait for some shared state to change. Instead of busy-waiting or using channels with limitations, `sync.Cond` provides an efficient mechanism.

Key methods:
* `Wait()` — Suspends the calling goroutine, releasing the lock, and resumes when signaled.
* `Signal()` — Wakes one goroutine waiting on the condition.
* `Broadcast()` — Wakes all goroutines waiting on the condition.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/72-cond/main.go)
