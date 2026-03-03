# Mistake #2: Unnecessary nested code

#### TL;DR
TL;DR

Avoiding nested levels and keeping the happy path aligned on the left makes building a mental code model easier.

In general, the more nested levels a function requires, the more complex it is to read and understand. Let’s see some different applications of this rule to optimize our code for readability:

* When an `if` block returns, we should omit the `else` block in all cases. For example, we shouldn’t write:

if foo() {
    // ...
    return true
} else {
    // ...
}

Instead, we omit the `else` block like this:

if foo() {
    // ...
    return true
}
// ...

* We can also follow this logic with a non-happy path:

if s != "" {
    // ...
} else {
    return errors.New("empty string")
}

Here, an empty `s` represents the non-happy path. Hence, we should flip the
  condition like so:

if s == "" {
    return errors.New("empty string")
}
// ...

Writing readable code is an important challenge for every developer. Striving to reduce the number of nested blocks, aligning the happy path on the left, and returning as early as possible are concrete means to improve our code’s readability.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/2-nested-code/main.go)
