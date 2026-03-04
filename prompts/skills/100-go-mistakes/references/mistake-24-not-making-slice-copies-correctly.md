# Mistake #24: Not making slice copies correctly

#### TL;DR

To copy one slice to another using the `copy` built-in function, remember that the number of copied elements corresponds to the minimum between the two slice’s lengths.

Copying elements from one slice to another is a reasonably frequent operation. When using copy, we must recall that the number of elements copied to the destination corresponds to the minimum between the two slices’ lengths. Also bear in mind that other alternatives exist to copy a slice, so we shouldn’t be surprised if we find them in a codebase.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/24-slice-copy/main.go)
