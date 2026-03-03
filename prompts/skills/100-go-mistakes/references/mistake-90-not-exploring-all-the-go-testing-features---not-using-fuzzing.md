# Mistake #90: Not exploring all the Go testing features

* Code coverage

Use code coverage with the `-coverprofile` flag to quickly see which part of the code needs more attention.

* Testing from a different package

Place unit tests in a different package to enforce writing tests that focus on an exposed behavior, not internals.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/90-testing-features/different-package/main_test.go)

* Utility functions

Handling errors using the `*testing.T` variable instead of the classic `if err != nil` makes code shorter and easier to read.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/90-testing-features/utility-function/main_test.go)

* Setup and teardown

You can use setup and teardown functions to configure a complex environment, such as in the case of integration tests.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/90-testing-features/setup-teardown/main_test.go)
