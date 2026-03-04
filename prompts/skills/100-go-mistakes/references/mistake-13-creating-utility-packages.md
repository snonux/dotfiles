# Mistake #13: Creating utility packages


Naming is a critical piece of application design. Creating packages such as `common`, `util`, and `shared` doesn’t bring much value for the reader. Refactor such packages into meaningful and specific package names.

Also, bear in mind that naming a package after what it provides and not what it contains can be an efficient way to increase its expressiveness.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/13-utility-packages/stringset.go)
