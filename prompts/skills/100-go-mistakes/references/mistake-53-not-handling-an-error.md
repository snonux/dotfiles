# Mistake #53: Not handling an error

#### TL;DR

Ignoring an error, whether during a function call or in a `defer` function, should be done explicitly using the blank identifier. Otherwise, future readers may be confused about whether it was intentional or a miss.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/53-not-handling-error/main.go)
