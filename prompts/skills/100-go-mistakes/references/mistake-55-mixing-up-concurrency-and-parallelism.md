# Mistake #55: Mixing up concurrency and parallelism

#### TL;DR
TL;DR

Understanding the fundamental differences between concurrency and parallelism is a cornerstone of the Go developer’s knowledge. Concurrency is about structure, whereas parallelism is about execution.

Concurrency and parallelism are not the same:

* Concurrency is about structure. We can change a sequential implementation into a concurrent one by introducing different steps that separate concurrent goroutines can tackle.
* Meanwhile, parallelism is about execution. We can use parallism at the steps level by adding more parallel goroutines.

In summary, concurrency provides a structure to solve a problem with parts that may be parallelized. Therefore, concurrency enables parallelism.
