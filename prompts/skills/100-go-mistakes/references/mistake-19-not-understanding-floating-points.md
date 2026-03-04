# Mistake #19: Not understanding floating-points

#### TL;DR

Making floating-point comparisons within a given delta can ensure that your code is portable. When performing addition or subtraction, group the operations with a similar order of magnitude to favor accuracy. Also, perform multiplication and division before addition and subtraction.

In Go, there are two floating-point types (if we omit imaginary numbers): float32 and float64. The concept of a floating point was invented to solve the major problem with integers: their inability to represent fractional values. To avoid bad surprises, we need to know that floating-point arithmetic is an approximation of real arithmetic.

For that, we’ll look at a multiplication example:

var n float32 = 1.0001
fmt.Println(n * n)

We may expect this code to print the result of 1.0001 * 1.0001 = 1.00020001, right? However, running it on most x86 processors prints 1.0002, instead.

Because Go’s `float32` and `float64` types are approximations, we have to bear a few rules in mind:

* When comparing two floating-point numbers, check that their difference is within an acceptable range.
* When performing additions or subtractions, group operations with a similar order of magnitude for better accuracy.
* To favor accuracy, if a sequence of operations requires addition, subtraction, multiplication, or division, perform the multiplication and division operations first.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/03-data-types/19-floating-points/main.go)
