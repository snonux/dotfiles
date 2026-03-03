# Mistake #15: Missing code documentation

#### TL;DR
TL;DR

To help clients and maintainers understand your code’s purpose, document exported elements.

Documentation is an important aspect of coding. It simplifies how clients can consume an API but can also help in maintaining a project. In Go, we should follow some rules to make our code idiomatic:

First, every exported element must be documented. Whether it is a structure, an interface, a function, or something else, if it’s exported, it must be documented. The convention is to add comments, starting with the name of the exported element.

As a convention, each comment should be a complete sentence that ends with punctuation. Also bear in mind that when we document a function (or a method), we should highlight what the function intends to do, not how it does it; this belongs to the core of a function and comments, not documentation. Furthermore, the documentation should ideally provide enough information that the consumer does not have to look at our code to understand how to use an exported element.

When it comes to documenting a variable or a constant, we might be interested in conveying two aspects: its purpose and its content. The former should live as code documentation to be useful for external clients. The latter, though, shouldn’t necessarily be public.

To help clients and maintainers understand a package’s scope, we should also document each package. The convention is to start the comment with `// Package` followed by the package name. The first line of a package comment should be concise. That’s because it will appear in the package. Then, we can provide all the information we need in the following lines.

Documenting our code shouldn’t be a constraint. We should take the opportunity to make sure it helps clients and maintainers to understand the purpose of our code.
