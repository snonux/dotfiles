# Mistake #48: Panicking

#### TL;DR
TL;DR

Using `panic` is an option to deal with errors in Go. However, it should only be used sparingly in unrecoverable conditions: for example, to signal a programmer error or when you fail to load a mandatory dependency.

In Go, panic is a built-in function that stops the ordinary flow:

func main() {
    fmt.Println("a")
    panic("foo")
    fmt.Println("b")
}

This code prints a and then stops before printing b:

a
panic: foo

goroutine 1 [running]:
main.main()
        main.go:7 +0xb3

Panicking in Go should be used sparingly. There are two prominent cases, one to signal a programmer error (e.g., `sql.Register` that panics if the driver is `nil` or has already been register) and another where our application fails to create a mandatory dependency. Hence, exceptional conditions that lead us to stop the application. In most other cases, error management should be done with a function that returns a proper error type as the last return argument.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/07-error-management/48-panic/main.go)
