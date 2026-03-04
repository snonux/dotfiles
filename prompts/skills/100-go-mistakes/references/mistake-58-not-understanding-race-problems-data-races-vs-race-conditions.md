# Mistake #58: Not understanding race problems (data races vs. race conditions and the Go memory model)

#### TL;DR

Being proficient in concurrency also means understanding that data races and race conditions are different concepts. Data races occur when multiple goroutines simultaneously access the same memory location and at least one of them is writing. Meanwhile, being data-race-free doesn’t necessarily mean deterministic execution. When a behavior depends on the sequence or the timing of events that can’t be controlled, this is a race condition.

Race problems can be among the hardest and most insidious bugs a programmer can face. As Go developers, we must understand crucial aspects such as data races and race conditions, their possible impacts, and how to avoid them.

Data Race

A data race occurs when two or more goroutines simultaneously access the same memory location and at least one is writing. In this case, the result can be hazardous. Even worse, in some situations, the memory location may end up holding a value containing a meaningless combination of bits.

We can prevent a data race from happening using different techniques. For example: 

* Using the `sync/atomic` package
* In synchronizing the two goroutines with an ad hoc data structure like a mutex
* Using channels to make the two goroutines communicating to ensure that a variable is updated by only one goroutine at a time

Race Condition

Depending on the operation we want to perform, does a data-race-free application necessarily mean a deterministic result? Not necessarily.

A race condition occurs when the behavior depends on the sequence or the timing of events that can’t be controlled. Here, the timing of events is the goroutines’ execution order.

In summary, when we work in concurrent applications, it’s essential to understand that a data race is different from a race condition. A data race occurs when multiple goroutines simultaneously access the same memory location and at least one of them is writing. A data race means unexpected behavior. However, a data-race-free application doesn’t necessarily mean deterministic results. An application can be free of data races but still have behavior that depends on uncontrolled events (such as goroutine execution, how fast a message is published to a channel, or how long a call to a database lasts); this is a race condition. Understanding both concepts is crucial to becoming proficient in designing concurrent applications.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/08-concurrency-foundations/58-races/)
