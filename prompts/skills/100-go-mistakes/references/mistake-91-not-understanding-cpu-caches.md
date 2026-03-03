# Mistake #91: Not understanding CPU caches

* CPU architecture

Understanding how to use CPU caches is important for optimizing CPU-bound applications because the L1 cache is about 50 to 100 times faster than the main memory.

* Cache line

Being conscious of the cache line concept is critical to understanding how to organize data in data-intensive applications. A CPU doesn’t fetch memory word by word; instead, it usually copies a memory block to a 64-byte cache line. To get the most out of each individual cache line, enforce spatial locality.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/91-cpu-caches/cache-line/)

* Slice of structs vs. struct of slices

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/91-cpu-caches/slice-structs/)

* Predictability

Making code predictable for the CPU can also be an efficient way to optimize certain functions. For example, a unit or constant stride is predictable for the CPU, but a non-unit stride (for example, a linked list) isn’t predictable.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/91-cpu-caches/predictability/)

* Cache placement policy

To avoid a critical stride, hence utilizing only a tiny portion of the cache, be aware that caches are partitioned.
