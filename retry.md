---
layout: default
title: Retry
---

# Retry
{: .no_toc }

1. TOC
{:toc}

Retry policies retry failed executions a certain number of times, with an optional delay between attempts. `RetryPolicy` is stateless and can be shared as needed.

## Usage

Creating and using a `RetryPolicy` is straightforward:

```python
from failsafe import Failsafe, RetryPolicy

# Retry on ConnectionError up to 3 times with a 1 second delay between attempts
retry = RetryPolicy(handle=ConnectionError, delay=1.0, max_retries=3)

connection = Failsafe(retry).call(connect, host)
```

## Configuration

### Failure Handling

A `RetryPolicy` can be configured to handle only [certain results, exceptions, or conditions][failure-handling] as failures:

```python
RetryPolicy(handle=[ConnectionError, Result(None)])
```

### Max Retries

By default a `RetryPolicy` allows 2 retries, for a maximum of 3 attempts:

```python
RetryPolicy(max_retries=2)
```

Only `max_retries` is provided; Go's `WithMaxAttempts(n)` is `max_retries=n - 1`. To retry without a count limit — bounded only by `max_duration` or an outer [timeout][timeouts]:

```python
RetryPolicy(max_retries=None, max_duration=60.0)
```

### Max Duration

In addition to a retry count, you can set a max duration for an execution, after which retries stop even if the retry count has not been reached:

```python
RetryPolicy(max_duration=300.0)
RetryPolicy(max_duration=timedelta(minutes=5))
```

Delays are clamped to the remaining budget, so a long backoff never overshoots `max_duration`.

### Delays

By default a `RetryPolicy` has no delay between attempts. Seconds or a `timedelta` configure a fixed delay:

```python
RetryPolicy(delay=1.0)
RetryPolicy(delay=timedelta(seconds=1))
```

A delay that backs off exponentially, capped at a maximum:

```python
from failsafe import Backoff

RetryPolicy(delay=Backoff(1.0, 30.0))            # doubling by default
RetryPolicy(delay=Backoff(1.0, 30.0, factor=3))
```

A random delay over some range:

```python
from failsafe import RandomDelay

RetryPolicy(delay=RandomDelay(1.0, 10.0))
```

Or a delay computed per attempt from the [execution][execution-info]:

```python
RetryPolicy(delay=lambda ex: retry_after(ex.last_result))
```

Backoff state is per execution, not per policy, so a shared policy's concurrent executions never interfere.

### Jitter

Jitter is an attribute of the delay rather than a separate parameter, because jitter without a delay does nothing:

```python
from failsafe import Fixed, Jitter

RetryPolicy(delay=Backoff(1.0, 30.0, jitter=Jitter(factor=0.25)))  # ±25% of each delay
RetryPolicy(delay=Fixed(1.0, jitter=Jitter(seconds=0.1)))          # ±100ms on each delay
RetryPolicy(delay=Backoff(1.0, 30.0, jitter=0.25))                 # shorthand for factor
```

`Jitter(factor=...)` and `Jitter(seconds=...)` keep Go's two meanings distinct, where a bare float would silently misread `jitter=0.5` as one or the other. A plain `delay=1.0` carries no jitter and has nothing to leave half-configured.

For deterministic tests, inject the randomness:

```python
RetryPolicy(delay=Backoff(1.0, 30.0, jitter=0.25), rng=random.Random(42))
```

### Budgets

[Budgets][budgets] can be added to retry policies to control the max outstanding retries across a system:

```python
RetryPolicy(budget=budget)
```

### Aborts

You can specify which results, exceptions, or conditions should [abort][failure-handling] retries, failing immediately with that outcome rather than `RetriesExceeded`:

```python
RetryPolicy(handle=HTTPError, abort=AuthenticationError)
RetryPolicy(abort=lambda result, exc: result is not None and result.status_code == 404)
```

`abort` is only consulted for outcomes that `handle` already considers failures, and it takes the same `Condition` type.

### Raised Exception

By default, when an execution fails and the retries are exhausted, `RetriesExceeded` is raised, carrying the last result and exception, and chaining the original as `__cause__`:

```python
try:
    response = Failsafe(retry).call(send_message)
except RetriesExceeded as e:
    logger.error("Failed to send message", extra={"response": e.last_result, "error": e.last_exception})
```

A `RetryPolicy` can instead return or raise the last failure itself:

```python
RetryPolicy(return_last_failure=True)
```

If additional handling or an alternative result is needed, compose a [fallback][fallbacks] around the retry policy.

### Event Listeners

In addition to the standard [policy event listeners][policy-listeners], a `RetryPolicy` can notify you when a retry is scheduled or about to be attempted, when the retries are exceeded, or when retries are aborted:

```python
retry = RetryPolicy(
    on_retry=lambda e: logger.warning("Retrying after %s", e.exception),
    on_retry_scheduled=lambda e: logger.debug("Retry in %.1fs", e.delay),
    on_retries_exceeded=lambda e: metrics.incr("retries_exceeded"),
    on_abort=lambda e: logger.info("Aborted: %s", e.exception),
)
```

Every listener keyword also accepts a list, and each can be added after construction — `add` returns the function, so it doubles as a decorator:

```python
RetryPolicy(on_retry=[log_retry, count_retry])

@retry.on_retry.add
def trace_retry(e): ...
```

A listener that raises is logged, not propagated: a metrics bug will not break a request.

{% include common-links.html %}
