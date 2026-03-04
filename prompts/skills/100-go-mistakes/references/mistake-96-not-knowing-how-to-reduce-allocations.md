# Mistake #96: Not knowing how to reduce allocations


Reducing allocations improves performance by decreasing GC pressure. Techniques include API changes to accept pre-allocated buffers, leveraging compiler optimizations, and using `sync.Pool` for reusable objects.

Reducing the number of heap allocations is one of the most effective ways to improve Go application performance. Each allocation adds pressure on the garbage collector.

Key techniques:
* **API changes**: Design functions to accept pre-allocated slices or buffers rather than always creating new ones. For example, `io.Reader.Read(p []byte)` lets the caller control the allocation.
* **Compiler optimizations**: Be aware that the compiler can sometimes optimize away allocations (e.g., inlining small functions). Use `go build -gcflags="-m"` to see escape analysis decisions.
* **sync.Pool**: Use `sync.Pool` for frequently allocated and deallocated objects. The pool maintains a set of temporary objects that can be reused, reducing allocation overhead. Note that pooled objects can be reclaimed by the GC at any time.

    var pool = sync.Pool{
        New: func() any {
            return make([]byte, 1024)
        },
    }

    buf := pool.Get().([]byte)
    defer pool.Put(buf)

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/96-reduce-allocations/)
