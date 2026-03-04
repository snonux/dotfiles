# Mistake #54: Not handling defer errors

#### TL;DR

When we want to ignore an error in a `defer` call, use the blank identifier (`_`) to make it explicit and add a comment explaining why.

Consider the following code:

    func f() {
        // ...
        notify() // Error handling is omitted
    }

    func notify() error {
        // ...
    }

From a maintainability perspective, the code can lead to some issues. A reader looking at it cannot tell whether the error was intentionally ignored or accidentally forgotten.

For these reasons, when we want to ignore an error, there's only one way to do it, using the blank identifier (`_`):

    _ = notify()

In terms of compilation and run time, this approach doesn't change anything compared to the first piece of code. But this new version makes explicit that we aren't interested in the error. Also, we can add a comment that indicates the rationale for why an error is ignored:

    // At-most once delivery.
    // Hence, it's accepted to miss some of them in case of errors.
    _ = notify()

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/54-defer-errors/main.go)
