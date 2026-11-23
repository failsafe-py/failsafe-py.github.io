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

Creating and using a [`Timeout`][Timeout] is simple:

```python
from failsafe import Failsafe, Timeout

Failsafe(Timeout(10.0)).call(connect)
Failsafe(Timeout(timedelta(seconds=10))).call(connect)
```

## How It Works

When the limit elapses, the execution and any policies composed *inside* the timeout fail with [`TimeoutExceeded`][TimeoutExceeded].

Under [`AsyncFailsafe`][AsyncFailsafe] the awaiting attempt is interrupted, so the limit bounds the time actually spent. Under [`Failsafe`][Failsafe] it cannot be, and that difference is worth understanding before you rely on a sync timeout.

## Warning regarding Sync Timeouts

_This section does not apply to Async users._

Python cannot interrupt a running function. A sync [`Timeout`][Timeout] checks the deadline *between* policy steps, so a call that blocks straight through simply runs to completion. Example:

```python
Failsafe(Timeout(2.0)).call(time.sleep, 20)
```

That waits 20 seconds and then raises [`TimeoutExceeded`][TimeoutExceeded].


### 1. Using httpx? It already works

The [httpx transport][http] hands the remaining budget to httpx on every attempt, so the deadline bounds the round trip with nothing to wire up:

```python
client = httpx.Client(transport=FailsafeTransport(Timeout(2.0)))
client.get(url)   # fails in ~2s even against a server that never replies
```

### 2. Otherwise, pass `remaining()` yourself

[`Execution.remaining()`][execution-info] is the seconds left before the deadline. Hand it to whatever blocks, and the limit becomes real because *that* library enforces it:

```python
from failsafe import Failsafe, Timeout, current_execution

def connect(host):
    return socket.create_connection(host, timeout=current_execution().remaining())

Failsafe(Timeout(2.0)).call(connect, host)   # returns in ~2s
```

Every sync I/O library in Python takes one:

| | |
|---|---|
| `httpx`, `requests` | `get(..., timeout=x)` |
| `socket` | `settimeout(x)` |
| `psycopg` | `connect(..., connect_timeout=x)` |
| `redis-py` | `Redis(socket_timeout=x)` |

`remaining()` returns `None` when no policy has set a deadline, so a callee that wants a fallback should write `current_execution().remaining() or 30`.

It is a *limited* workaround. It needs the callee to cooperate, which rules out code you do not control, C extensions, and pure-CPU work.

### 3. Prefer Async for Anything More Involved

[`AsyncFailsafe`][AsyncFailsafe] just works. Async Python will be a lot easier to write. `asyncio.timeout` interrupts the attempt wherever it is awaiting, so the limit holds without the callee knowing it exists:

```python
await AsyncFailsafe(Timeout(2.0)).call(asyncio.sleep, 20)   # raises in ~2s
```

If you are composing timeouts with retries, hedges, or anything where bounded latency matters, async is the mode that delivers it. [Hedging][hedge] is async-only for the same underlying reason: it needs to cancel the attempts that lost.

## Timeouts with Retries

When a [`Timeout`][Timeout] is composed *outside* a [`RetryPolicy`][RetryPolicy], the limit covers every attempt together, and a timeout ends the retries:

```python
Failsafe(Timeout(10.0), retry).call(connect)   # 10s for everything
```

When a [`Timeout`][Timeout] is composed *inside* a [`RetryPolicy`][RetryPolicy], each attempt gets its own limit, and a timeout does not stop the outer retries:

```python
Failsafe(retry, Timeout(10.0)).call(connect)   # 10s per attempt
```

A [`TimeoutExceeded`][TimeoutExceeded] is an ordinary failure, so an outer retry policy retries it by default.

## Timeout vs Cancellation

A [`TimeoutExceeded`][TimeoutExceeded] is an ordinary failure, so an outer [`RetryPolicy`][RetryPolicy] can retry it. An [`asyncio.CancelledError`][cancelled-error] cannot: cancellation is terminal. Use a [`Timeout`][Timeout] to bound execution time, and cancel the task to stop the execution outright.

## Event Listeners

A [`Timeout`][Timeout] can notify you when an attempt exceeds the limit:

```python
Timeout(10.0, on_timeout=lambda e: logger.error("connection timed out"))
```

{% include common-links.html %}
