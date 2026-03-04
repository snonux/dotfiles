# Mistake #80: Forgetting the return statement after replying to an HTTP request


To avoid unexpected behaviors in HTTP handler implementations, make sure you don’t miss the `return` statement if you want a handler to stop after `http.Error`.

Consider the following HTTP handler that handles an error from `foo` using `http.Error`:

func handler(w http.ResponseWriter, req *http.Request) {
    err := foo(req)
    if err != nil {
        http.Error(w, "foo", http.StatusInternalServerError)
    }

    _, _ = w.Write([]byte("all good"))
    w.WriteHeader(http.StatusCreated)
}

If we run this code and `err != nil`, the HTTP response would be:

foo
all good

The response contains both the error and success messages, and also the first HTTP status code, 500. There would also be a warning log indicating that we attempted to write the status code multiple times:

2023/10/10 16:45:33 http: superfluous response.WriteHeader call from main.handler (main.go:20)

The mistake in this code is that `http.Error` does not stop the handler's execution, which means the success message and status code get written in addition to the error. Beyond an incorrect response, failing to return after writing an error can lead to the unwanted execution of code and unexpected side-effects. The following code adds the `return` statement following the `http.Error` and exhibits the desired behavior when ran:

func handler(w http.ResponseWriter, req *http.Request) {
    err := foo(req)
    if err != nil {
        http.Error(w, "foo", http.StatusInternalServerError)
        return // Adds the return statement
    }

    _, _ = w.Write([]byte("all good"))
    w.WriteHeader(http.StatusCreated)
}

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/80-http-return/main.go)
