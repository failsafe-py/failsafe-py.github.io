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

# Opens after 5 failures, half-opens after 1 minute, closes after 2 successes
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

# 20% of at least 5 executions in the last minute
CircuitBreaker(failure_threshold=Rate(0.2, min_executions=5, period=60.0))
```

One `Rate` covers both of Go's `WithFailureThresholdPeriod` and `WithFailureRateThreshold`: a count over a period is a rate.

### Half-Opening

After opening, a breaker delays for 1 minute by default before transitioning to half-open. You can configure a different delay, using the same forms a [retry delay][retry] accepts:

```python
CircuitBreaker(delay=30.0)
CircuitBreaker(delay=Fixed(60.0, jitter=Jitter(factor=0.2)))
CircuitBreaker(delay=failsafe.httpx.retry_after_delay)
```

{: .callout }
> A callable `delay=` yields no delay for a manual `breaker.open()`, which has no execution to compute from. Go keeps `DelayFunc` and `Delay` in separate fields so one can fall back to the other; a single `delay=` union has nothing to fall back to.

While open, you can read the remaining delay, so callers know how long to wait:

```python
breaker.remaining_delay
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

A `CircuitBreaker` exposes metrics for the state it is in: `state`, `is_open`, `is_closed`, `is_half_open`, `executions`, `successes`, `failures`, `success_rate`, `failure_rate`, and `remaining_delay`.

```python
if breaker.is_open:
    metrics.gauge("breaker.remaining", breaker.remaining_delay)
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

`record(outcome)` records an `Outcome` judged by the breaker's own `handle` condition, which is what the executor uses.

## Best Practices

A `CircuitBreaker` can and *should* be shared across code that accesses a common dependency. This ensures that when the breaker opens, every execution that shares that dependency is blocked until the circuit closes again. If multiple connections or requests reach the same external server, they should all go through the same breaker. Construct it at module or DI scope — see [policy sharing][policy-sharing].

Sharing is safe across threads *and* across drivers: a breaker tripped by a `Failsafe` call is seen open by an `AsyncFailsafe` call built from the same object.

### Composing Circuit Breakers

When [composing policies][policy-composition], it is recommended not to have a circuit breaker handle exceptions from other policies, such as `BulkheadFull` or `RateLimitExceeded`. If an execution is rejected by some policy, there is no need for a breaker to open as well. This makes it easier to reason about why a breaker opened, and avoids limiting load for longer than needed.

Note that the default `handle=Exception` *does* catch those, since they are ordinary exceptions. Narrow it when composing a breaker outside a limiting policy:

```python
Failsafe(CircuitBreaker(handle=ConnectionError), bulkhead)
```

## Additional Details

### Time Based Resolution

Time based breakers use a sliding window to aggregate results. As time progresses and newer results are recorded, older ones are discarded. To stay space and time efficient, results are grouped into 10 time slices, each 1/10th of the configured period; when a slice falls outside the period its results are discarded.

Buckets expire on **write** only, matching Go. A window nobody has written to still reports its last totals, rather than silently draining as time passes.

### Performance

The internal implementation uses a single circular structure to record results. Recording an execution and evaluating a threshold is _O(1)_, regardless of the thresholding capacity. The state is guarded by a lock held for microseconds, which is what lets one instance serve sync and async callers at once.

{% include common-links.html %}
