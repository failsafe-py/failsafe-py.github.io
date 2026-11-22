---
layout: default
title: Circuit Breaker
---

# Circuit Breaker
{: .no_toc }

1. TOC
{:toc}

[Circuit breakers][fowler-circuit-breaker] are [load limiters][load-limiting] that temporarily disable execution when failures occur. failsafe-py supports two types: *count based* and *time based*. Count based breakers track recent execution results up to a certain limit. Time based breakers track any number of results that occur within a time period.

## Usage

Creating and using a `CircuitBreaker` is straightforward:

```python
from failsafe import CircuitBreaker, Failsafe

breaker = CircuitBreaker(
    handle=ConnectionError,
    failure_threshold=5,
    delay=60.0,
    success_threshold=2,
)

Failsafe(breaker).call(send_message)
```

## How it Works

When recent execution failures exceed a configured threshold, the breaker is *opened* and further executions fail with `CircuitBreakerOpen` without the function being called. After a delay the breaker becomes *half-open*, admitting trial executions that determine whether it should close or open again. If the trials meet the success threshold the breaker *closes*, otherwise it re-*opens*.

Half-open admits a **bounded** number of concurrent trials, capped at the success-thresholding capacity and refilled as results arrive. Without that cap, every caller that queued up during the delay is admitted at once and stampedes the service that is trying to recover.

## Configuration

### Failure Handling

A `CircuitBreaker` can be configured to handle only [certain results, exceptions, or conditions][failure-handling] as failures:

```python
CircuitBreaker(handle=[ConnectionError, Result(None)])
```

### Opening

A circuit breaker is *count based* by default and opens after a single failure. It can instead open when a number of successive executions have failed:

```python
CircuitBreaker(failure_threshold=5)
```

Or when, for example, 3 out of the last 5 executions have failed:

```python
from failsafe import Ratio

CircuitBreaker(failure_threshold=Ratio(3, 5))
```

A *time based* breaker opens when the failure rate over a minimum number of executions within a period exceeds a threshold:

```python
from failsafe import Rate

CircuitBreaker(failure_threshold=Rate(0.2, min_executions=5, period=60.0))
```

### Half-Opening

After opening, a breaker will delay for 1 minute by default before transitioning to half-open. You can configure a different delay, or a computed delay based on an execution result:

```python
CircuitBreaker(delay=30.0)
CircuitBreaker(delay=Fixed(60.0, jitter=Jitter(factor=0.2)))
CircuitBreaker(delay=failsafe.httpx.retry_after_delay)
```

When in an open state, you can also get the remaining delay, so that callers know how long to wait before retrying:

```python
breaker.remaining_delay()
```

### Closing

The breaker can be configured to close again if a number of trial executions succeed, else it re-opens:

```python
CircuitBreaker(success_threshold=5)
CircuitBreaker(success_threshold=Ratio(3, 5))
```

If no success threshold is configured, the failure threshold decides whether a half-open breaker closes or re-opens.

### Event Listeners

In addition to the standard [policy listeners][policy-listeners], a `CircuitBreaker` can notify you when its state changes:

```python
CircuitBreaker(
    on_state_change=lambda e: logger.info("breaker %s -> %s", e.previous_state, e.state),
    on_open=lambda e: alerts.page("breaker opened"),
    on_close=lambda e: logger.info("recovered"),
    on_half_open=lambda e: logger.info("probing"),
)
```

### Metrics

A `CircuitBreaker` exposes metrics for the state it is in. Properties: `state`, `is_open`, `is_closed`, `is_half_open`, `executions`, `successes`, `failures`. Methods, because each takes the breaker's lock to compute: `success_rate()`, `failure_rate()`, `remaining_delay()`.

```python
if breaker.is_open:
    metrics.gauge("breaker.remaining", breaker.remaining_delay())
```

## Standalone Usage

A `CircuitBreaker` can also be manually operated:

```python
breaker.open()
breaker.half_open()
breaker.close()

if breaker.try_acquire_permit():
    try:
        do_something()
    except Exception:
        breaker.record_failure()
        raise
    else:
        breaker.record_success()
```

## Best Practices

A `CircuitBreaker` can and *should* be shared across code that accesses a common dependency. This ensures that when the breaker opens, every execution that shares that dependency is blocked until the circuit closes again. If multiple connections or requests reach the same external server, they should all go through the same breaker. Construct it at module or DI scope — see [policy sharing][policy-sharing].

Sharing is safe across threads *and* across sync and async callers: a breaker tripped by a `Failsafe` call is seen open by an `AsyncFailsafe` call built from the same object.

### Composing Circuit Breakers

When [composing policies][policy-composition], it is recommended not to have a circuit breaker handle exceptions from other policies, such as `BulkheadFull` or `RateLimitExceeded`. If an execution is rejected by some policy, there is no need for a breaker to open as well. This makes it easier to reason about why a breaker opened, and avoids limiting load for longer than needed.

Note that the default `handle=Exception` *does* catch those, since they are ordinary exceptions. Narrow it when composing a breaker outside a limiting policy:

```python
Failsafe(CircuitBreaker(handle=ConnectionError), bulkhead)
```

{% include common-links.html %}
