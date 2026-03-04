# Mistake #1: Unintended variable shadowing

#### TL;DR

Avoiding shadowed variables can help prevent mistakes like referencing the wrong variable or confusing readers.

Variable shadowing occurs when a variable name is redeclared in an inner block, but this practice is prone to mistakes. Imposing a rule to forbid shadowed variables depends on personal taste. For example, sometimes it can be convenient to reuse an existing variable name like `err` for errors. Yet, in general, we should remain cautious because we now know that we can face a scenario where the code compiles, but the variable that receives the value is not the one expected.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/1-variable-shadowing/main.go)
