# Mistake #59: Not understanding the concurrency impacts of a workload type

#### TL;DR

When creating a certain number of goroutines, consider the workload type. Creating CPU-bound goroutines means bounding this number close to the GOMAXPROCS variable (based by default on the number of CPU cores on the host). Creating I/O-bound goroutines depends on other factors, such as the external system.

In programming, the execution time of a workload is limited by one of the following:

* The speed of the CPU—For example, running a merge sort algorithm. The workload is called CPU-bound.
* The speed of I/O—For example, making a REST call or a database query. The workload is called I/O-bound.
* The amount of available memory—The workload is called memory-bound.

#### TL;DR
Note

The last is the rarest nowadays, given that memory has become very cheap in recent decades. Hence, this section focuses on the two first workload types: CPU- and I/O-bound.

If the workload executed by the workers is I/O-bound, the value mainly depends on the external system. Conversely, if the workload is CPU-bound, the optimal number of goroutines is close to the number of available CPU cores (a best practice can be to use `runtime.GOMAXPROCS`). Knowing the workload type (I/O or CPU) is crucial when designing concurrent applications.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/08-concurrency-foundations/59-workload-type/main.go)
