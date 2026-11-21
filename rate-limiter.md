---
layout: default
title: Rate Limiter
---

# Rate Limiter
{: .no_toc }

1. TOC
{:toc}

Rate limiters are [load limiters][load-limiting] that limit the rate of executions. failsafe-py supports two types: *smooth* and *bursty*. Smooth limiters permit a max number of executions per period, using a leaky bucket approach to spread executions out at an even rate. Bursty limiters use a fixed window to permit a max number of executions per period, allowing bursts within each one.

## How It Works

When executions exceed the configured max per period, further executions either fail with `RateLimitExceeded` or wait until permitted.

Both flavours reserve permits by pure arithmetic: a reservation returns the time the caller must wait, and the waiting happens in the driver. A reserved permit is therefore never lost, and the same instance can serve sync and async callers.

## Smooth Rate Limiter

```python
from failsafe import Failsafe, RateLimiter

# Permits 100 executions per second, evenly spaced
limiter = RateLimiter.smooth(100, period=1.0)
Failsafe(limiter).call(send_message)
```

The rate at which individual executions are permitted follows from `max_executions` and `period`. You can instead specify the max rate of individual executions directly:

```python
# Permits an execution every 10 milliseconds
limiter = RateLimiter.smooth(max_rate=0.01)
limiter = RateLimiter.smooth(max_rate=timedelta(milliseconds=10))
```

Exactly one of the two forms is required; passing both or neither raises `ValueError`. Two classmethods cover what Go spreads across `NewSmooth`, `NewSmoothWithMaxRate`, `NewBursty` and a builder for each.

Smooth executions are permitted with no delay up to the max rate, and always performed at or below it, avoiding bursts.

## Bursty Rate Limiter

```python
# Permits 10 executions per second, in a burst
limiter = RateLimiter.bursty(10, period=1.0)
Failsafe(limiter).call(send_message)
```

Bursty executions are permitted with no delay up to `max_executions` per `period`. When a new period begins the allowance resets, which may cause bursts at period boundaries. Larger periods cause larger bursts.

Available permits can go negative: a burst of 10 against a limit of 2 leaves a deficit, and later callers wait several periods for it to drain.

## Configuration

### Waiting

By default, an exceeded limiter fails further executions immediately with `RateLimitExceeded`. It can also wait for permission within a max wait time:

```python
limiter = RateLimiter.smooth(100, period=1.0, max_wait_time=1.0)
```

Actual wait times vary with how busy the limiter is, and grow if executions are consistently attempted faster than the limiter permits.

{: .callout }
> `max_wait_time` applies to executions through Failsafe. A standalone `acquire_permit()` blocks indefinitely; use `try_reserve_permit(max_wait)` to bound it. This asymmetry is Go's, preserved deliberately.

### Event Listeners

A `RateLimiter` can notify you when a limit has been exceeded by an execution attempt:

```python
RateLimiter.smooth(100, period=1.0, on_rate_limit_exceeded=lambda e: logger.error("rate limited"))
```

## Standalone Usage

```python
if limiter.try_acquire_permit():
    do_something()
```

Blocking acquisition is available in both colours against the same state:

```python
limiter.acquire_permit()
await limiter.acquire_permit_async()
```

You can also integrate with an external scheduler by reserving a permit and getting back the wait:

```python
wait = limiter.reserve_permit()           # seconds to wait
scheduler.enter(wait, 1, some_func)

wait = limiter.try_reserve_permit(1.0)    # -1.0 if it would take longer
```

Multiple permits can be acquired at once, for a caller whose work costs more than one unit:

```python
limiter.acquire_permit(permits=5)
```

`limiter.reset()` discards all reservations, as if the limiter had just been built.

## Best Practices

A `RateLimiter` can and *should* be shared across code that accesses a common dependency, so every execution reaching that dependency counts against the same limit. Construct it at module or DI scope — see [policy sharing][policy-sharing].

For limiting *load* rather than *rate*, consider a [bulkhead][bulkheads], which limits concurrency directly, or an [adaptive limiter][adaptive-limiters], which discovers the limit. [Little's Law][littles-law] explains why: a fixed request rate does not fix concurrency when response times change.

## Performance

The implementation is _O(1)_ in time and space. The reservation arithmetic runs in integer nanoseconds rather than float seconds, because the maths leans on exact integer division — in floats, `0.3 / 0.1` lands just under 3 and silently drops a period.

{% include common-links.html %}
