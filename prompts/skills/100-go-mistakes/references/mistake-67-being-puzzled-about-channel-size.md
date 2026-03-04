# Mistake #67: Being puzzled about channel size

#### TL;DR

Carefully decide on the right channel type to use, given a problem. Only unbuffered channels provide strong synchronization guarantees. For buffered channels, you should have a good reason to specify a channel size other than one.

An unbuffered channel is a channel without any capacity. It can be created by either omitting the size or providing a 0 size:

ch1 := make(chan int)
ch2 := make(chan int, 0)

With an unbuffered channel (sometimes called a synchronous channel), the sender will block until the receiver receives data from the channel.

Conversely, a buffered channel has a capacity, and it must be created with a size greater than or equal to 1:

ch3 := make(chan int, 1)

With a buffered channel, a sender can send messages while the channel isn’t full. Once the channel is full, it will block until a receiver goroutine receives a message:

ch3 := make(chan int, 1)
ch3 <-1 // Non-blocking
ch3 <-2 // Blocking

The first send isn’t blocking, whereas the second one is, as the channel is full at this stage.

What's the main difference between unbuffered and buffered channels:

* An unbuffered channel enables synchronization. We have the guarantee that two goroutines will be in a known state: one receiving and another sending a message.
* A buffered channel doesn’t provide any strong synchronization. Indeed, a producer goroutine can send a message and then continue its execution if the channel isn’t full. The only guarantee is that a goroutine won’t receive a message before it is sent. But this is only a guarantee because of causality (you don’t drink your coffee before you prepare it).

If we need a buffered channel, what size should we provide?

The default value we should use for buffered channels is its minimum: 1. So, we may approach the problem from this standpoint: is there any good reason not to use a value of 1? Here’s a list of possible cases where we should use another size:

* While using a worker pooling-like pattern, meaning spinning a fixed number of goroutines that need to send data to a shared channel. In that case, we can tie the channel size to the number of goroutines created.
* When using channels for rate-limiting problems. For example, if we need to enforce resource utilization by bounding the number of requests, we should set up the channel size according to the limit.

If we are outside of these cases, using a different channel size should be done cautiously. Let’s bear in mind that deciding about an accurate queue size isn’t an easy problem:

Martin Thompson

Queues are typically always close to full or close to empty due to the differences in pace between consumers and producers. They very rarely operate in a balanced middle ground where the rate of production and consumption is evenly matched.
