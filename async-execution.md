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

A policy object carries its own state and is safe to use from `Failsafe` and `AsyncFailsafe` at once. One `CircuitBreaker` guarding a backend sees every caller, whether that caller is a thread or a task:

```python
breaker = CircuitBreaker(failure_threshold=5)

sync_payments = Failsafe(retry, breaker)
async_payments = AsyncFailsafe(retry, breaker)
```

A failure recorded through `sync_payments` opens the breaker for `async_payments` too. The same holds for a [`Bulkhead`][bulkheads], [`RateLimiter`][rate-limiters] or [`AdaptiveLimiter`][adaptive-limiters]: one permit count serves both, with waiters admitted in arrival order regardless of which driver they came from.

This matters wherever a sync worker and an async service talk to the same backend, and it is the reason the library is built around one engine rather than two implementations.

## Cancellation

Async cancellation is ordinary asyncio cancellation. Cancelling the task cancels the in-flight attempt, and [`CancelledError`][cancelled-error] propagates out untouched — it is never treated as a retryable failure, never swallowed by a [`Fallback`][fallbacks], and never recorded by a breaker.

```python
task = asyncio.create_task(api.call(fetch, url))
task.cancel()

with contextlib.suppress(asyncio.CancelledError):
    await task
```

Sync mode has deadlines but no externally-triggered cancellation. See [cancellation and deadlines][execution-cancellation].

## What Only Works in Async Mode

- [Hedging][hedge] requires cancelling the losing attempts, which sync Python cannot do. `HedgePolicy` under `Failsafe` raises `NotImplementedError`.
- [`Timeout`][timeouts] interrupts the attempt itself, via [`asyncio.timeout`][asyncio-timeout]. In sync mode a timeout is cooperative unless `interrupt=True`, which frees the caller but leaves the abandoned thread running.

Everything else — retries, circuit breaking, rate limiting, bulkheads, adaptive limiting, throttling, fallbacks, caching, budgets — is identical in both modes.

## Listeners Are Sync

[Event listeners][event-listeners] are plain functions, not coroutines — a coroutine listener cannot be awaited from sync code. Listeners are for logging and metrics; if one needs to do I/O, hand the work to a task:

```python
retry = RetryPolicy(on_retry=lambda e: asyncio.get_running_loop().create_task(report(e)))
```

{% include common-links.html %}
