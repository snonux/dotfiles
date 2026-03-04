# Mistake #32: Ignoring the impacts of using pointer elements in range loops


When iterating over a data structure using a range loop and storing the pointer of each element, be aware that all pointers will point to the same element: the last one. Use a local variable or index access instead.

When using a range loop with pointer elements, a common mistake is to store pointers to the loop variable. Since the loop variable is reused across iterations, all stored pointers end up referencing the same (last) element. To fix this, create a local copy within the loop or access elements by index.

    s := []int{1, 2, 3}
    var ptrs []*int
    for _, v := range s {
        v := v // Create a local copy
        ptrs = append(ptrs, &v)
    }

Note: As of Go 1.22, the loop variable is redefined per iteration, which eliminates this issue in newer Go versions.
