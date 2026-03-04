# Mistake #40: Useless string conversions

#### TL;DR

Remembering that the `bytes` package offers the same operations as the `strings` package can help avoid extra byte/string conversions.

When choosing to work with a string or a `[]byte`, most programmers tend to favor strings for convenience. But most I/O is actually done with `[]byte`. For example, `io.Reader`, `io.Writer`, and `io.ReadAll` work with `[]byte`, not strings.

When we’re wondering whether we should work with strings or `[]byte`, let’s recall that working with `[]byte` isn’t necessarily less convenient. Indeed, all the exported functions of the strings package also have alternatives in the `bytes` package: `Split`, `Count`, `Contains`, `Index`, and so on. Hence, whether we’re doing I/O or not, we should first check whether we could implement a whole workflow using bytes instead of strings and avoid the price of additional conversions.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/40-string-conversion/main.go)
