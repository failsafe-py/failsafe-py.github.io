---
layout: default
title: Execution Info
---

# Execution Info

`current_execution()` returns an `Execution` containing execution related information such as the number of execution attempts, start and elapsed times, and the last result or exception:

```python
from failsafe import Failsafe, current_execution

def connect(host):
    logger.info("Connecting, attempt %d", current_execution().attempts)
    return do_connect(host)

Failsafe(retry).call(connect, host)
```

This is useful for executions that depend on a result from a previous attempt:

```python
def next_page(cursor):
    last = current_execution().last_result
    return api.page(after=last.cursor if last else cursor)
```

The `Execution` can also tell you if an execution is a retry, a hedge, or the first attempt:

```python
def connect(host):
    if current_execution().is_retry:
        logger.info("Retrying connection attempt")
    return do_connect(host)
```

It is a [contextvar][contextvars], so it is available from any function the execution calls, however deeply nested. Outside an execution it returns `None`.

## Deadlines

`remaining()` returns the seconds left before the execution's deadline, or `None` if none is set. Pass it to whatever does the I/O, so a [`Timeout`][timeouts] or a retry `max_duration` reaches your call:

```python
def connect(host):
    return socket.create_connection(host, timeout=current_execution().remaining())
```

{% include common-links.html %}
