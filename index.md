---
layout: default
title: Fault tolerance and resilience patterns for Python
---

# Overview

failsafe-py is a library for building resilient, fault tolerant Python applications. It works by wrapping functions with one or more resilience [policies], which can be combined and [composed][policy-composition] as needed. Policies include:

- Failure handling: [Retry][retry], [Fallback][fallbacks]
- Load limiting: [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Bulkhead][bulkheads], [Rate Limiter][rate-limiters], [Cache][caches]
- Time limiting: [Timeout][timeouts], [Hedge][hedge]

Every policy works the same from sync and async code, and **one policy instance can be shared between both**: a circuit breaker tripped by a thread is seen open by a coroutine.

failsafe-py is a port of [failsafe-go]. If you are coming from Go, start at [Porting from failsafe-go][porting].

## Installation

{: .callout-unreleased }
> **Not on PyPI yet.** failsafe-py is in development and has not been released. The
> commands below are what installation will look like; until then, install from
> [source][github].

```bash
pip install failsafe-py
```

The core has no runtime dependencies. [HTTP support][http] is an extra:

```bash
pip install 'failsafe-py[httpx]'
```

## Getting Started

To see how failsafe-py works, we'll create a [retry policy][retry] that defines which failures to handle and when retries should be performed:

```python
from failsafe import Failsafe, RetryPolicy

# Retry on ConnectionError up to 3 times with a 1 second delay between attempts
retry = RetryPolicy(handle=ConnectionError, delay=1.0, max_retries=3)
```

We can then get a result from a function *with* retries:

```python
connection = Failsafe(retry).call(connect, host)
```

Or use the same object as a decorator:

```python
resilient = Failsafe(retry)

@resilient
def connect(host): ...
```

There is one execution method, `call`, rather than Go's `Run`/`Get` pair: a Python function that returns nothing returns `None`, so no split is needed.

### Asynchronous Execution

Executing a coroutine function [asynchronously][async-execution] *with* retries uses `AsyncFailsafe`, which takes the same policy objects:

```python
from failsafe import AsyncFailsafe

connection = await AsyncFailsafe(retry).call(aconnect, host)
```

There is no async execution handle to learn: `asyncio.create_task` already provides one.

```python
task = asyncio.create_task(AsyncFailsafe(retry).call(aconnect, host))
connection = await task
```

### Composing Policies

Multiple [policies] can be composed to add additional layers of resilience or to handle different failures in different ways:

```python
from failsafe import CircuitBreaker, Fallback, Timeout

fallback = Fallback(value=backup_connection)
breaker = CircuitBreaker()
timeout = Timeout(10.0)

# Call with fallback, retries, circuit breaking, and a timeout
connection = Failsafe(fallback, retry, breaker, timeout).call(connect, host)
```

Order does matter when composing policies. See the [policy composition][policy-composition] overview for more details.

### Reusing a Composition

A `Failsafe` *is* the reusable composition — build it once and call it many times:

```python
payments = Failsafe(retry, breaker)

def charge(amount): return payments.call(_post, "/charge", amount)
def refund(txn):    return payments.call(_post, "/refund", txn)
```

This is not just a convenience. Stateful policies model the health of a *backend*, so writing `@Failsafe(RetryPolicy(), CircuitBreaker())` on twenty functions builds twenty independent breakers, each seeing a twentieth of the traffic. See [policy sharing][policy-sharing].

## Further Reading

Read more about [policies] and how they're used, then explore some of failsafe-py's other features in the site menu. Every policy's parameters are documented in its docstrings; a generated API reference is coming once the library is published.

{% include common-links.html %}
