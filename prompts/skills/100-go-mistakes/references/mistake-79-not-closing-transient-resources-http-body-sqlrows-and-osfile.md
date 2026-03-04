# Mistake #79: Not closing transient resources (HTTP body, sql.Rows, and os.File)


Always close transient resources like HTTP response bodies, `sql.Rows`, and `os.File` to avoid leaks. Use `defer` after checking for errors.

Transient resources such as HTTP response bodies, `sql.Rows`, and `os.File` must be closed after use. Failing to do so can cause resource leaks—leaked file descriptors, connections held open, or memory not being freed.

* **HTTP body**: The response body must be closed even if you don't read it. Otherwise, the underlying TCP connection cannot be reused. Always defer `resp.Body.Close()` after the error check.
* **sql.Rows**: `sql.Rows` holds a database connection. If not closed, the connection is not returned to the pool, potentially exhausting available connections.
* **os.File**: Open file descriptors are a limited resource. Not closing them can lead to "too many open files" errors.

The idiomatic pattern is:

    resp, err := http.Get(url)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/79-closing-resources/)
