# Mistake #30: Ignoring that elements are copied in range loops


The value element in a range loop is a copy. Therefore, to mutate a struct, use the index to access it directly or use a classic for loop with pointers.

A range loop allows iterating over different data structures: String, Array, Pointer to an array, Slice, Map, Receiving channel.

Compared to a classic for loop, a range loop is a convenient way to iterate over all the elements of one of these data structures, thanks to its concise syntax.

Yet, we should remember that the value element in a range loop is a copy. Therefore, if the value is a struct we need to mutate, we will only update the copy, not the element itself, unless the value or field we modify is a pointer. The favored options are to access the element via the index using a range loop or a classic for loop.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/30-range-loop-element-copied/)
