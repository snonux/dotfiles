# Mistake #88: Not using testing utility packages (httptest and iotest)

#### TL;DR

Use the `httptest` package for testing HTTP clients and servers, and the `iotest` package for testing `io.Reader` implementations and error tolerance.

The `httptest` package provides utilities to test HTTP applications without starting a real server:

* `httptest.NewServer` creates a local HTTP server for integration testing.
* `httptest.NewRecorder` creates a `ResponseRecorder` to inspect HTTP responses in handler tests.

The `iotest` package helps write `io.Reader` implementations and test that an application is tolerant to errors:

* `iotest.ErrReader` returns a reader that always returns an error.
* `iotest.HalfReader` returns a reader that reads half the requested bytes.
* `iotest.OneByteReader` returns a reader that reads one byte at a time.
* `iotest.TestReader` tests an `io.Reader` implementation for correctness.

[Source code (httptest)](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/88-utility-package/httptest/main_test.go)

[Source code (iotest)](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/88-utility-package/iotest/main_test.go)
