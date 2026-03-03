# Mistake #17: Creating confusion with octal literals

#### TL;DR
TL;DR

When reading existing code, bear in mind that integer literals starting with `0` are octal numbers. Also, to improve readability, make octal integers explicit by prefixing them with `0o`.

Octal numbers start with a 0 (e.g., `010` is equal to 8 in base 10). To improve readability and avoid potential mistakes for future code readers, we should make octal numbers explicit using the `0o` prefix (e.g., `0o10`).

We should also note the other integer literal representations:

* Binary—Uses a `0b` or `0B` prefix (for example, `0b100` is equal to 4 in base 10)
* Hexadecimal—Uses an `0x` or `0X` prefix (for example, `0xF` is equal to 15 in base 10)
* Imaginary—Uses an `i` suffix (for example, `3i`)

We can also use an underscore character (_) as a separator for readability. For example, we can write 1 billion this way: `1_000_000_000`. We can also use the underscore character with other representations (for example, `0b00_00_01`).

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/17-octal-literals/main.go)
