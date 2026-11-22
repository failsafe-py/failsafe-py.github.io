---
layout: default
title: Policies
---

# Policies
{: .no_toc }

1. TOC
{:toc}

failsafe-py provides numerous resilience policies. While each policy handles failures in different ways, some of their common features are described below.

## Failure Handling

Policies add resilience by detecting failures and handling them. Each policy determines which execution results, exceptions, or conditions represent a failure and how to handle them.

Some policies, such as [Retry][retry], [Circuit Breaker][circuit-breakers], [Adaptive Throttler][adaptive-throttlers], and [Fallback][fallbacks], let you specify what to handle as a failure through a single `handle` parameter. By default these policies treat any `Exception` as a failure. They can be configured to handle more specific exception types, results, or conditions:

```python
RetryPolicy(handle=ConnectionError)                    # an exception type
RetryPolicy(handle=(ConnectionError, TimeoutError))    # several
RetryPolicy(handle=None)                               # a returned value
RetryPolicy(handle="unavailable")                      # any value, matched with ==
RetryPolicy(handle=lambda result, exc: result == 500)  # a condition
```

A list mixes all of them, and they are OR'ed:

```python
RetryPolicy(handle=[ConnectionError, lambda r, e: r is not None and r.status_code >= 500])
```

The same conditions are accepted wherever a policy asks "does this outcome match?": `abort=` on retries, `cancel_on=` on hedges, `cache_if=` on caches.

### Matching an Awkward Value

A bare value works wherever it is unambiguous. Where it is not, write a predicate — inside a list, which already means "any of these conditions", or when the value is itself a tuple, a list, or callable:

```python
RetryPolicy(handle=[ConnectionError, lambda result, exc: result == "unavailable"])
RetryPolicy(handle=lambda result, exc: result == (1, 2))
```

A list containing a bare value, and an empty list, both raise `TypeError` rather than guessing.

### Results Do Not Replace Error Handling

A result condition **adds to** the default rather than replacing it. This policy retries both a `None` result and any exception:

```python
RetryPolicy(handle=None)
```

Only a condition that handles exceptions replaces the default.

### Exception Chains

An exception matches if it is an instance of a handled type, or if any exception in its `__cause__` chain is. Only `__cause__` is followed — explicit `raise ... from` chaining — because walking `__context__` would match exceptions raised incidentally while handling something else. For an `ExceptionGroup`, any matching leaf matches.

Policies chain the failure they wrap, so an outer policy matches the original exception without naming the policy exception:

```python
# matches a ConnectionError that an inner RetryPolicy exhausted its attempts on
Fallback(value=CACHED, handle=ConnectionError)
```

## Policy Composition

Policies can be composed in any way desired, including multiple policies of the same type. Policies are composed around a function from left to right, like function composition, where the inner-most policy handles a function result first:

```python
Failsafe(fallback, retry, breaker, timeout).call(fn)
```

This results in the following composition when executing `fn` and handling its result:

```
Fallback(RetryPolicy(CircuitBreaker(Timeout(fn))))
```

A composition is fixed at construction. To add a layer, build a new one from the same policy objects:

```python
base_policies = (fallback, retry)
plain = Failsafe(*base_policies)
guarded = Failsafe(*base_policies, breaker)
```

### Executing a Policy Composition

Execution begins with the outer-most policy. That policy in turn calls the next inner policy, and so on, until the user-provided function is reached. A result or exception travels back out through the policy layers, handled if needed by any policy along the way.

Each policy makes its own decision to allow an execution attempt to proceed and how to handle a result. A `RetryPolicy` may retry, which calls the next inner policy again, or it may return. A `CircuitBreaker` may raise before an attempt even reaches the function.

### Example Execution

Consider an execution of the following policy composition:

<img class="composition" src="{{ '/assets/images/composition.svg' | relative_url }}" alt="Sequence diagram of a Fallback, RetryPolicy and CircuitBreaker composition">

- `call` invokes the `Fallback`
- `Fallback` calls the `RetryPolicy`
- `RetryPolicy` calls the `CircuitBreaker`
- `CircuitBreaker` raises `CircuitBreakerOpen` if the breaker is open, else calls the function
- the function executes and returns a result or raises
- `CircuitBreaker` records the outcome as a success or failure, based on its [configuration](#failure-handling), possibly changing state, then returns
- `RetryPolicy` records the outcome as a success or failure, and either retries or returns
- `Fallback` handles the outcome according to its configuration and produces a fallback result if needed
- `call` returns the final result, or raises

### Composition and Exception Handling

While policies handle all `Exception` instances by default, it is common to configure a policy to handle something more specific, as [described above](#failure-handling):

```python
RetryPolicy(handle=ConnectionError)
```

When doing so for a policy composed *around* other policies, you may also want it to handle the exceptions those inner policies raise:

```python
Fallback(value=CACHED, handle=(RetriesExceeded, CircuitBreakerOpen, TimeoutExceeded))
```

Every policy exception derives from `FailsafeError`, so `handle=FailsafeError` catches all of them at once.

### Composition Recommendations

A common ordering places a `Fallback` outermost, followed by a `CachePolicy`, a `RetryPolicy` or `HedgePolicy`, a `CircuitBreaker`, `AdaptiveLimiter`, `AdaptiveThrottler` or `RateLimiter`, a `Bulkhead`, and a `Timeout` innermost:

```python
Failsafe(fallback, cache, retry, breaker, bulkhead, timeout)
```

That said, it really depends on how the policies are being used, and different compositions make sense for different use cases.

## Policy Sharing

All policies are safe to share across executions, across threads, and between `Failsafe` and `AsyncFailsafe`. Some policies such as [Retry][retry] are stateless; others such as [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Rate Limiter][rate-limiters] and [Bulkhead][bulkheads] are stateful and are *meant* to be shared across executions that reach the same resource.

A stateful policy models the health of a resource, not of a call site. Build the composition once and reuse it:

```python
payments = Failsafe(retry, payments_breaker, payments_throttler)

def charge(amount): return payments.call(_post, "/charge", amount)
def refund(txn):    return payments.call(_post, "/refund", txn)

@payments
def status(txn): ...
```

### Decorator Pitfall

Watch out for the following:

```python
@Failsafe(RetryPolicy(), CircuitBreaker())
def charge(amount): ...

@Failsafe(RetryPolicy(), CircuitBreaker())
def refund(txn): ...
```

In this case each decorator builds its own breaker, and each only sees a
fraction of the traffic. You probably want to share policies per set of common
backends:

```python
_shared = Failsafe(RetryPolicy(), CircuitBreaker())

@_shared
def charge(amount): ...

@_shared
def refund(txn): ...
```


## Supported Policies

Read about the built-in policies that failsafe-py supports:

- [Retry][retry]
- [Circuit Breaker][circuit-breakers]
- [Adaptive Limiter][adaptive-limiters]
- [Adaptive Throttler][adaptive-throttlers]
- [Rate Limiter][rate-limiters]
- [Timeout][timeouts]
- [Fallback][fallbacks]
- [Hedge][hedge]
- [Bulkhead][bulkheads]
- [Cache][caches]

{% include common-links.html %}
