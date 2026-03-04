# Mistake #75: Providing a wrong time duration

#### TL;DR

Remain cautious with functions accepting a `time.Duration`. Even though passing an integer is allowed, strive to use the time API to prevent any possible confusion.

Many common functions in the standard library accept a `time.Duration`, which is an alias for the `int64` type. However, one `time.Duration` unit represents one nanosecond, instead of one millisecond, as commonly seen in other programming languages. As a result, passing numeric types instead of using the `time.Duration` API can lead to unexpected behavior.

A developer with experience in other languages might assume that the following code creates a new `time.Ticker` that delivers ticks every second, given the value `1000`:

ticker := time.NewTicker(1000)
for {
    select {
    case <-ticker.C:
        // Do something
    }
}

However, because 1,000 `time.Duration` units = 1,000 nanoseconds, ticks are delivered every 1,000 nanoseconds = 1 microsecond, not every second as assumed.

We should always use the `time.Duration` API to avoid confusion and unexpected behavior:

ticker = time.NewTicker(time.Microsecond)
// Or
ticker = time.NewTicker(1000 * time.Nanosecond)

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/75-wrong-time-duration/main.go)
