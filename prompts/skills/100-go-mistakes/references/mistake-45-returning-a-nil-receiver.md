# Mistake #45: Returning a nil receiver


When returning an interface, be cautious about not returning a nil pointer but an explicit nil value. Otherwise, unintended consequences may occur and the caller will receive a non-nil value.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/06-functions-methods/45-nil-receiver/main.go)
