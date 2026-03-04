# Mistake #44: Unintended side effects with named result parameters

#### TL;DR

See #43.

We mentioned why named result parameters can be useful in some situations. But as these result parameters are initialized to their zero value, using them can sometimes lead to subtle bugs if we’re not careful enough. For example, can you spot what’s wrong with this code?

func (l loc) getCoordinates(ctx context.Context, address string) (
    lat, lng float32, err error) {
    isValid := l.validateAddress(address) (1)
    if !isValid {
        return 0, 0, errors.New("invalid address")
    }

    if ctx.Err() != nil { (2)
        return 0, 0, err
    }

    // Get and return coordinates
}

The error might not be obvious at first glance. Here, the error returned in the `if ctx.Err() != nil` scope is `err`. But we haven’t assigned any value to the `err` variable. It’s still assigned to the zero value of an `error` type: `nil`. Hence, this code will always return a nil error.

When using named result parameters, we must recall that each parameter is initialized to its zero value. As we have seen in this section, this can lead to subtle bugs that aren’t always straightforward to spot while reading code. Therefore, let’s remain cautious when using named result parameters, to avoid potential side effects.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/06-functions-methods/44-side-effects-named-result-parameters/main.go)
