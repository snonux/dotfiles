# Mistake #76: time.After and memory leaks


Avoid using `time.After` in loops or repeated calls; it creates a new channel each time that won't be GC'd until the timer fires. Use `time.NewTimer` instead and call `Stop` when done.

`time.After(d)` is a convenience wrapper that returns a channel that will receive the current time after duration `d`. However, the resources created by `time.After` are not freed until the timer expires. If used inside a loop—for example, in a `select` statement—each iteration creates a new timer that won't be garbage collected until it fires. This can lead to significant memory leaks in long-running applications.

The solution is to use `time.NewTimer` instead, which allows you to stop the timer proactively:

    timer := time.NewTimer(d)
    defer timer.Stop()

    select {
    case <-ch:
        // Handle message
        if !timer.Stop() {
            <-timer.C
        }
        timer.Reset(d)
    case <-timer.C:
        // Handle timeout
    }
