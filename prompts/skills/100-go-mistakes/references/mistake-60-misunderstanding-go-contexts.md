# Mistake #60: Misunderstanding Go contexts


Go contexts are also one of the cornerstones of concurrency in Go. A context allows you to carry a deadline, a cancellation signal, and/or a list of keys-values.

https://pkg.go.dev/context

A Context carries a deadline, a cancellation signal, and other values across API boundaries.

Deadline

A deadline refers to a specific point in time determined with one of the following:

* A `time.Duration` from now (for example, in 250 ms)
* A `time.Time` (for example, 2023-02-07 00:00:00 UTC)

The semantics of a deadline convey that an ongoing activity should be stopped if this deadline is met. An activity is, for example, an I/O request or a goroutine waiting to receive a message from a channel.

Cancellation signals

Another use case for Go contexts is to carry a cancellation signal. Let’s imagine that we want to create an application that calls `CreateFileWatcher(ctx context.Context, filename string)` within another goroutine. This function creates a specific file watcher that keeps reading from a file and catches updates. When the provided context expires or is canceled, this function handles it to close the file descriptor.

Context values

The last use case for Go contexts is to carry a key-value list. What’s the point of having a context carrying a key-value list? Because Go contexts are generic and mainstream, there are infinite use cases.

For example, if we use tracing, we may want different subfunctions to share the same correlation ID. Some developers may consider this ID too invasive to be part of the function signature. In this regard, we could also decide to include it as part of the provided context.

Catching a context cancellation

The `context.Context` type exports a `Done` method that returns a receive-only notification channel: `<-chan struct{}`. This channel is closed when the work associated with the context should be canceled. For example,

* The Done channel related to a context created with `context.WithCancel` is closed when the cancel function is called.
* The Done channel related to a context created with `context.WithDeadline` is closed when the deadline has expired.

One thing to note is that the internal channel should be closed when a context is canceled or has met a deadline, instead of when it receives a specific value, because the closure of a channel is the only channel action that all the consumer goroutines will receive. This way, all the consumers will be notified once a context is canceled or a deadline is reached.

In summary, to be a proficient Go developer, we have to understand what a context is and how to use it. In general, a function that users wait for should take a context, as doing so allows upstream callers to decide when calling this function should be aborted. 

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/08-concurrency-foundations/60-contexts/main.go)
