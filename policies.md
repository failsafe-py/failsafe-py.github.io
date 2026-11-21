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
from failsafe import Result

RetryPolicy(handle=ConnectionError)                    # one exception type
RetryPolicy(handle=(ConnectionError, TimeoutError))    # several
RetryPolicy(handle=Result(None))                       # a returned value
RetryPolicy(handle=lambda result, exc: result == 500)  # a condition
```

A sequence mixes all of them, and they are OR'ed:

```python
RetryPolicy(handle=[ConnectionError, Result(None), lambda r, e: r is not None and r.status_code >= 500])
```

The same `Condition` type is accepted wherever a policy asks "does this outcome match?": `abort=` on retries, `cancel_on=` on hedges, `cache_if=` on caches.

### Why `Result(...)` Is Explicit

`handle=None` would be ambiguous between "no condition configured" and "treat a returned `None` as a failure". Wrapping the value disambiguates it, which is what keeps `handle` from splitting into `handle=` and `handle_result=`.

### Results Do Not Replace Error Handling

A result-only condition **adds to** the default rather than replacing it. This policy retries both a `None` result and any exception:

```python
RetryPolicy(handle=Result(None))
```

Only a condition that handles exceptions replaces the default.

### Exception Chains

An exception matches if it is an instance of a handled type, or if any exception in its `__cause__` chain is. The chain is walked depth-limited and only through `__cause__` — explicit chaining — because walking `__context__` would match exceptions raised incidentally while handling something else. For an `ExceptionGroup`, any matching leaf matches.

## Policy Composition

Policies can be composed in any way desired, including multiple policies of the same type. Policies are composed around a function from left to right, like function composition, where the inner-most policy handles a function result first:

```python
Failsafe(fallback, retry, breaker, timeout).call(fn)
```

This results in the following composition when executing `fn` and handling its result:

```
Fallback(RetryPolicy(CircuitBreaker(Timeout(fn))))
```

A composition is fixed at construction. To add a layer, build a new one from the same policy objects — which is safe, because policies are shareable:

```python
base_policies = (fallback, retry)
plain = Failsafe(*base_policies)
guarded = Failsafe(*base_policies, breaker)
```

Both executors share `fallback` and `retry`, and `guarded` additionally applies `breaker`. There is no method that extends an executor in place, so a composition you hand to someone else cannot change under them.

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

A stateful policy models the health of a **backend**, not of a call site. Build the composition once, at module or DI scope, and reuse it:

```python
payments = Failsafe(retry, payments_breaker, payments_throttler)

def charge(amount): return payments.call(_post, "/charge", amount)
def refund(txn):    return payments.call(_post, "/refund", txn)

@payments
def status(txn): ...
```

### The Fragmentation Hazard

This is the mistake Python's decorator syntax makes easy:

```python
# wrong: twenty functions, twenty independent breakers
@Failsafe(RetryPolicy(), CircuitBreaker())
def charge(amount): ...

@Failsafe(RetryPolicy(), CircuitBreaker())
def refund(txn): ...
```

Each decorator builds its own breaker, so each sees a fraction of the traffic and none of them trips when the backend fails. No type checker can reject it — it is a valid constructor call — so it is a matter of discipline: hoist anything stateful.

A lazy factory does not fix it either. Sharing is about *how many* policy objects get built, not *when*.

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
