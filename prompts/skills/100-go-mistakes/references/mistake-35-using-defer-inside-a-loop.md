# Mistake #35: Using defer inside a loop

#### TL;DR

A `defer` call is executed not during each loop iteration but when the surrounding function returns. Be cautious about using `defer` inside loops; extract the loop body into a function to ensure `defer` executes per iteration.

The `defer` statement delays a call's execution until the surrounding function returns. One common mistake with `defer` is to forget that it schedules a function call when the surrounding function returns, not when the current block or iteration completes. For example:

    func readFiles(ch <-chan string) error {
        for path := range ch {
            file, err := os.Open(path)
            if err != nil {
                return err
            }
            defer file.Close()
            // Do something with file
        }
        return nil
    }

The `defer` calls are executed not during each loop iteration but when the `readFiles` function returns. If `readFiles` doesn't return, the file descriptors will be kept open forever, causing leaks.

One common option to fix this problem is to create a surrounding function after `defer`, called during each iteration:

    func readFiles(ch <-chan string) error {
        for path := range ch {
            if err := readFile(path); err != nil {
                return err
            }
        }
        return nil
    }

    func readFile(path string) error {
        file, err := os.Open(path)
        if err != nil {
            return err
        }
        defer file.Close()
        // Do something with file
        return nil
    }

Another solution is to make the `readFile` function a closure but intrinsically, this remains the same solution: adding another surrounding function to execute the `defer` calls during each iteration.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/35-defer-loop/main.go)
