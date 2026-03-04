# Mistake #71: Misusing sync.WaitGroup


Call `wg.Add` before spinning up goroutines, not inside them. Calling `Add` inside a goroutine introduces a race with `Wait`.

In the following example, `wg.Add(1)` is called within the newly created goroutine, not in the parent goroutine:

    wg := sync.WaitGroup{}
    var v uint64
    for i := 0; i < 3; i++ {
        go func() {
            wg.Add(1)
            atomic.AddUint64(&v, 1)
            wg.Done()
        }()
    }
    wg.Wait()
    fmt.Println(v)

If we run this example, we get a non-deterministic value (0 to 3) and a data race. The problem is that there is no guarantee that we have indicated to the wait group that we want to wait for three goroutines before calling `wg.Wait()`.

To fix this, call `wg.Add` before the loop or inside the loop but not in the goroutine:

    wg := sync.WaitGroup{}
    var v uint64
    wg.Add(3)
    for i := 0; i < 3; i++ {
        go func() {
            atomic.AddUint64(&v, 1)
            wg.Done()
        }()
    }
    wg.Wait()
    fmt.Println(v)

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/71-wait-group/main.go)
