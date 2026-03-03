# Mistake #50: Comparing an error type inaccurately

#### TL;DR
TL;DR

If you use Go 1.13 error wrapping with the `%w` directive and `fmt.Errorf`, comparing an error against a type has to be done using `errors.As`. Otherwise, if the returned error you want to check is wrapped, it will fail the checks.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/50-compare-error-type/main.go)
