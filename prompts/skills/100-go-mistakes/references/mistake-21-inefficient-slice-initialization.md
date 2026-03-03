# Mistake #21: Inefficient slice initialization

#### TL;DR
TL;DR

When creating a slice, initialize it with a given length or capacity if its length is already known. This reduces the number of allocations and improves performance.

While initializing a slice using `make`, we can provide a length and an optional capacity. Forgetting to pass an appropriate value for both of these parameters when it makes sense is a widespread mistake. Indeed, it can lead to multiple copies and additional effort for the GC to clean the temporary backing arrays. Performance-wise, there’s no good reason not to give the Go runtime a helping hand.

Our options are to allocate a slice with either a given capacity or a given length. Of these two solutions, we have seen that the second tends to be slightly faster. But using a given capacity and append can be easier to implement and read in some contexts.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/21-slice-init/main.go)
