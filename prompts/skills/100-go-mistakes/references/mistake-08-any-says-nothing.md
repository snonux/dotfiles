# Mistake #8: any says nothing

#### TL;DR

The `any` type can be helpful if there is a genuine need for accepting or returning any possible type (for instance, when it comes to marshaling or formatting). In general, we should avoid overgeneralizing the code we write at all costs. Perhaps a little bit of duplicated code might occasionally be better if it improves other aspects such as code expressiveness.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/8-any/main.go)
