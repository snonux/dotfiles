# Mistake #70: Using mutexes inaccurately with slices and maps

#### TL;DR
TL;DR

Remembering that slices and maps are pointers can prevent common data races.

Let's implement a `Cache` struct used to handle caching for customer balances. This struct will contain a map of balances per customer ID and a mutex to protect concurrent accesses:

type Cache struct {
    mu       sync.RWMutex
    balances map[string]float64
}

Next, we add an `AddBalance` method that mutates the `balances` map. The mutation is done in a critical section (within a mutex lock and a mutex unlock):

func (c *Cache) AddBalance(id string, balance float64) {
    c.mu.Lock()
    c.balances[id] = balance
    c.mu.Unlock()
}

Meanwhile, we have to implement a method to calculate the average balance for all the customers. One idea is to handle a minimal critical section this way:

func (c *Cache) AverageBalance() float64 {
    c.mu.RLock()
    balances := c.balances // Creates a copy of the balances map
    c.mu.RUnlock()

    sum := 0.
    for _, balance := range balances { // Iterates over the copy, outside of the critical section
        sum += balance
    }
    return sum / float64(len(balances))
}

What's the problem with this code?

If we run a test using the `-race` flag with two concurrent goroutines, one calling `AddBalance` (hence mutating balances) and another calling `AverageBalance`, a data race occurs. What’s the problem here?

Internally, a map is a `runtime.hmap` struct containing mostly metadata (for example, a counter) and a pointer referencing data buckets. So, `balances := c.balances` doesn’t copy the actual data. Therefore, the two goroutines perform operations on the same data set, and one mutates it. Hence, it's a data race.

One possible solution is to protect the whole `AverageBalance` function:

func (c *Cache) AverageBalance() float64 {
    c.mu.RLock()
    defer c.mu.RUnlock() // Unlocks when the function returns

    sum := 0.
    for _, balance := range c.balances {
        sum += balance
    }
    return sum / float64(len(c.balances))
}

Another option, if the iteration operation isn’t lightweight, is to work on an actual copy of the data and protect only the copy:

func (c *Cache) AverageBalance() float64 {
    c.mu.RLock()
    m := maps.Clone(c.balances)
    c.mu.RUnlock()

    sum := 0.
    for _, balance := range m {
        sum += balance
    }
    return sum / float64(len(m))
}

Once we have made a deep copy, we release the mutex. The iterations are done on the copy outside of the critical section.

In summary, we have to be careful with the boundaries of a mutex lock. In this section, we have seen why assigning an existing map (or an existing slice) to a map isn’t enough to protect against data races. The new variable, whether a map or a slice, is backed by the same data set. There are two leading solutions to prevent this: protect the whole function, or work on a copy of the actual data. In all cases, let’s be cautious when designing critical sections and make sure the boundaries are accurately defined.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/70-mutex-slices-maps/main.go)
