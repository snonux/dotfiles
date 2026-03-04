# Mistake #66: Not using nil channels


Using nil channels should be part of your concurrency toolset because it allows you to remove cases from `select` statements, for example.

What should this code do?

var ch chan int
<-ch

`ch` is a `chan int` type. The zero value of a channel being nil, `ch` is `nil`. The goroutine won’t panic; however, it will block forever.

The principle is the same if we send a message to a nil channel. This goroutine blocks forever:

var ch chan int
ch <- 0

Then what’s the purpose of Go allowing messages to be received from or sent to a nil channel? For example, we can use nil channels to implement an idiomatic way to merge two channels:

func merge(ch1, ch2 <-chan int) <-chan int {
    ch := make(chan int, 1)

    go func() {
        for ch1 != nil || ch2 != nil { // Continue if at least one channel isn’t nil
            select {
            case v, open := <-ch1:
                if !open {
                    ch1 = nil // Assign ch1 to a nil channel once closed
                    break
                }
                ch <- v
            case v, open := <-ch2:
                if !open {
                    ch2 = nil // Assigns ch2 to a nil channel once closed
                    break
                }
                ch <- v
            }
        }
        close(ch)
    }()

    return ch
}

This elegant solution relies on nil channels to somehow remove one case from the `select` statement.

Let’s keep this idea in mind: nil channels are useful in some conditions and should be part of the Go developer’s toolset when dealing with concurrent code.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/66-nil-channels/main.go)
