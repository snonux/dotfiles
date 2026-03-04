# Mistake #74: Copying a sync type


Types from the `sync` package should never be copied. This applies to `sync.Mutex`, `sync.WaitGroup`, `sync.Cond`, and the other types. Use pointers to share them.

The `sync` package types (`Mutex`, `RWMutex`, `WaitGroup`, `Cond`, `Map`, `Pool`, `Once`) should never be copied after first use. Copying a mutex, for example, duplicates its internal state, which can lead to deadlocks or data races. This includes:

* Passing a sync type by value to a function
* Assigning a struct containing a sync type to another variable
* Returning a struct containing a sync type by value

Use the `go vet` tool to detect accidental copies of sync types. Always pass sync types by pointer when they need to be shared.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/74-copying-sync/main.go)
