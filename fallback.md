---
layout: default
title: Fallback
---

# Fallback
{: .no_toc }

1. TOC
{:toc}

Fallbacks handle failed executions by providing an alternative result or exception.

## Usage

There are a few different options for creating a `Fallback`. You can provide an alternative result:

```python
from failsafe import Fallback

fallback = Fallback(value=default_result)
```

Or compute a different result or exception:

```python
fallback = Fallback(fn=lambda ex: connect_to_backup(backup_config))
```

The function receives the [execution][execution-info], whose `last_result` and `last_exception` describe the failure being handled. An exception it raises replaces the original.

Using a `Fallback` is simple:

```python
connection = Failsafe(fallback).call(connect)
```

## Configuration

### Failure Handling

A `Fallback` can be configured to handle only [certain results, exceptions, or conditions][failure-handling] as failures:

```python
Fallback(value=CACHED, handle=[ConnectionError, lambda result, exc: result is None])
```

By default *any* exception fires the fallback, including `RetriesExceeded`, `CircuitBreakerOpen` and `TimeoutExceeded` from inner policies. That is usually what you want from an outermost fallback, but narrow it if not:

```python
Fallback(value=CACHED, handle=(RetriesExceeded, CircuitBreakerOpen, TimeoutExceeded))
Fallback(value=CACHED, handle=FailsafeError)   # every policy exception, nothing else
```

When using a `Fallback` alongside another policy, it is common to configure both to handle the same failures.

### Event Listeners

In addition to the standard [policy event listeners][policy-listeners], a `Fallback` can notify you when it handles a failure:

```python
Fallback(
    value=CACHED,
    on_fallback=lambda e: logger.info("Fallback executed, result=%r", e.result),
)
```

{% include common-links.html %}
