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

Under `AsyncFailsafe` the attempt is interrupted. Under `Failsafe` it is not: Python cannot interrupt a running call, so pass [`remaining()`][execution-info] to whatever does the I/O, or use `interrupt=True` to run the attempt on a worker thread and free the caller on time.

```python
Failsafe(Timeout(10.0, interrupt=True)).call(blocking_call)
```

{: .callout }
> With `interrupt=True` the caller is freed, but the abandoned thread runs to completion — Python has no way to kill a thread.

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
