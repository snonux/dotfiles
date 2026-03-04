# Mistake #25: Unexpected side effects using slice append


Using copy or the full slice expression is a way to prevent `append` from creating conflicts if two different functions use slices backed by the same array. However, only a slice copy prevents memory leaks if you want to shrink a large slice.

When using slicing, we must remember that we can face a situation leading to unintended side effects. If the resulting slice has a length smaller than its capacity, append can mutate the original slice. If we want to restrict the range of possible side effects, we can use either a slice copy or the full slice expression, which prevents us from doing a copy.

#### Note

`s[low:high:max]` (full slice expression): This statement creates a slice similar to the one created with `s[low:high]`, except that the resulting slice’s capacity is equal to `max - low`.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/25-slice-append/main.go)
