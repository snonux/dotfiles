# Mistake #43: Never using named result parameters

#### TL;DR
TL;DR

Using named result parameters can be an efficient way to improve the readability of a function/method, especially if multiple result parameters have the same type. In some cases, this approach can also be convenient because named result parameters are initialized to their zero value. But be cautious about potential side effects.

When we return parameters in a function or a method, we can attach names to these parameters and use them as regular variables. When a result parameter is named, it’s initialized to its zero value when the function/method begins. With named result parameters, we can also call a naked return statement (without arguments). In that case, the current values of the result parameters are used as the returned values.

Here’s an example that uses a named result parameter `b`:

func f(a int) (b int) {
    b = a
    return
}

In this example, we attach a name to the result parameter: `b`. When we call return without arguments, it returns the current value of `b`.

In some cases, named result parameters can also increase readability: for example, if two parameters have the same type. In other cases, they can also be used for convenience. Therefore, we should use named result parameters sparingly when there’s a clear benefit.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/06-functions-methods/43-named-result-parameters/main.go)
