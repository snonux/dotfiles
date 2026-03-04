# Mistake #83: Not enabling the race flag

#### TL;DR

Enabling the `-race` flag is highly recommended when writing concurrent applications. Doing so allows you to catch potential data races that can lead to software bugs.

In Go, the race detector isn’t a static analysis tool used during compilation; instead, it’s a tool to find data races that occur at runtime. To enable it, we have to enable the -race flag while compiling or running a test. For example:

go test -race ./...

Once the race detector is enabled, the compiler instruments the code to detect data races. Instrumentation refers to a compiler adding extra instructions: here, tracking all memory accesses and recording when and how they occur.

Enabling the race detector adds an overhead in terms of memory and execution time; hence, it's generally recommended to enable it only during local testing or continuous integration, not production.

If a race is detected, Go raises a warning. For example:

package main

import (
    "fmt"
)

func main() {
    i := 0
    go func() { i++ }()
    fmt.Println(i)
}

Running this code with the `-race` logs the following warning:

==================
WARNING: DATA RACE
Write at 0x00c000026078 by goroutine 7: # (1)
  main.main.func1()
      /tmp/app/main.go:9 +0x4e

Previous read at 0x00c000026078 by main goroutine: # (2)
  main.main()
      /tmp/app/main.go:10 +0x88

Goroutine 7 (running) created at: # (3)
  main.main()
      /tmp/app/main.go:9 +0x7a
==================

* Indicates that goroutine 7 was writing
* Indicates that the main goroutine was reading
* Indicates when the goroutine 7 was created

Let’s make sure we are comfortable reading these messages. Go always logs the following:

* The concurrent goroutines that are incriminated: here, the main goroutine and goroutine 7.
* Where accesses occur in the code: in this case, lines 9 and 10.
* When these goroutines were created: goroutine 7 was created in main().

In addition, if a specific file contains tests that lead to data races, we can exclude it  from race detection using the `!race` build tag:

//go:build !race

package main

import (
    "testing"
)

func TestFoo(t *testing.T) {
    // ...
}
