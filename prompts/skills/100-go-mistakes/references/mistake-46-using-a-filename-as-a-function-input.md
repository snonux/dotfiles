# Mistake #46: Using a filename as a function input

#### TL;DR
TL;DR

Designing functions to receive `io.Reader` types instead of filenames improves the reusability of a function and makes testing easier.

Accepting a filename as a function input to read from a file should, in most cases, be considered a code smell (except in specific functions such as `os.Open`). Indeed, it makes unit tests more complex because we may have to create multiple files. It also reduces the reusability of a function (although not all functions are meant to be reused). Using the `io.Reader` interface abstracts the data source. Regardless of whether the input is a file, a string, an HTTP request, or a gRPC request, the implementation can be reused and easily tested.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/06-functions-methods/46-function-input/)
