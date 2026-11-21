---
layout: default
title: Cancellation and Deadlines
---

# Cancellation and Deadlines
{: .no_toc }

1. TOC
{:toc}

The two drivers differ here more than anywhere else. Async mode has real cancellation; sync mode has deadlines only.

| | Async | Sync |
|---|---|---|
| Deadline from a [`Timeout`][timeouts] | Interrupts the attempt | Cooperative, or a worker thread with `interrupt=True` |
| Deadline from `max_duration` | Enforced between attempts | Enforced between attempts |
| Externally triggered cancellation | `task.cancel()` | **Not supported** |
| Reaching downstream code | Cancellation propagates for free | Pass `remaining()` to your I/O |

## Async Cancellation

Async cancellation is ordinary asyncio cancellation — there is nothing library-specific to learn:

```python
task = asyncio.create_task(AsyncFailsafe(retry).call(aconnect, host))
task.cancel()
```

[`CancelledError`][cancelled-error] propagates out untouched. No policy retries it, records it, or substitutes a fallback for it; the core catches `Exception`, never `BaseException`. A cancelled task is not a failing backend.

A [`Timeout`][timeouts] in async mode interrupts the attempt via [`asyncio.timeout`][asyncio-timeout] and surfaces as `TimeoutExceeded`, which *is* an ordinary failure and can be retried by an outer [`RetryPolicy`][retry]. That distinction is the whole reason `Timeout` exists alongside cancellation.

Outstanding [hedge][hedge] executions are cancelled once a successful result arrives.

## Deadlines in Sync Mode

Sync code sets a deadline; it does not get cancelled from another thread.

```python
from failsafe import current_execution

def connect(host):
    return socket.create_connection(host, timeout=current_execution().remaining())
```

`remaining()` returns the seconds left before the nearest deadline — from a `Timeout`, a retry `max_duration`, or both — or `None` when nothing has set one. Between attempts the driver enforces the deadline itself; *within* an attempt, cooperation is yours, which is what the snippet above does.

### Why There Is No Sync Cancellation

`Execution` deliberately has no `cancelled` attribute, and Go's `exec.IsCanceled()` and `exec.Canceled()` have no equivalent.

Python cannot interrupt a running call, so a cancellation channel would only work if downstream code polled it. No mainstream sync library accepts one: `requests`, `urllib` and the DB-API drivers all take a *timeout*. A `threading.Event` on the execution would be API surface that nothing cooperates with, and it would look like a cancellation guarantee while providing none. Removing the concept is more honest than faking it.

### Interrupting Timeouts

`Timeout(..., interrupt=True)` is the escape hatch when the call you wrap accepts no timeout of its own:

```python
Failsafe(Timeout(10.0, interrupt=True)).call(blocking_call)
```

The caller is freed on time. The abandoned worker thread runs to completion — Python has no way to kill a thread — so this bounds *caller latency*, not resource use. Prefer a real I/O timeout where one exists.

## Propagating Cancellation Downstream

In async mode, propagation is free. Cancelling the task cancels whatever it is awaiting, including an in-flight [httpx][http] request:

```python
transport = AsyncFailsafeTransport(retry_policy(), timeout_policy)
client = httpx.AsyncClient(transport=transport)
```

In sync mode, propagate the deadline instead:

```python
def get(url):
    return client.get(url, timeout=current_execution().remaining())
```

## Timeout vs Cancellation

A `TimeoutExceeded` can be retried by an outer `RetryPolicy`; a `CancelledError` cannot. Prefer a `Timeout` when you want to bound execution time or combine it with retries, and cancel the task when you want the whole execution to stop.

{% include common-links.html %}
