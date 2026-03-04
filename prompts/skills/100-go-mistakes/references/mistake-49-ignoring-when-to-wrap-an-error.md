# Mistake #49: Ignoring when to wrap an error

#### TL;DR

Wrapping an error allows you to mark an error and/or provide additional context. However, error wrapping creates potential coupling as it makes the source error available for the caller. If you want to prevent that, don’t use error wrapping.

Since Go 1.13, the %w directive allows us to wrap errors conveniently. Error wrapping is about wrapping or packing an error inside a wrapper container that also makes the source error available. In general, the two main use cases for error wrapping are the following:

* Adding additional context to an error
* Marking an error as a specific error

When handling an error, we can decide to wrap it. Wrapping is about adding additional context to an error and/or marking an error as a specific type. If we need to mark an error, we should create a custom error type. However, if we just want to add extra context, we should use fmt.Errorf with the %w directive as it doesn’t require creating a new error type. Yet, error wrapping creates potential coupling as it makes the source error available for the caller. If we want to prevent it, we shouldn’t use error wrapping but error transformation, for example, using fmt.Errorf with the %v directive.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/49-error-wrapping/main.go)
