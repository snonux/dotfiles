# Mistake #69: Creating data races with append

#### TL;DR
TL;DR

Calling `append` isn’t always data-race-free; hence, it shouldn’t be used concurrently on a shared slice.

Should adding an element to a slice using `append` is data-race-free? Spoiler: it depends.

Do you believe this example has a data race? 

s := make([]int, 1)

go func() { // In a new goroutine, appends a new element on s
    s1 := append(s, 1)
    fmt.Println(s1)
}()

go func() { // Same
    s2 := append(s, 1)
    fmt.Println(s2)
}()

The answer is no.

In this example, we create a slice with `make([]int, 1)`. The code creates a one-length, one-capacity slice. Thus, because the slice is full, using append in each goroutine returns a slice backed by a new array. It doesn’t mutate the existing array; hence, it doesn’t lead to a data race.

Now, let’s run the same example with a slight change in how we initialize `s`. Instead of creating a slice with a length of 1, we create it with a length of 0 but a capacity of 1. How about this new example? Does it contain a data race?

s := make([]int, 0, 1)

go func() { 
    s1 := append(s, 1)
    fmt.Println(s1)
}()

go func() {
    s2 := append(s, 1)
    fmt.Println(s2)
}()

The answer is yes. We create a slice with `make([]int, 0, 1)`. Therefore, the array isn’t full. Both goroutines attempt to update the same index of the backing array (index 1), which is a data race.

How can we prevent the data race if we want both goroutines to work on a slice containing the initial elements of `s` plus an extra element? One solution is to create a copy of `s`.

We should remember that using append on a shared slice in concurrent applications can lead to a data race. Hence, it should be avoided.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/69-data-race-append/main.go)
