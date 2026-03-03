# Mistake #62: Starting a goroutine without knowing when to stop it

#### TL;DR
TL;DR

Avoiding leaks means being mindful that whenever a goroutine is started, you should have a plan to stop it eventually.

Goroutines are easy and cheap to start—so easy and cheap that we may not necessarily have a plan for when to stop a new goroutine, which can lead to leaks. Not knowing when to stop a goroutine is a design issue and a common concurrency mistake in Go.

Let’s discuss a concrete example. We will design an application that needs to watch some external configuration (for example, using a database connection). Here’s a first implementation:

func main() {
    newWatcher()
    // Run the application
}

type watcher struct { /* Some resources */ }

func newWatcher() {
    w := watcher{}
    go w.watch() // Creates a goroutine that watches some external configuration
}

The problem with this code is that when the main goroutine exits (perhaps because of an OS signal or because it has a finite workload), the application is stopped. Hence, the resources created by watcher aren’t closed gracefully. How can we prevent this from happening?

One option could be to pass to newWatcher a context that will be canceled when main returns:

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    newWatcher(ctx)
    // Run the application
}

func newWatcher(ctx context.Context) {
    w := watcher{}
    go w.watch(ctx)
}

We propagate the context created to the watch method. When the context is canceled, the watcher struct should close its resources. However, can we guarantee that watch will have time to do so? Absolutely not—and that’s a design flaw.

The problem is that we used signaling to convey that a goroutine had to be stopped. We didn’t block the parent goroutine until the resources had been closed.  Let’s make sure we do:

func main() {
    w := newWatcher()
    defer w.close()
    // Run the application
}

func newWatcher() watcher {
    w := watcher{}
    go w.watch()
    return w
}

func (w watcher) close() {
    // Close the resources
}

Instead of signaling `watcher` that it’s time to close its resources, we now call this `close` method, using `defer` to guarantee that the resources are closed before the application exits.

In summary, let’s be mindful that a goroutine is a resource like any other that must eventually be closed to free memory or other resources. Starting a goroutine without knowing when to stop it is a design issue. Whenever a goroutine is started, we should have a clear plan about when it will stop. Last but not least, if a goroutine creates resources and its lifetime is bound to the lifetime of the application, it’s probably safer to wait for this goroutine to complete before exiting the application. This way, we can ensure that the resources can be freed.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/62-starting-goroutine/)
