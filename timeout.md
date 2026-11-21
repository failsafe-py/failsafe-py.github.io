---
layout: default
title: Timeout
---

# Timeout
{: .no_toc }

1. TOC
{:toc}

Timeouts fail executions that take too long to complete, or limit load on systems.

## Usage

Creating and using a `Timeout` is simple:

```python
from failsafe import Failsafe, Timeout

Failsafe(Timeout(10.0)).call(connect)
Failsafe(Timeout(timedelta(seconds=10))).call(connect)
```

## How It Works

When the limit elapses, the execution and any policies composed *inside* the timeout fail with `TimeoutExceeded`.

How the attempt itself is affected:

| | Behaviour |
|---|---|
| `AsyncFailsafe` | The attempt is interrupted, via [`asyncio.timeout`][asyncio-timeout]. `CancelledError` is raised inside the coroutine and converted to `TimeoutExceeded` at the boundary |
| `Failsafe` | Cooperative by default. Python cannot interrupt a running call, so the limit is checked between attempts |
| `Failsafe`, `interrupt=True` | The attempt runs on a worker thread and the caller is freed on time |

### Cooperative Timeouts in Sync Mode

A sync function that blocks for a minute under a one-second timeout still blocks for a minute — the timeout is observed once it returns. To make a sync timeout effective, read the remaining budget and hand it to whatever does the I/O:

```python
from failsafe import current_execution

def connect(host):
    return socket.create_connection(host, timeout=current_execution().remaining())
```

This is the sync pattern throughout the library: deadlines, not cancellation. See [cancellation and deadlines][execution-cancellation].

### Interrupting Timeouts

`interrupt=True` runs the attempt on a worker thread, so the caller is released on time:

```python
Failsafe(Timeout(10.0, interrupt=True)).call(blocking_call)
```

{: .callout }
> The caller is freed, but **the abandoned thread runs to completion**. Python has no way to kill a thread. If the work it is doing is unbounded, this leaks a thread per timeout. Prefer passing `remaining()` into a real I/O timeout; use `interrupt=True` only when the call you wrap cannot accept one.

## Timeouts with Retries

When a `Timeout` is composed *outside* a [`RetryPolicy`][retry], the limit covers every attempt together, and a timeout ends the retries:

```python
Failsafe(Timeout(10.0), retry).call(connect)   # 10s for everything
```

When a `Timeout` is composed *inside* a `RetryPolicy`, each attempt gets its own limit, and a timeout does not stop the outer retries:

```python
Failsafe(retry, Timeout(10.0)).call(connect)   # 10s per attempt
```

A `TimeoutExceeded` is an ordinary failure, so an outer retry policy retries it by default.

## Timeout vs Cancellation

A `TimeoutExceeded` can be retried by an outer `RetryPolicy`. An `asyncio.CancelledError` cannot: cancellation is terminal, propagates untouched, and is never treated as a failure by any policy.

Prefer a `Timeout` when you want to bound execution time or combine it with retries. Cancel the task when you want the whole execution to stop.

A timeout overwrites an already-recorded inner result: outer policies may still be processing that result, and must be interrupted rather than allowed to finish with it.

## Event Listeners

A `Timeout` can notify you when an attempt exceeds the limit:

```python
Timeout(10.0, on_timeout=lambda e: logger.error("connection timed out"))
```

{% include common-links.html %}
