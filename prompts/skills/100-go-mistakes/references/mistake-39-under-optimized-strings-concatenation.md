# Mistake #39: Under-optimized strings concatenation

#### TL;DR
TL;DR

Concatenating a list of strings should be done with `strings.Builder` to prevent allocating a new string during each iteration.

Let’s consider a `concat` function that concatenates all the string elements of a slice using the `+=` operator:

func concat(values []string) string {
    s := ""
    for _, value := range values {
        s += value
    }
    return s
}

During each iteration, the `+=` operator concatenates `s` with the value string. At first sight, this function may not look wrong. But with this implementation, we forget one of the core characteristics of a string: its immutability. Therefore, each iteration doesn’t update `s`; it reallocates a new string in memory, which significantly impacts the performance of this function.

Fortunately, there is a solution to deal with this problem, using `strings.Builder`:

func concat(values []string) string {
    sb := strings.Builder{}
    for _, value := range values {
        _, _ = sb.WriteString(value)
    }
    return sb.String()
}

During each iteration, we constructed the resulting string by calling the `WriteString` method that appends the content of value to its internal buffer, hence minimizing memory copying.

#### TL;DR
Note

`WriteString` returns an error as the second output, but we purposely ignore it. Indeed, this method will never return a non-nil error. So what’s the purpose of this method returning an error as part of its signature? `strings.Builder` implements the `io.StringWriter` interface, which contains a single method: `WriteString(s string) (n int, err error)`. Hence, to comply with this interface, `WriteString` must return an error.

Internally, `strings.Builder` holds a byte slice. Each call to `WriteString` results in a call to append on this slice. There are two impacts. First, this struct shouldn’t be used concurrently, as the calls to `append` would lead to race conditions. The second impact is something that we saw in mistake #21, "Inefficient slice initialization": if the future length of a slice is already known, we should preallocate it. For that purpose, `strings.Builder` exposes a method `Grow(n int)` to guarantee space for another `n` bytes:

func concat(values []string) string {
    total := 0
    for i := 0; i &lt; len(values); i++ {
        total += len(values[i])
    }

    sb := strings.Builder{}
    sb.Grow(total) (2)
    for _, value := range values {
        _, _ = sb.WriteString(value)
    }
    return sb.String()
}

Let’s run a benchmark to compare the three versions (v1 using `+=`; v2 using `strings.Builder{}` without preallocation; and v3 using `strings.Builder{}` with preallocation). The input slice contains 1,000 strings, and each string contains 1,000 bytes:

BenchmarkConcatV1-4             16      72291485 ns/op
BenchmarkConcatV2-4           1188        878962 ns/op
BenchmarkConcatV3-4           5922        190340 ns/op

As we can see, the latest version is by far the most efficient: 99% faster than v1 and 78% faster than v2.

`strings.Builder` is the recommended solution to concatenate a list of strings. Usually, this solution should be used within a loop. Indeed, if we just have to concatenate a few strings (such as a name and a surname), using `strings.Builder` is not recommended as doing so will make the code a bit less readable than using the `+=` operator or `fmt.Sprintf`.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/39-string-concat/)
