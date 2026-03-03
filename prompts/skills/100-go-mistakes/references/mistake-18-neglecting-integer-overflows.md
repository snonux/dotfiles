# Mistake #18: Neglecting integer overflows

#### TL;DR
TL;DR

Because integer overflows and underflows are handled silently in Go, you can implement your own functions to catch them.

In Go, an integer overflow that can be detected at compile time generates a compilation error. For example,

var counter int32 = math.MaxInt32 + 1

constant 2147483648 overflows int32

However, at run time, an integer overflow or underflow is silent; this does not lead to an application panic. It is essential to keep this behavior in mind, because it can lead to sneaky bugs (for example, an integer increment or addition of positive integers that leads to a negative result).

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/18-integer-overflows)
