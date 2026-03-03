# Mistake #84: Not using test execution modes (parallel and shuffle)

#### TL;DR
TL;DR

Using the `-parallel` flag is an efficient way to speed up tests, especially long-running ones. Use the `-shuffle` flag to help ensure that a test suite doesn’t rely on wrong assumptions that could hide bugs.
