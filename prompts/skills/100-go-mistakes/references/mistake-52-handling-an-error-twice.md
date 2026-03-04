# Mistake #52: Handling an error twice


In most situations, an error should be handled only once. Logging an error is handling an error. Therefore, you have to choose between logging or returning an error. In many cases, error wrapping is the solution as it allows you to provide additional context to an error and return the source error.

Handling an error multiple times is a mistake made frequently by developers, not specifically in Go. This can cause situations where the same error is logged multiple times make debugging harder.

Let's remind us that handling an error should be done only once. Logging an error is handling an error. Hence, we should either log or return an error. By doing this, we simplify our code and gain better insights into the error situation. Using error wrapping is the most convenient approach as it allows us to propagate the source error and add context to an error.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/52-handling-error-twice/main.go)
