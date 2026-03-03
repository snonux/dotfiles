# Mistake #12: Project misorganization (project structure and package organization)

Regarding the overall organization, there are different schools of thought. For example, should we organize our application by context or by layer? It depends on our preferences. We may favor grouping code per context (such as the customer context, the contract context, etc.), or we may favor following hexagonal architecture principles and group per technical layer. If the decision we make fits our use case, it cannot be a wrong decision, as long as we remain consistent with it.

Regarding packages, there are multiple best practices that we should follow. First, we should avoid premature packaging because it might cause us to overcomplicate a project. Sometimes, it’s better to use a simple organization and have our project evolve when we understand what it contains rather than forcing ourselves to make the perfect structure up front.
Granularity is another essential thing to consider. We should avoid having dozens of nano packages containing only one or two files. If we do, it’s because we have probably missed some logical connections across these packages, making our project harder for readers to understand. Conversely, we should also avoid huge packages that dilute the meaning of a package name.

Package naming should also be considered with care. As we all know (as developers), naming is hard. To help clients understand a Go project, we should name our packages after what they provide, not what they contain. Also, naming should be meaningful. Therefore, a package name should be short, concise, expressive, and, by convention, a single lowercase word.

Regarding what to export, the rule is pretty straightforward. We should minimize what should be exported as much as possible to reduce the coupling between packages and keep unnecessary exported elements hidden. If we are unsure whether to export an element or not, we should default to not exporting it. Later, if we discover that we need to export it, we can adjust our code. Let’s also keep in mind some exceptions, such as making fields exported so that a struct can be unmarshaled with encoding/json.

Organizing a project isn’t straightforward, but following these rules should help make it easier to maintain. However, remember that consistency is also vital to ease maintainability. Therefore, let’s make sure that we keep things as consistent as possible within a codebase.

#### TL;DR
Note

In 2023, the Go team has published an official guideline for organizing / structuring a Go project: go.dev/doc/modules/layout
