# Mistake #28: Maps and memory leaks

#### TL;DR

A map can always grow in memory, but it never shrinks. Hence, if it leads to some memory issues, you can try different options, such as forcing Go to recreate the map or using pointers.

Read the full section here.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/28-map-memory-leak/main.go)
