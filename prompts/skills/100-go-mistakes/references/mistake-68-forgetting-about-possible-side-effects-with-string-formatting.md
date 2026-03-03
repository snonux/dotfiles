# Mistake #68: Forgetting about possible side effects with string formatting

#### TL;DR
TL;DR

Being aware that string formatting may lead to calling existing functions means watching out for possible deadlocks and other data races.

It’s pretty easy to forget the potential side effects of string formatting while working in a concurrent application.

etcd data race

github.com/etcd-io/etcd/pull/7816 shows an example of an issue where a map's key was formatted based on a mutable values from a context.

Deadlock

Can you see what the problem is in this code with a `Customer` struct exposing an `UpdateAge` method and implementing the `fmt.Stringer` interface?

type Customer struct {
    mutex sync.RWMutex // Uses a sync.RWMutex to protect concurrent accesses
    id    string
    age   int
}

func (c *Customer) UpdateAge(age int) error {
    c.mutex.Lock() // Locks and defers unlock as we update Customer
    defer c.mutex.Unlock()

    if age &lt; 0 { // Returns an error if age is negative
        return fmt.Errorf("age should be positive for customer %v", c)
    }

    c.age = age
    return nil
}

func (c *Customer) String() string {
    c.mutex.RLock() // Locks and defers unlock as we read Customer
    defer c.mutex.RUnlock()
    return fmt.Sprintf("id %s, age %d", c.id, c.age)
}

The problem here may not be straightforward. If the provided age is negative, we return an error. Because the error is formatted, using the `%s` directive on the receiver, it will call the `String` method to format `Customer`. But because `UpdateAge` already acquires the mutex lock, the `String` method won’t be able to acquire it. Hence, this leads to a deadlock situation. If all goroutines are also asleep, it leads to a panic.

One possible solution is to restrict the scope of the mutex lock:

func (c *Customer) UpdateAge(age int) error {
    if age &lt; 0 {
        return fmt.Errorf("age should be positive for customer %v", c)
    }

    c.mutex.Lock()
    defer c.mutex.Unlock()

    c.age = age
    return nil
}

Yet, such an approach isn't always possible. In these conditions, we have to be extremely careful with string formatting.

Another approach is to access the `id` field directly:

func (c *Customer) UpdateAge(age int) error {
    c.mutex.Lock()
    defer c.mutex.Unlock()

    if age &lt; 0 {
        return fmt.Errorf("age should be positive for customer id %s", c.id)
    }

    c.age = age
    return nil
}

In concurrent applications, we should remain cautious about the possible side effects of string formatting.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/68-string-formatting/main.go)
