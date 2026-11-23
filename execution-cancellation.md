---
layout: default
title: Cancellation and Deadlines
---

# Cancellation and Deadlines
{: .no_toc }

1. TOC
{:toc}

Async executions can be cancelled. Sync executions have deadlines only.

## Async Cancellation

Cancelling the task cancels the execution:

```python
task = asyncio.create_task(AsyncFailsafe(retry).call(aconnect, host))
task.cancel()
```

[`CancelledError`][cancelled-error] propagates out untouched: no policy retries it, records it, or falls back for it.

Outstanding [hedge][hedge] executions are cancelled once a successful result arrives.

## Deadlines in Sync Mode

A sync execution sets a deadline; it is not cancelled from another thread. `current_execution().remaining()` is the seconds left before the nearest deadline — from a [`Timeout`][Timeout], a retry `max_duration`, or both — or `None` if none is set. Pass it to whatever does the I/O:

```python
from failsafe import current_execution

def connect(host):
    return socket.create_connection(host, timeout=current_execution().remaining())
```

The deadline is also enforced between attempts.

{% include common-links.html %}
