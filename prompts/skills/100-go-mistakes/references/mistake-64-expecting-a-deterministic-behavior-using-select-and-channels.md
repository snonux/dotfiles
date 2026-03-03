# Mistake #64: Expecting a deterministic behavior using select and channels

#### TL;DR
TL;DR

Understanding that `select` with multiple channels chooses the case randomly if multiple options are possible prevents making wrong assumptions that can lead to subtle concurrency bugs.

One common mistake made by Go developers while working with channels is to make wrong assumptions about how select behaves with multiple channels.

For example, let's consider the following case (`disconnectCh` is a unbuffered channel):

go func() {
  for i := 0; i &lt; 10; i++ {
      messageCh &lt;- i
    }
    disconnectCh &lt;- struct{}{}
}()

for {
    select {
    case v := &lt;-messageCh:
        fmt.Println(v)
    case &lt;-disconnectCh:
        fmt.Println("disconnection, return")
        return
    }
}

If we run this example multiple times, the result will be random:

0
1
2
disconnection, return

0
disconnection, return

Instead of consuming the 10 messages, we only received a few of them. What’s the reason? It lies in the specification of the select statement with multiple channels (https:// go.dev/ref/spec):

Quote

If one or more of the communications can proceed, a single one that can proceed is chosen via a uniform pseudo-random selection.

Unlike a switch statement, where the first case with a match wins, the select statement selects randomly if multiple options are possible.

This behavior might look odd at first, but there’s a good reason for it: to prevent possible starvation. Suppose the first possible communication chosen is based on the source order. In that case, we may fall into a situation where, for example, we only receive from one channel because of a fast sender. To prevent this, the language designers decided to use a random selection.

When using `select` with multiple channels, we must remember that if multiple options are possible, the first case in the source order does not automatically win. Instead, Go selects randomly, so there’s no guarantee about which option will be chosen. To overcome this behavior, in the case of a single producer goroutine, we can use either unbuffered channels or a single channel.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/64-select-behavior/main.go)
