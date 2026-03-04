# Mistake #37: Inaccurate string iteration


Iterating on a string with the `range` operator iterates on the runes with the index corresponding to the starting index of the rune’s byte sequence. To access a specific rune index (such as the third rune), convert the string into a `[]rune`.

Iterating on a string is a common operation for developers. Perhaps we want to perform an operation for each rune in the string or implement a custom function to search for a specific substring. In both cases, we have to iterate on the different runes of a string. But it’s easy to get confused about how iteration works.

For example, consider the following example:

s := "hêllo"
for i := range s {
    fmt.Printf("position %d: %c\n", i, s[i])
}
fmt.Printf("len=%d\n", len(s))

position 0: h
position 1: Ã
position 3: l
position 4: l
position 5: o
len=6

Let's highlight three points that might be confusing:

* The second rune is Ã in the output instead of ê.
* We jumped from position 1 to position 3: what is at position 2?
* len returns a count of 6, whereas s contains only 5 runes.

Let’s start with the last observation. We already mentioned that len returns the number of bytes in a string, not the number of runes. Because we assigned a string literal to `s`, `s` is a UTF-8 string. Meanwhile, the special character "ê" isn’t encoded in a single byte; it requires 2 bytes. Therefore, calling `len(s)` returns 6.

Meanwhile, in the previous example, we have to understand that we don't iterate over each rune; instead, we iterate over each starting index of a rune:

Printing `s[i]` doesn’t print the ith rune; it prints the UTF-8 representation of the byte at index `i`. Hence, we printed "hÃllo" instead of "hêllo".

If we want to print all the different runes, we can either use the value element of the `range` operator:

s := "hêllo"
for i, r := range s {
    fmt.Printf("position %d: %c\n", i, r)
}

Or, we can convert the string into a slice of runes and iterate over it:

s := "hêllo"
runes := []rune(s)
for i, r := range runes {
    fmt.Printf("position %d: %c\n", i, r)
}

Note that this solution introduces a run-time overhead compared to the previous one. Indeed, converting a string into a slice of runes requires allocating an additional slice and converting the bytes into runes: an O(n) time complexity with n the number of bytes in the string. Therefore, if we want to iterate over all the runes, we should use the first solution.

However, if we want to access the ith rune of a string with the first option, we don’t have access to the rune index; rather, we know the starting index of a rune in the byte sequence.

s := "hêllo"
r := []rune(s)[4]
fmt.Printf("%c\n", r) // o

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/37-string-iteration/main.go)
