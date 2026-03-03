# Mistake #51: Comparing an error value inaccurately

#### TL;DR
TL;DR

If you use Go 1.13 error wrapping with the `%w` directive and `fmt.Errorf`, comparing an error against or a value has to be done using `errors.As`. Otherwise, if the returned error you want to check is wrapped, it will fail the checks.

A sentinel error is an error defined as a global variable:

import "errors"

var ErrFoo = errors.New("foo")

In general, the convention is to start with `Err` followed by the error type: here, `ErrFoo`. A sentinel error conveys an expected error, an error that clients will expect to check. As general guidelines:

* Expected errors should be designed as error values (sentinel errors): `var ErrFoo = errors.New("foo")`.
* Unexpected errors should be designed as error types: `type BarError struct { ... }`, with `BarError` implementing the `error` interface.

If we use error wrapping in our application with the `%w` directive and `fmt.Errorf`, checking an error against a specific value should be done using `errors.Is` instead of `==`. Thus, even if the sentinel error is wrapped, `errors.Is` can recursively unwrap it and compare each error in the chain against the provided value.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/51-comparing-error-value/main.go)
