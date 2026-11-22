---
layout: default
title: Async Execution
---

# Async Execution
{: .no_toc }

1. TOC
{:toc}

`Failsafe` runs blocking code; `AsyncFailsafe` runs [asyncio] coroutines. They take the same policy objects and behave identically, differing only in how a delay or a permit wait is performed.

```python
from failsafe import AsyncFailsafe, RetryPolicy

retry = RetryPolicy(handle=ConnectionError, delay=1.0, max_retries=3)

connection = await AsyncFailsafe(retry).call(aconnect, host)
```

`AsyncFailsafe.call` takes a coroutine function and awaits it once per attempt. It is also a decorator, which produces a coroutine function:

```python
api = AsyncFailsafe(retry, breaker)

@api
async def fetch(url): ...
```

## It Is Just a Coroutine

`AsyncFailsafe.call` returns a coroutine, so everything asyncio offers works on it. There is no execution handle to learn:

```python
task = asyncio.create_task(AsyncFailsafe(retry).call(aconnect, host))

task.done()
await task
task.cancel()
```

Fan-out is whatever asyncio offers, not a bespoke API:

```python
async with asyncio.TaskGroup() as tg:
    for host in hosts:
        tg.create_task(api.call(aconnect, host))
```

## Sharing Policies Between Both Worlds

A policy can be used from `Failsafe` and `AsyncFailsafe` at the same time:

```python
breaker = CircuitBreaker(failure_threshold=5)

sync_payments = Failsafe(retry, breaker)
async_payments = AsyncFailsafe(retry, breaker)
```

A failure recorded through `sync_payments` opens the breaker for `async_payments` too, and a [`Bulkhead`][bulkheads], [`RateLimiter`][rate-limiters] or [`AdaptiveLimiter`][adaptive-limiters] shares one permit count across both.

## What Only Works in Async Mode

[Hedging][hedge] requires cancelling the losing attempts, which sync Python cannot do, so `HedgePolicy` under `Failsafe` raises `NotImplementedError`. Every other policy behaves identically in both modes.

{% include common-links.html %}
