# Mistake #73: Not using errgroup


Use `errgroup` to synchronize a group of goroutines and handle errors, as well as shared context cancellation. It simplifies patterns involving multiple concurrent operations that can fail.

The `golang.org/x/sync/errgroup` package provides a convenient way to synchronize a group of goroutines working on subtasks of a common task. Compared to using a plain `sync.WaitGroup`, `errgroup` adds:

* Error propagation — the first non-nil error returned by any goroutine is captured and returned by `Wait()`.
* Context cancellation — using `errgroup.WithContext`, a shared context is canceled when any goroutine returns an error, allowing other goroutines to stop early.
* Concurrency limiting — `SetLimit` allows controlling the maximum number of goroutines running simultaneously.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/73-errgroup/main.go)
