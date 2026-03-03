# Mistake #65: Not using notification channels

#### TL;DR
TL;DR

Send notifications using a `chan struct{}` type.

Channels are a mechanism for communicating across goroutines via signaling. A signal can be either with or without data.

Let’s look at a concrete example. We will create a channel that will notify us whenever a certain disconnection occurs. One idea is to handle it as a `chan bool`:

disconnectCh := make(chan bool)

Now, let’s say we interact with an API that provides us with such a channel. Because it’s a channel of Booleans, we can receive either `true` or `false` messages. It’s probably clear what `true` conveys. But what does `false` mean? Does it mean we haven’t been disconnected? And in this case, how frequently will we receive such a signal? Does it mean we have reconnected? Should we even expect to receive `false`? Perhaps we should only expect to receive `true` messages.

If that’s the case, meaning we don’t need a specific value to convey some information, we need a channel without data. The idiomatic way to handle it is a channel of empty structs: `chan struct{}`.
