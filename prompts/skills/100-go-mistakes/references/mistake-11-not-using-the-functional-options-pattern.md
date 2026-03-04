# Mistake #11: Not using the functional options pattern

#### TL;DR

To handle options conveniently and in an API-friendly manner, use the functional options pattern.

Although there are different implementations with minor variations, the main idea is as follows:

* An unexported struct holds the configuration: options.
* Each option is a function that returns the same type: `type Option func(options *options) error`. For example, `WithPort` accepts an `int` argument that represents the port and returns an `Option` type that represents how to update the `options` struct.

type options struct {
  port *int
}

type Option func(options *options) error

func WithPort(port int) Option {
  return func(options *options) error {
    if port < 0 {
      return errors.New("port should be positive")
    }
    options.port = &port
    return nil
  }
}

func NewServer(addr string, opts ...Option) ( *http.Server, error) {
  var options options
  for _, opt := range opts {
    err := opt(&options)
    if err != nil {
      return nil, err
    }
  }

  // At this stage, the options struct is built and contains the config
  // Therefore, we can implement our logic related to port configuration
  var port int
  if options.port == nil {
    port = defaultHTTPPort
  } else {
    if *options.port == 0 {
      port = randomPort()
    } else {
      port = *options.port
    }
  }

  // ...
}

The functional options pattern provides a handy and API-friendly way to handle options. Although the builder pattern can be a valid option, it has some minor downsides (having to pass a config struct that can be empty or a less handy way to handle error management) that tend to make the functional options pattern the idiomatic way to deal with these kind of problems in Go.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/02-code-project-organization/11-functional-options/)
