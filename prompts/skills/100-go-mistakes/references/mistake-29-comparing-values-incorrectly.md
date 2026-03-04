# Mistake #29: Comparing values incorrectly


To compare types in Go, you can use the == and != operators if two types are comparable: Booleans, numerals, strings, pointers, channels, and structs are composed entirely of comparable types. Otherwise, you can either use `reflect.DeepEqual` and pay the price of reflection or use custom implementations and libraries.

It’s essential to understand how to use `==` and `!=` to make comparisons effectively. We can use these operators on operands that are comparable:

* Booleans—Compare whether two Booleans are equal.
* Numerics (int, float, and complex types)—Compare whether two numerics are equal.
* Strings—Compare whether two strings are equal.
* Channels—Compare whether two channels were created by the same call to make or if both are nil.
* Interfaces—Compare whether two interfaces have identical dynamic types and equal dynamic values or if both are nil.
* Pointers—Compare whether two pointers point to the same value in memory or if both are nil.
* Structs and arrays—Compare whether they are composed of similar types.

#### Note

We can also use the `<=`, `>=`, `<`, and `>` operators with numeric types to compare values and with strings to compare their lexical order.

If operands are not comparable (e.g., slices and maps), we have to use other options such as reflection. Reflection is a form of metaprogramming, and it refers to the ability of an application to introspect and modify its structure and behavior. For example, in Go, we can use `reflect.DeepEqual`. This function reports whether two elements are deeply equal by recursively traversing two values. The elements it accepts are basic types plus arrays, structs, slices, maps, pointers, interfaces, and functions. Yet, the main catch is the performance penalty.

If performance is crucial at run time, implementing our custom method might be the best solution.
One additional note: we must remember that the standard library has some existing comparison methods. For example, we can use the optimized `bytes.Compare` function to compare two slices of bytes. Before implementing a custom method, we need to make sure we don’t reinvent the wheel.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/29-comparing-values/main.go)
