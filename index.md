---
layout: default
title: Fault tolerance and resilience patterns for Python
---

# Overview

failsafe-py is a library for building resilient, fault tolerant Python applications. It works by wrapping functions with one or more resilience [policies], which can be combined and [composed][policy-composition] as needed. Policies include:

- Failure handling: [Retry][retry], [Fallback][fallbacks]
- Load limiting: [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Bulkhead][bulkheads], [Rate Limiter][rate-limiters], [Cache][caches]
- Time limiting: [Timeout][timeouts], [Hedge][hedge]

Every policy works the same from sync and async code, and one policy instance can be shared between both.

{: .callout-unreleased }
> **Alpha.** failsafe-py is an agentic rewrite of [failsafe-go](https://failsafe-go.dev).
> API specifics may change, expect a stable 1.0 release before end of year.

## Getting Started

To see how failsafe-py works, we'll create a [retry policy][retry] that defines which failures to handle and when retries should be performed:

```python
from failsafe import Failsafe, RetryPolicy

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

### Asynchronous Execution

Executing a coroutine function [asynchronously][async-execution] *with* retries uses [`AsyncFailsafe`][AsyncFailsafe], which takes the same policy objects:

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

connection = Failsafe(fallback, retry, breaker, timeout).call(connect, host)
```

Order does matter when composing policies. See the [policy composition][policy-composition] overview for more details.

## Further Reading

Read more about [policies] and how they're used, then explore the rest in the site menu.

{% include common-links.html %}
