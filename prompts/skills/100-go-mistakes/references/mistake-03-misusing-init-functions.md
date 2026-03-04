# Mistake #3: Misusing init functions

#### TL;DR

When initializing variables, remember that init functions have limited error handling and make state handling and testing more complex. In most cases, initializations should be handled as specific functions.

An init function is a function used to initialize the state of an application. It takes no arguments and returns no result (a `func()` function). When a package is initialized, all the constant and variable declarations in the package are evaluated. Then, the init functions are executed.

Init functions can lead to some issues:

* They can limit error management.
* They can complicate how to implement tests (for example, an external dependency must be set up, which may not be necessary for the scope of unit tests).
* If the initialization requires us to set a state, that has to be done through global variables.

We should be cautious with init functions. They can be helpful in some situations, however, such as defining static configuration. Otherwise, and in most cases, we should handle initializations through ad hoc functions.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/3-init-functions/)
