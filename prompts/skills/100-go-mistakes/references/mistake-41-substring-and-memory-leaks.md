# Mistake #41: Substring and memory leaks

#### TL;DR
TL;DR

Using copies instead of substrings can prevent memory leaks, as the string returned by a substring operation will be backed by the same byte array.

In mistake #26, “Slices and memory leaks,” we saw how slicing a slice or array may lead to memory leak situations. This principle also applies to string and substring operations.

We need to keep two things in mind while using the substring operation in Go. First, the interval provided is based on the number of bytes, not the number of runes. Second, a substring operation may lead to a memory leak as the resulting substring will share the same backing array as the initial string. The solutions to prevent this case from happening are to perform a string copy manually or to use `strings.Clone` from Go 1.18.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/41-substring-memory-leak/main.go)
