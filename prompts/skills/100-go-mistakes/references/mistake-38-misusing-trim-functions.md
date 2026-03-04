# Mistake #38: Misusing trim functions

#### TL;DR

`strings.TrimRight`/`strings.TrimLeft` removes all the trailing/leading runes contained in a given set, whereas `strings.TrimSuffix`/`strings.TrimPrefix` returns a string without a provided suffix/prefix.

For example:

fmt.Println(strings.TrimRight("123oxo", "xo"))

The example prints 123:

Conversely, `strings.TrimLeft` removes all the leading runes contained in a set.

On the other side, `strings.TrimSuffix` / `strings.TrimPrefix` returns a string without the provided trailing suffix / prefix.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/38-trim/main.go)
