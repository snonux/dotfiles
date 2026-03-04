# Mistake #31: Ignoring how arguments are evaluated in range loops (channels and arrays)


The range loop expression is evaluated only once, before the beginning of the loop, by doing a copy. Be aware of this to avoid common mistakes.

The range loop evaluates the provided expression only once, before the beginning of the loop, by doing a copy (regardless of the type). We should remember this behavior to avoid common mistakes that might, for example, lead us to access the wrong element. For example:

    a := [3]int{0, 1, 2}
    for i, v := range a {
        a[2] = 10
        if i == 2 {
            fmt.Println(v)
        }
    }

This code updates the last index to 10. However, if we run this code, it does not print 10; it prints 2, because the range expression `a` was copied before the loop started.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/31-range-loop-arg-evaluation/)
