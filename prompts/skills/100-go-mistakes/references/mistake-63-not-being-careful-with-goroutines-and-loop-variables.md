# Mistake #63: Not being careful with goroutines and loop variables

#### TL;DR

When launching goroutines from within a loop, be aware that the loop variable is shared across all iterations (prior to Go 1.22). Pass it as a parameter or create a local copy to avoid all goroutines referencing the last value.

A common mistake when using goroutines with loop variables is that all goroutines end up referencing the same variable, which holds the last iteration's value by the time goroutines execute. For example:

    for _, v := range s {
        go func() {
            fmt.Println(v) // All goroutines may print the last element
        }()
    }

The fix is to either pass the variable as a function argument or create a local copy:

    for _, v := range s {
        v := v // Create a local copy
        go func() {
            fmt.Println(v)
        }()
    }

Or pass it as a parameter:

    for _, v := range s {
        go func(val int) {
            fmt.Println(val)
        }(v)
    }

Note: As of Go 1.22, the loop variable semantics changed so each iteration gets its own variable, eliminating this class of bugs in newer Go versions.
