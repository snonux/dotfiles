---
name: 100-go-mistakes
description: Audits Go code repositories for common mistakes as identified in the "100 Go Mistakes and How to Avoid Them" book. Use this skill when asked to review Go code, check for best practices, or find common anti-patterns in Go.
---

# 100 Go Mistakes

This skill helps you identify and fix the most common mistakes made by Go developers. It is based on the book "100 Go Mistakes and How to Avoid Them" by Teiva Harsanyi.

## Workflow

1. **Trigger**: When asked to review Go code or find mistakes, activate this skill.
2. **Analysis**: Use the list below to identify potential areas of concern in the target repository.
3. **Reference**: Read the specific mistake documentation in the `references/` folder to understand the mistake and how to fix it.
4. **Action**: Suggest or apply fixes to the codebase.

## List of Mistakes

### 1. Code and Project Organization
- [Mistake #1: Unintended variable shadowing](references/mistake-01-unintended-variable-shadowing.md)
- [Mistake #2: Unnecessary nested code](references/mistake-02-unnecessary-nested-code.md)
- [Mistake #3: Misusing init functions](references/mistake-03-misusing-init-functions.md)
- [Mistake #4: Overusing getters and setters](references/mistake-04-overusing-getters-and-setters.md)
- [Mistake #5: Interface pollution](references/mistake-05-interface-pollution.md)
- [Mistake #6: Interface on the producer side](references/mistake-06-interface-on-the-producer-side.md)
- [Mistake #7: Returning interfaces](references/mistake-07-returning-interfaces.md)
- [Mistake #8: any says nothing](references/mistake-08-any-says-nothing.md)
- [Mistake #9: Being confused about when to use generics](references/mistake-09-being-confused-about-when-to-use-generics.md)
- [Mistake #10: Not being aware of the possible problems with type embedding](references/mistake-10-not-being-aware-of-the-possible-problems-with-type-embedding.md)
- [Mistake #11: Not using the functional options pattern](references/mistake-11-not-using-the-functional-options-pattern.md)
- [Mistake #12: Project misorganization](references/mistake-12-project-misorganization-project-structure-and-package-organization.md)
- [Mistake #13: Creating utility packages](references/mistake-13-creating-utility-packages.md)
- [Mistake #14: Ignoring package name collisions](references/mistake-14-ignoring-package-name-collisions.md)
- [Mistake #15: Missing code documentation](references/mistake-15-missing-code-documentation.md)
- [Mistake #16: Not using linters](references/mistake-16-not-using-linters.md)

### 2. Data Types
- [Mistake #17: Creating confusion with octal literals](references/mistake-17-creating-confusion-with-octal-literals.md)
- [Mistake #18: Neglecting integer overflows](references/mistake-18-neglecting-integer-overflows.md)
- [Mistake #19: Not understanding floating-points](references/mistake-19-not-understanding-floating-points.md)
- [Mistake #20: Not understanding slice length and capacity](references/mistake-20-not-understanding-slice-length-and-capacity.md)
- [Mistake #21: Inefficient slice initialization](references/mistake-21-inefficient-slice-initialization.md)
- [Mistake #22: Being confused about nil vs. empty slice](references/mistake-22-being-confused-about-nil-vs-empty-slice.md)
- [Mistake #23: Not properly checking if a slice is empty](references/mistake-23-not-properly-checking-if-a-slice-is-empty.md)
- [Mistake #24: Not making slice copies correctly](references/mistake-24-not-making-slice-copies-correctly.md)
- [Mistake #25: Unexpected side effects using slice append](references/mistake-25-unexpected-side-effects-using-slice-append.md)
- [Mistake #26: Slices and memory leaks](references/mistake-26-slices-and-memory-leaks.md)
- [Mistake #27: Inefficient map initialization](references/mistake-27-inefficient-map-initialization.md)
- [Mistake #28: Maps and memory leaks](references/mistake-28-maps-and-memory-leaks.md)
- [Mistake #29: Comparing values incorrectly](references/mistake-29-comparing-values-incorrectly.md)

### 3. Control Structures
- [Mistake #30: Ignoring that elements are copied in range loops](references/mistake-30-ignoring-that-elements-are-copied-in-range-loops.md)
- [Mistake #31: Ignoring how arguments are evaluated in range loops](references/mistake-31-ignoring-how-arguments-are-evaluated-in-range-loops-channels-and-arrays.md)
- [Mistake #32: Ignoring the impacts of using pointer elements in range loops](references/mistake-32-ignoring-the-impacts-of-using-pointer-elements-in-range-loops.md)
- [Mistake #33: Making wrong assumptions during map iterations](references/mistake-33-making-wrong-assumptions-during-map-iterations-ordering-and-map-insert-during-iteration.md)
- [Mistake #34: Ignoring how the break statement works](references/mistake-34-ignoring-how-the-break-statement-works.md)
- [Mistake #35: Using defer inside a loop](references/mistake-35-using-defer-inside-a-loop.md)

### 4. Strings
- [Mistake #36: Not understanding the concept of rune](references/mistake-36-not-understanding-the-concept-of-rune.md)
- [Mistake #37: Inaccurate string iteration](references/mistake-37-inaccurate-string-iteration.md)
- [Mistake #38: Misusing trim functions](references/mistake-38-misusing-trim-functions.md)
- [Mistake #39: Under-optimized strings concatenation](references/mistake-39-under-optimized-strings-concatenation.md)
- [Mistake #40: Useless string conversions](references/mistake-40-useless-string-conversions.md)
- [Mistake #41: Substring and memory leaks](references/mistake-41-substring-and-memory-leaks.md)

### 5. Functions and Methods
- [Mistake #42: Not knowing which type of receiver to use](references/mistake-42-not-knowing-which-type-of-receiver-to-use.md)
- [Mistake #43: Never using named result parameters](references/mistake-43-never-using-named-result-parameters.md)
- [Mistake #44: Unintended side effects with named result parameters](references/mistake-44-unintended-side-effects-with-named-result-parameters.md)
- [Mistake #45: Returning a nil receiver](references/mistake-45-returning-a-nil-receiver.md)
- [Mistake #46: Using a filename as a function input](references/mistake-46-using-a-filename-as-a-function-input.md)
- [Mistake #47: Ignoring how defer arguments and receivers are evaluated](references/mistake-47-ignoring-how-defer-arguments-and-receivers-are-evaluated.md)

### 6. Error Management
- [Mistake #48: Panicking](references/mistake-48-panicking.md)
- [Mistake #49: Ignoring when to wrap an error](references/mistake-49-ignoring-when-to-wrap-an-error.md)
- [Mistake #50: Comparing an error type inaccurately](references/mistake-50-comparing-an-error-type-inaccurately.md)
- [Mistake #51: Comparing an error value inaccurately](references/mistake-51-comparing-an-error-value-inaccurately.md)
- [Mistake #52: Handling an error twice](references/mistake-52-handling-an-error-twice.md)
- [Mistake #53: Not handling an error](references/mistake-53-not-handling-an-error.md)
- [Mistake #54: Not handling defer errors](references/mistake-54-not-handling-defer-errors.md)

### 7. Concurrency: Foundations
- [Mistake #55: Mixing up concurrency and parallelism](references/mistake-55-mixing-up-concurrency-and-parallelism.md)
- [Mistake #56: Thinking concurrency is always faster](references/mistake-56-thinking-concurrency-is-always-faster.md)
- [Mistake #57: Being puzzled about when to use channels or mutexes](references/mistake-57-being-puzzled-about-when-to-use-channels-or-mutexes.md)
- [Mistake #58: Not understanding race problems](references/mistake-58-not-understanding-race-problems-data-races-vs-race-conditions.md)
- [Mistake #59: Not understanding the concurrency impacts of a workload type](references/mistake-59-not-understanding-the-concurrency-impacts-of-a-workload-type.md)
- [Mistake #60: Misunderstanding Go contexts](references/mistake-60-misunderstanding-go-contexts.md)

### 8. Concurrency: Practice
- [Mistake #61: Propagating an inappropriate context](references/mistake-61-propagating-an-inappropriate-context.md)
- [Mistake #62: Starting a goroutine without knowing when to stop it](references/mistake-62-starting-a-goroutine-without-knowing-when-to-stop-it.md)
- [Mistake #63: Not being careful with goroutines and loop variables](references/mistake-63-not-being-careful-with-goroutines-and-loop-variables.md)
- [Mistake #64: Expecting a deterministic behavior using select and channels](references/mistake-64-expecting-a-deterministic-behavior-using-select-and-channels.md)
- [Mistake #65: Not using notification channels](references/mistake-65-not-using-notification-channels.md)
- [Mistake #66: Not using nil channels](references/mistake-66-not-using-nil-channels.md)
- [Mistake #67: Being puzzled about channel size](references/mistake-67-being-puzzled-about-channel-size.md)
- [Mistake #68: Forgetting about possible side effects with string formatting](references/mistake-68-forgetting-about-possible-side-effects-with-string-formatting.md)
- [Mistake #69: Creating data races with append](references/mistake-69-creating-data-races-with-append.md)
- [Mistake #70: Using mutexes inaccurately with slices and maps](references/mistake-70-using-mutexes-inaccurately-with-slices-and-maps.md)
- [Mistake #71: Misusing sync.WaitGroup](references/mistake-71-misusing-syncwaitgroup.md)
- [Mistake #72: Forgetting about sync.Cond](references/mistake-72-forgetting-about-synccond.md)
- [Mistake #73: Not using errgroup](references/mistake-73-not-using-errgroup.md)
- [Mistake #74: Copying a sync type](references/mistake-74-copying-a-sync-type.md)

### 9. Standard Library
- [Mistake #75: Providing a wrong time duration](references/mistake-75-providing-a-wrong-time-duration.md)
- [Mistake #76: time.After and memory leaks](references/mistake-76-timeafter-and-memory-leaks.md)
- [Mistake #77: JSON handling common mistakes](references/mistake-77-json-handling-common-mistakes.md)
- [Mistake #78: Common SQL mistakes](references/mistake-78-common-sql-mistakes.md)
- [Mistake #79: Not closing transient resources](references/mistake-79-not-closing-transient-resources-http-body-sqlrows-and-osfile.md)
- [Mistake #80: Forgetting the return statement after replying to an HTTP request](references/mistake-80-forgetting-the-return-statement-after-replying-to-an-http-request.md)
- [Mistake #81: Using the default HTTP client and server](references/mistake-81-using-the-default-http-client-and-server.md)

### 10. Testing
- [Mistake #82: Not categorizing tests](references/mistake-82-not-categorizing-tests-build-tags-environment-variables-and-short-mode.md)
- [Mistake #83: Not enabling the race flag](references/mistake-83-not-enabling-the-race-flag.md)
- [Mistake #84: Not using test execution modes](references/mistake-84-not-using-test-execution-modes-parallel-and-shuffle.md)
- [Mistake #85: Not using table-driven tests](references/mistake-85-not-using-table-driven-tests.md)
- [Mistake #86: Sleeping in unit tests](references/mistake-86-sleeping-in-unit-tests.md)
- [Mistake #87: Not dealing with the time API efficiently](references/mistake-87-not-dealing-with-the-time-api-efficiently.md)
- [Mistake #88: Not using testing utility packages](references/mistake-88-not-using-testing-utility-packages-httptest-and-iotest.md)
- [Mistake #89: Writing inaccurate benchmarks](references/mistake-89-writing-inaccurate-benchmarks.md)
- [Mistake #90: Not exploring all the Go testing features](references/mistake-90-not-exploring-all-the-go-testing-features---not-using-fuzzing.md)

### 11. Optimizations
- [Mistake #91: Not understanding CPU caches](references/mistake-91-not-understanding-cpu-caches.md)
- [Mistake #92: Writing concurrent code that leads to false sharing](references/mistake-92-writing-concurrent-code-that-leads-to-false-sharing.md)
- [Mistake #93: Not taking into account instruction-level parallelism](references/mistake-93-not-taking-into-account-instruction-level-parallelism.md)
- [Mistake #94: Not being aware of data alignment](references/mistake-94-not-being-aware-of-data-alignment.md)
- [Mistake #95: Not understanding stack vs. heap](references/mistake-95-not-understanding-stack-vs-heap.md)
- [Mistake #96: Not knowing how to reduce allocations](references/mistake-96-not-knowing-how-to-reduce-allocations.md)
- [Mistake #97: Not relying on inlining](references/mistake-97-not-relying-on-inlining.md)
- [Mistake #98: Not using Go diagnostics tooling](references/mistake-98-not-using-go-diagnostics-tooling.md)
- [Mistake #99: Not understanding how the GC works](references/mistake-99-not-understanding-how-the-gc-works.md)
- [Mistake #100: Not understanding the impacts of running Go in Docker and Kubernetes](references/mistake-100-not-understanding-the-impacts-of-running-go-in-docker-and-kubernetes.md)
