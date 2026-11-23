---
layout: default
title: Bulkhead
---

# Bulkhead
{: .no_toc }

1. TOC
{:toc}

Bulkheads are [load limiters][load-limiting] that limit concurrent executions.

## Usage

Creating and using a [`Bulkhead`][Bulkhead] is simple:

```python
from failsafe import Bulkhead, Failsafe

bulkhead = Bulkhead(10)
Failsafe(bulkhead).call(send_request)
```

## How It Works

Executions are permitted until the bulkhead is full, meaning the max number of concurrent executions has been reached. Further executions either fail with [`BulkheadFull`][BulkheadFull] or wait until permitted.

## Configuration

### Waiting

By default, when the max concurrent executions are exceeded, further executions fail immediately with [`BulkheadFull`][BulkheadFull]. A bulkhead can also wait for permission if it can be acquired within a max wait time:

```python
bulkhead = Bulkhead(10, max_wait_time=1.0)
```

Fairness is guaranteed: waiting executions are permitted in the order they arrive. Actual wait times vary with how busy the bulkhead is, and since executions block while waiting, a `max_wait_time` should be chosen carefully to avoid excessive blocking.

Fairness holds **across sync and async callers**. One [`Bulkhead`][Bulkhead] instance serves threads and asyncio tasks from a single permit count and a single FIFO queue, so a task does not jump ahead of a thread that arrived first.

### Event Listeners

A [`Bulkhead`][Bulkhead] can notify you when it is full:

```python
Bulkhead(10, on_full=lambda e: logger.error("Bulkhead full"))
```

The listener does not run when an execution fails to acquire a permit for another reason, such as cancellation.

## Standalone Usage

A [`Bulkhead`][Bulkhead] can also be manually operated:

```python
if bulkhead.try_acquire_permit():
    try:
        do_something()
    finally:
        bulkhead.release_permit()
```

```python
bulkhead.acquire_permit(timeout=1.0)
await bulkhead.acquire_permit_async(timeout=1.0)
```

Standalone permit methods do not call `on_full`. That listener only applies to executions through Failsafe.

## Best Practices

A [`Bulkhead`][Bulkhead] can and *should* be shared across code that accesses a finite resource. This ensures that when the bulkhead is full, every execution reaching that resource waits or fails until permits free up. Construct it at module or DI scope — see [policy sharing][policy-sharing].

For a concurrency limit you do not have to guess, see [adaptive limiters][adaptive-limiters], which discover the limit instead of enforcing one you picked.

{% include common-links.html %}
