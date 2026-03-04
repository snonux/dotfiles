# Mistake #86: Sleeping in unit tests


Avoid sleeps using synchronization to make a test less flaky and more robust. If synchronization isn’t possible, consider a retry approach.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/86-sleeping/main_test.go)
