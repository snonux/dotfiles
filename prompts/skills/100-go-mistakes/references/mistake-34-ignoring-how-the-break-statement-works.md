# Mistake #34: Ignoring how the break statement works


A `break` statement terminates the execution of the innermost `for`, `switch`, or `select` statement. Use labels to break out of an outer loop from within a `switch` or `select`.

A break statement is commonly used to terminate the execution of a loop. When loops are used in conjunction with switch or select, developers frequently make the mistake of breaking the wrong statement. For example:

    for i := 0; i < 5; i++ {
        fmt.Printf("%d ", i)
        switch i {
        default:
        case 2:
            break
        }
    }

The break statement doesn't terminate the `for` loop: it terminates the `switch` statement, instead. Hence, instead of iterating from 0 to 2, this code iterates from 0 to 4: `0 1 2 3 4`.

One essential rule to keep in mind is that a `break` statement terminates the execution of the innermost `for`, `switch`, or `select` statement.

To break the loop instead of the `switch` statement, the most idiomatic way is to use a label:

    loop:
        for i := 0; i < 5; i++ {
            fmt.Printf("%d ", i)
            switch i {
            default:
            case 2:
                break loop
            }
        }

Here, we associate the `loop` label with the `for` loop. Then, because we provide the `loop` label to the `break` statement, it breaks the loop, not the switch. Therefore, this new version will print `0 1 2`, as we expected.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/34-break/main.go)
