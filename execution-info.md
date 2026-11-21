---
layout: default
title: Execution Info
---

# Execution Info
{: .no_toc }

1. TOC
{:toc}

`current_execution()` returns the `Execution` for the call in progress: attempt counts, timings, and the last result or exception.

```python
from failsafe import Failsafe, current_execution

def connect(host):
    ex = current_execution()
    logger.info("Connecting, attempt %d, elapsed %.1fs", ex.attempts, ex.elapsed)
    return do_connect(host)

Failsafe(retry).call(connect, host)
```

It is a [contextvar][contextvars], so it works from a nested helper several frames down without threading a parameter through every signature. Outside an execution it returns `None`.

## What It Carries

| Attribute | Meaning |
|---|---|
| `attempts` | Attempts started, including hedges |
| `executions` | Attempts that actually reached the function |
| `retries` | Retries performed so far |
| `hedges` | Hedged attempts started |
| `start_time` | When the execution began, on the configured clock |
| `elapsed` | Seconds since the execution began |
| `attempt_start_time` | When the current attempt began |
| `elapsed_attempt` | Seconds since the current attempt began |
| `last_result` | The previous attempt's result |
| `last_exception` | The previous attempt's exception |
| `args` / `kwargs` | The arguments the execution was called with |
| `is_first_attempt` | Whether this is the first attempt |
| `is_retry` | Whether this attempt is a retry |
| `is_hedge` | Whether this attempt is a hedge |
| `deadline` | The absolute deadline, if any policy set one |
| `remaining()` | Seconds left before the deadline, or `None` |

## Depending on a Previous Attempt

This is useful for executions that build on a previous attempt's result:

```python
def fetch_next(cursor):
    ex = current_execution()
    return api.page(after=ex.last_result.cursor if ex.last_result else cursor)
```

Or for branching on how the attempt was reached:

```python
def connect(host):
    if current_execution().is_retry:
        logger.info("Retrying connection attempt")
    return do_connect(host)
```

## Deadlines

`remaining()` is how a sync execution cooperates with a [`Timeout`][timeouts] or a retry `max_duration`. Size your own I/O timeout from it:

```python
def send(payload):
    return client.post(url, json=payload, timeout=current_execution().remaining())
```

It returns `None` when nothing has set a deadline. See [cancellation and deadlines][execution-cancellation].

## In Listeners

[Event listeners][event-listeners] receive an event that carries the execution, so the same information is available there:

```python
def on_retry(e):
    logger.warning("attempt %d failed after %.1fs: %s", e.attempts, e.elapsed, e.exception)

RetryPolicy(on_retry=on_retry)
```

## Async

Identical — `current_execution()` works in a coroutine, because contextvars are per-task:

```python
async def aconnect(host):
    ex = current_execution()
    async with asyncio.timeout(ex.remaining()):
        return await do_connect(host)
```

Concurrent tasks each see their own execution.

{% include common-links.html %}
