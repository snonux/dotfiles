# Mistake #42: Not knowing which type of receiver to use


The decision whether to use a value or a pointer receiver should be made based on factors such as the type, whether it has to be mutated, whether it contains a field that can’t be copied, and how large the object is. When in doubt, use a pointer receiver.

Choosing between value and pointer receivers isn’t always straightforward. Let’s discuss some of the conditions to help us choose.

A receiver must be a pointer

* If the method needs to mutate the receiver. This rule is also valid if the receiver is a slice and a method needs to append elements:

type slice []int

func (s *slice) add(element int) {
    *s = append(*s, element)
}

* If the method receiver contains a field that cannot be copied: for example, a type part of the sync package (see #74, “Copying a sync type”).

A receiver should be a pointer

* If the receiver is a large object. Using a pointer can make the call more efficient, as doing so prevents making an extensive copy. When in doubt about how large is large, benchmarking can be the solution; it’s pretty much impossible to state a specific size, because it depends on many factors.

A receiver must be a value

* If we have to enforce a receiver’s immutability.
* If the receiver is a map, function, or channel. Otherwise, a compilation error
  occurs.

A receiver should be a value

* If the receiver is a slice that doesn’t have to be mutated.
* If the receiver is a small array or struct that is naturally a value type without mutable fields, such as `time.Time`.
* If the receiver is a basic type such as `int`, `float64`, or `string`.

Of course, it’s impossible to be exhaustive, as there will always be edge cases, but this section’s goal was to provide guidance to cover most cases. By default, we can choose to go with a value receiver unless there’s a good reason not to do so. In doubt, we should use a pointer receiver.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/06-functions-methods/42-receiver/)
