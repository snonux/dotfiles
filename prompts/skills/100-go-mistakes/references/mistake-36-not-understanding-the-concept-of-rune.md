# Mistake #36: Not understanding the concept of rune


Understanding that a rune corresponds to the concept of a Unicode code point and that it can be composed of multiple bytes should be part of the Go developer’s core knowledge to work accurately with strings.

As runes are everywhere in Go, it's important to understand the following:

* A charset is a set of characters, whereas an encoding describes how to translate a charset into binary.
* In Go, a string references an immutable slice of arbitrary bytes.
* Go source code is encoded using UTF-8. Hence, all string literals are UTF-8 strings. But because a string can contain arbitrary bytes, if it’s obtained from somewhere else (not the source code), it isn’t guaranteed to be based on the UTF-8 encoding.
* A `rune` corresponds to the concept of a Unicode code point, meaning an item represented by a single value.
* Using UTF-8, a Unicode code point can be encoded into 1 to 4 bytes.
* Using `len()` on a string in Go returns the number of bytes, not the number of runes.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/36-rune/main.go)
