# Mistake #77: JSON handling common mistakes

* Unexpected behavior because of type embedding

Be careful about using embedded fields in Go structs. Doing so may lead to sneaky bugs like an embedded time.Time field implementing the `json.Marshaler` interface, hence overriding the default marshaling behavior.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/77-json-handling/type-embedding/main.go)

* JSON and the monotonic clock

When comparing two `time.Time` structs, recall that `time.Time` contains both a wall clock and a monotonic clock, and the comparison using the == operator is done on both clocks.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/77-json-handling/monotonic-clock/main.go)

* Map of `any`

To avoid wrong assumptions when you provide a map while unmarshaling JSON data, remember that numerics are converted to `float64` by default.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/77-json-handling/map-any/main.go)
