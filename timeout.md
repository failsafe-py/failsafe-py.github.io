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

Under `AsyncFailsafe` the awaiting attempt is interrupted, so the limit bounds the time actually spent. Under `Failsafe` it cannot be, and that difference is worth understanding before you rely on a sync timeout.

## Sync Timeouts Are Cooperative

Python cannot interrupt a running function. A sync `Timeout` checks the deadline *between* policy steps, so a call that blocks straight through simply runs to completion:

```python
Failsafe(Timeout(2.0)).call(time.sleep, 20)
```

That raises `TimeoutExceeded` — **after 20 seconds**. The limit decided what gets *reported*, not what gets *spent*: `time.sleep` offers no way to interrupt it, so nothing can cut it short. Worse, had the call returned a value at second 20, that value is discarded in favour of the timeout.

The same applies per attempt under a retry, so `Failsafe(retry, Timeout(2.0))` over a 20-second call takes 60 seconds for three attempts, not 6.

There is no flag that fixes this. Running the attempt on a worker thread would free the caller on time but leave the work running, still holding any [bulkhead][bulkheads] permit or connection it acquired — a bounded wait bought with an unbounded leak.

### a) The Workaround: `remaining()`

A sync timeout is real only if the callee enforces it. [`Execution.remaining()`][execution-info] is the seconds left before the deadline; pass it to whatever blocks:

```python
from failsafe import Failsafe, Timeout, current_execution

def fetch(url):
    return httpx.get(url, timeout=current_execution().remaining())

Failsafe(Timeout(2.0)).call(fetch, url)   # returns in ~2s
```

This works because `httpx` enforces the deadline — failsafe only supplies the number. Every sync I/O library in Python takes one:

| | |
|---|---|
| `httpx`, `requests` | `get(..., timeout=x)` |
| `socket` | `settimeout(x)` |
| `psycopg` | `connect(..., connect_timeout=x)` |
| `redis-py` | `Redis(socket_timeout=x)` |

`remaining()` returns `None` when no policy has set a deadline, so a callee that wants a fallback should write `current_execution().remaining() or 30`.

It is a *limited* workaround. It needs the callee to cooperate, which rules out code you do not control, C extensions, and pure-CPU work.

### b) Prefer Async for Anything More Involved

`AsyncFailsafe` has none of this. `asyncio.timeout` interrupts the attempt wherever it is awaiting, so the limit holds without the callee knowing it exists:

```python
await AsyncFailsafe(Timeout(2.0)).call(asyncio.sleep, 20)   # raises in ~2s
```

If you are composing timeouts with retries, hedges, or anything where bounded latency matters, async is the mode that delivers it. [Hedging][hedge] is async-only for the same underlying reason: it needs to cancel the attempts that lost.

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

A `TimeoutExceeded` is an ordinary failure, so an outer `RetryPolicy` can retry it. An [`asyncio.CancelledError`][cancelled-error] cannot: cancellation is terminal. Use a `Timeout` to bound execution time, and cancel the task to stop the execution outright.

## Event Listeners

A `Timeout` can notify you when an attempt exceeds the limit:

```python
Timeout(10.0, on_timeout=lambda e: logger.error("connection timed out"))
```

{% include common-links.html %}
