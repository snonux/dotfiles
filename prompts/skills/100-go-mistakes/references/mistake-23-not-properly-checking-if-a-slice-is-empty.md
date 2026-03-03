# Mistake #23: Not properly checking if a slice is empty

#### TL;DR
TL;DR

To check if a slice doesn’t contain any element, check its length. This check works regardless of whether the slice is `nil` or empty. The same goes for maps. To design unambiguous APIs, you shouldn’t distinguish between nil and empty slices.

To determine whether a slice has elements, we can either do it by checking if the slice is nil or if its length is equal to 0. Checking the length is the best option to follow as it will cover both if the slice is empty or if the slice is nil.

Meanwhile, when designing interfaces, we should avoid distinguishing nil and empty slices, which leads to subtle programming errors. When returning slices, it should make neither a semantic nor a technical difference if we return a nil or empty slice. Both should mean the same thing for the callers. This principle is the same with maps. To check if a map is empty, check its length, not whether it’s nil.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/23-checking-slice-empty/main.go)
