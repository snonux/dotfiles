# Mistake #22: Being confused about nil vs. empty slice


To prevent common confusions such as when using the `encoding/json` or the `reflect` package, you need to understand the difference between nil and empty slices. Both are zero-length, zero-capacity slices, but only a nil slice doesn’t require allocation.

In Go, there is a distinction between nil and empty slices. A nil slice is equals to `nil`, whereas an empty slice has a length of zero. A nil slice is empty, but an empty slice isn’t necessarily `nil`. Meanwhile, a nil slice doesn’t require any allocation. We have seen throughout this section how to initialize a slice depending on the context by using

* `var s []string` if we aren’t sure about the final length and the slice can be empty
* `[]string(nil)` as syntactic sugar to create a nil and empty slice
* `make([]string, length)` if the future length is known

The last option, `[]string{}`, should be avoided if we initialize the slice without elements. Finally, let’s check whether the libraries we use make the distinctions between nil and empty slices to prevent unexpected behaviors.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/22-nil-empty-slice/)
