# Mistake #27: Inefficient map initialization

#### TL;DR

When creating a map, initialize it with a given length if its length is already known. This reduces the number of allocations and improves performance.

A map provides an unordered collection of key-value pairs in which all the keys are distinct. In Go, a map is based on the hash table data structure. Internally, a hash table is an array of buckets, and each bucket is a pointer to an array of key-value pairs.

If we know up front the number of elements a map will contain, we should create it by providing an initial size. Doing this avoids potential map growth, which is quite heavy computation-wise because it requires reallocating enough space and rebalancing all the elements.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/27-map-init/main_test.go)
