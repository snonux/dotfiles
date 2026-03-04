# Mistake #61: Propagating an inappropriate context

#### TL;DR

Understanding the conditions when a context can be canceled should matter when propagating it: for example, an HTTP handler canceling the context when the response has been sent.

In many situations, it is recommended to propagate Go contexts. However, context propagation can sometimes lead to subtle bugs, preventing subfunctions from being correctly executed.

Let’s consider the following example. We expose an HTTP handler that performs some tasks and returns a response. But just before returning the response, we also want to send it to a Kafka topic. We don’t want to penalize the HTTP consumer latency-wise, so we want the publish action to be handled asynchronously within a new goroutine. We assume that we have at our disposal a `publish` function that accepts a context so the action of publishing a message can be interrupted if the context is canceled, for example. Here is a possible implementation:

func handler(w http.ResponseWriter, r *http.Request) {
    response, err := doSomeTask(r.Context(), r)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    return
    }
    go func() {
        err := publish(r.Context(), response)
        // Do something with err
    }()
    writeResponse(response)
}

What’s wrong with this piece of code? We have to know that the context attached to an HTTP request can cancel in different conditions:

* When the client’s connection closes
* In the case of an HTTP/2 request, when the request is canceled
* When the response has been written back to the client

In the first two cases, we probably handle things correctly. For example, if we get a response from doSomeTask but the client has closed the connection, it’s probably OK to call publish with a context already canceled so the message isn’t published. But what about the last case?

When the response has been written to the client, the context associated with the request will be canceled. Therefore, we are facing a race condition:

* If the response is written after the Kafka publication, we both return a response and publish a message successfully
* However, if the response is written before or during the Kafka publication, the message shouldn’t be published.

In the latter case, calling publish will return an error because we returned the HTTP response quickly.

#### TL;DR
Note

From Go 1.21, there is a way to create a new context without cancel. `context.WithoutCancel` returns a copy of parent that is not canceled when parent is canceled.

In summary, propagating a context should be done cautiously.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/61-inappropriate-context/main.go)
