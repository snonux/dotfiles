# Mistake #26: Slices and memory leaks

#### TL;DR
TL;DR

Working with a slice of pointers or structs with pointer fields, you can avoid memory leaks by marking as nil the elements excluded by a slicing operation.

Leaking capacity

Remember that slicing a large slice or array can lead to potential high memory consumption. The remaining space won’t be reclaimed by the GC, and we can keep a large backing array despite using only a few elements. Using a slice copy is the solution to prevent such a case.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/26-slice-memory-leak/capacity-leak)

Slice and pointers

When we use the slicing operation with pointers or structs with pointer fields, we need to know that the GC won’t reclaim these elements. In that case, the two options are to either perform a copy or explicitly mark the remaining elements or their fields to `nil`.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/26-slice-memory-leak/slice-pointers)
