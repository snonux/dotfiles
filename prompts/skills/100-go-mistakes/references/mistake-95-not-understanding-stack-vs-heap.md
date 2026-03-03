# Mistake #95: Not understanding stack vs. heap

#### TL;DR
TL;DR

Understanding the fundamental differences between heap and stack should also be part of your core knowledge when optimizing a Go application. Stack allocations are almost free, whereas heap allocations are slower and rely on the GC to clean the memory.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/95-stack-heap/)
