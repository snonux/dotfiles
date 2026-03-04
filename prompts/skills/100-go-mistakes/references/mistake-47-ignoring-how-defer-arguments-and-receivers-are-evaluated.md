# Mistake #47: Ignoring how defer arguments and receivers are evaluated


In a `defer` function, arguments are evaluated right away, not once the surrounding function returns. To defer a call with an updated value, use pointers or closures.

In a `defer` function the arguments are evaluated right away, not once the surrounding function returns. For example, in this code, we always call `notify` and `incrementCounter` with the same status: an empty string.

    const (
        StatusSuccess  = "success"
        StatusErrorFoo = "error_foo"
        StatusErrorBar = "error_bar"
    )

    func f() error {
        var status string
        defer notify(status)
        defer incrementCounter(status)

        if err := foo(); err != nil {
            status = StatusErrorFoo
            return err
        }

        if err := bar(); err != nil {
            status = StatusErrorBar
            return err
        }

        status = StatusSuccess
        return nil
    }

Two leading options if we want to keep using `defer`:

The first solution is to pass a string pointer:

    func f() error {
        var status string
        defer notify(&status)
        defer incrementCounter(&status)
        // The rest of the function unchanged
    }

There's another solution: calling a closure as a `defer` statement:

    func f() error {
        var status string
        defer func() {
            notify(status)
            incrementCounter(status)
        }()
        // The rest of the function unchanged
    }

Here, we wrap the calls within a closure. This closure references the status variable from outside its body. Therefore, `status` is evaluated once the closure is executed, not when we call `defer`.

Let's also note this behavior applies with method receivers: the receiver is evaluated immediately.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/06-functions-methods/47-defer-evaluation/)
