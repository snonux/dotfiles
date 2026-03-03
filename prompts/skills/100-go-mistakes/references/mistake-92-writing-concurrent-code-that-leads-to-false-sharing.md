# Mistake #92: Writing concurrent code that leads to false sharing

#### TL;DR
TL;DR

Knowing that lower levels of CPU caches aren’t shared across all the cores helps avoid performance-degrading patterns such as false sharing while writing concurrency code. Sharing memory is an illusion.

Read the full section here.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/92-false-sharing/)
