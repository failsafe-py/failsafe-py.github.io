---
layout: default
title: Adaptive Throttler
---

# Adaptive Throttler
{: .no_toc }

1. TOC
{:toc}

Adaptive throttlers are probabilistic load shedders that limit load based on recent failures, as described in the [Google SRE Book][throttling].

## Usage

```python
from failsafe import AdaptiveThrottler, Failsafe

# Starts rejecting at 10% failures per minute, after 5 executions, up to 90% max rejections
throttler = AdaptiveThrottler(
    handle=ConnectionError,
    failure_rate_threshold=0.1,
    execution_threshold=5,
    thresholding_period=60.0,
    max_rejection_rate=0.9,
)

response = Failsafe(throttler).call(fetch_data)
```

## How it Works

Adaptive throttlers track recent failures over a time period. When the recent failure rate exceeds the configured threshold, the throttler starts probabilistically rejecting executions. The rejection rate increases with how far over the threshold the failure rate is, stopping at the max rate. Rejected executions fail with `ThrottleExceeded`.

## Policy Comparison

Adaptive throttlers are similar to [circuit breakers][circuit-breakers] in that both limit load based on recent failures. But where a circuit breaker rejects *all* executions for a period, a throttler rejects *some*, in proportion to the damage. Execution flows stay smoother, and a recovering backend is detected sooner because probe traffic never stops.

## Configuration

### Failure Handling

An `AdaptiveThrottler` can be configured to handle only [certain results, exceptions, or conditions][failure-handling] as failures:

```python
AdaptiveThrottler(handle=[ConnectionError, Result(None)])
```

Unlike a [retry policy][retry], a throttler takes no `abort`; Go's throttler builder exposes none either.

### Failure Rate Threshold

The threshold is the failure rate over a period, with a minimum number of executions, before executions start being rejected:

```python
# Starts rejecting at 10% failures per minute, after 10 executions
AdaptiveThrottler(failure_rate_threshold=0.1, execution_threshold=10, thresholding_period=60.0)
```

The execution threshold matters: without it a single early failure in a quiet period would throttle a healthy resource.

### Max Rejection Rate

The max rejection rate defaults to `0.9`:

```python
# Reject up to 75% of executions
AdaptiveThrottler(max_rejection_rate=0.75)
```

Use a value below 1. Maintaining some flow of executions is what lets the throttler detect that an overloaded system has recovered.

### Execution Prioritization

Adaptive throttlers can decide which executions to reject by priority, rejecting lower priority executions before higher ones. See [execution prioritization][execution-prioritization]:

```python
from failsafe import throttle_prioritizer

throttler = AdaptiveThrottler().prioritized_by(throttle_prioritizer())
```

### Event Listeners

Adaptive throttlers support the standard [policy listeners][policy-listeners]:

```python
AdaptiveThrottler(on_failure=lambda e: metrics.incr("throttler.failure"))
```

These do **not** fire for a throttled rejection, matching Go: a rejection is not an execution result, and it is not recorded in the window either.

### Metrics

```python
throttler.rejection_rate   # share currently being rejected, 0 to 1
throttler.executions       # recorded within the thresholding period
throttler.successes
throttler.failures
```

### Deterministic Tests

Rejection is a random draw, so the source is injectable:

```python
AdaptiveThrottler(rng=random.Random(42), clock=fake_clock)
```

## Standalone Usage

```python
if throttler.try_acquire_permit():
    try:
        do_something()
    except Exception:
        throttler.record_failure()
        raise
    else:
        throttler.record_success()
```

`record_result(outcome)` records an `Outcome` judged by the throttler's own `handle` condition, replacing Go's `RecordResult`/`RecordError` pair — a Go zero value cannot be told apart from "no result", while an `Outcome` carries both.

A raising variant is available in both colours:

```python
throttler.acquire_permit()
await throttler.acquire_permit_async()
```

## Best Practices

An `AdaptiveThrottler` can and *should* be shared across code that accesses a common dependency. Construct it at module or DI scope — see [policy sharing][policy-sharing].

### Composing Adaptive Throttlers

When [composing policies][policy-composition], it is recommended not to have a throttler handle exceptions from other policies, such as `BulkheadFull` or `RateLimitExceeded`. If an execution is rejected by some policy, there is no need for a throttler to count it too. Note that the default `handle=Exception` does catch those, so narrow it when composing a throttler outside a limiting policy.

## Additional Details

The window is bucketed at 20 buckets over the thresholding period, and buckets expire on **write** only, matching Go. The rejection rate formula pads the execution count by one, which keeps the rate strictly below 1 at low counts so that a handful of failures cannot wedge a resource shut.

[throttling]: https://sre.google/sre-book/handling-overload/#client-side-throttling-a7sYUg

{% include common-links.html %}
