# Mistake #33: Making wrong assumptions during map iterations (ordering and map insert during iteration)

#### TL;DR
TL;DR

To ensure predictable outputs when using maps, remember that a map data structure:

* Doesn’t order the data by keys
* Doesn’t preserve the insertion order
* Doesn’t have a deterministic iteration order
* Doesn’t guarantee that an element added during an iteration will be produced during this iteration

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/33-map-iteration/main.go)
