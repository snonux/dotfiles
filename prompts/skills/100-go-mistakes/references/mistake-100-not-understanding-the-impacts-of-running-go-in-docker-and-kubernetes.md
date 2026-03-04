# Mistake #100: Not understanding the impacts of running Go in Docker and Kubernetes


Be aware that `GOMAXPROCS` defaults to the number of OS-visible CPUs, not the container's CPU limit. Use libraries like `automaxprocs` to set it correctly based on cgroup limits.

When running Go applications in Docker or Kubernetes, several runtime behaviors can lead to performance issues:

* **GOMAXPROCS**: By default, `runtime.GOMAXPROCS` is set to the number of CPUs visible to the OS, not the container's CPU limit. For example, on a 64-core host with a container limited to 2 CPUs, Go will create 64 OS threads for scheduling. This leads to excessive context switching and reduced performance. Use `go.uber.org/automaxprocs` to automatically set `GOMAXPROCS` based on the cgroup CPU quota.

* **Memory limits**: Similarly, Go's GC doesn't natively know about container memory limits (prior to `GOMEMLIMIT` in Go 1.19). Without `GOMEMLIMIT`, the GC may allow heap growth beyond the container's memory limit, causing OOM kills.

* **Minimal Docker images**: Use multi-stage builds with `scratch` or `distroless` base images to reduce image size and attack surface. Remember to include CA certificates if making HTTPS calls.
