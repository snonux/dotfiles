# Mistake #89: Writing inaccurate benchmarks


Regarding benchmarks:

* Use time methods to preserve the accuracy of a benchmark.
* Increasing benchtime or using tools such as benchstat can be helpful when dealing with micro-benchmarks.
* Be careful with the results of a micro-benchmark if the system that ends up running the application is different from the one running the micro-benchmark.
* Make sure the function under test leads to a side effect, to prevent compiler optimizations from fooling you about the benchmark results.
* To prevent the observer effect, force a benchmark to re-create the data used by a CPU-bound function.

Read the full section here.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/89-benchmark/)
