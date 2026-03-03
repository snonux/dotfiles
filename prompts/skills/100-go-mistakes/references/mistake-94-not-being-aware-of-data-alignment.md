# Mistake #94: Not being aware of data alignment

#### TL;DR
TL;DR

You can avoid common mistakes by remembering that in Go, basic types are aligned with their own size. For example, keep in mind that reorganizing the fields of a struct by size in descending order can lead to more compact structs (less memory allocation and potentially a better spatial locality).

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/94-data-alignment/)
