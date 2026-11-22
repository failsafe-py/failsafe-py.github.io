---
layout: default
title: Event Listeners
---

# Event Listeners
{: .no_toc }

1. TOC
{:toc}

failsafe-py supports event listeners on policies, configured as constructor keyword arguments.

## Policy Listeners

Policies that can be configured to handle specific results or exceptions, such as [RetryPolicy][retry], [CircuitBreaker][circuit-breakers], [AdaptiveThrottler][adaptive-throttlers], and [Fallback][fallbacks], provide event listeners that indicate when an execution attempt succeeds or fails according to that policy's [failure handling configuration][failure-handling]:

```python
RetryPolicy(
    on_success=lambda e: logger.info("Connected: %r", e.result),
    on_failure=lambda e: logger.error("Failed to create connection: %s", e.exception),
)
```

Additional listeners are available for different policies.

## Listeners Are Sync

Listeners are plain functions, not coroutines, in both sync and async executions. If a listener needs to do I/O, hand the work off:

```python
RetryPolicy(on_retry=lambda e: asyncio.get_running_loop().create_task(report(e)))
```

## Alternative Execution Results

Event listeners are meant for side effects such as logging and metrics. They do not influence the outcome of an execution. To provide an alternative execution result, use a [Fallback][fallbacks].

{% include common-links.html %}
