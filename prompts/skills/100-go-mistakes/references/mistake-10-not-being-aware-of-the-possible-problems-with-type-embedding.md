# Mistake #10: Not being aware of the possible problems with type embedding

#### TL;DR

Using type embedding can also help avoid boilerplate code; however, ensure that doing so doesn’t lead to visibility issues where some fields should have remained hidden.

When creating a struct, Go offers the option to embed types. But this can sometimes lead to unexpected behaviors if we don’t understand all the implications of type embedding. Throughout this section, we look at how to embed types, what these bring, and the possible issues.

In Go, a struct field is called embedded if it’s declared without a name. For example,

type Foo struct {
    Bar // Embedded field
}

type Bar struct {
    Baz int
}

In the `Foo` struct, the `Bar` type is declared without an associated name; hence, it’s an embedded field.

We use embedding to promote the fields and methods of an embedded type. Because `Bar` contains a `Baz` field, this field is
promoted to `Foo`. Therefore, `Baz` becomes available from `Foo`.

What can we say about type embedding? First, let’s note that it’s rarely a necessity, and it means that whatever the use case, we can probably solve it as well without type embedding. Type embedding is mainly used for convenience: in most cases, to promote behaviors.

If we decide to use type embedding, we need to keep two main constraints in mind:

* It shouldn’t be used solely as some syntactic sugar to simplify accessing a field (such as `Foo.Baz()` instead of `Foo.Bar.Baz()`). If this is the only rationale, let’s not embed the inner type and use a field instead.
* It shouldn’t promote data (fields) or a behavior (methods) we want to hide from the outside: for example, if it allows clients to access a locking behavior that should remain private to the struct.

Using type embedding consciously by keeping these constraints in mind can help avoid boilerplate code with additional forwarding methods. However, let’s make sure we don’t do it solely for cosmetics and not promote elements that should remain hidden.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/10-type-embedding/main.go)
