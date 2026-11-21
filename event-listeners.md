---
layout: default
title: Event Listeners
---

# Event Listeners
{: .no_toc }

1. TOC
{:toc}

failsafe-py supports event listeners on policies. Every policy takes them as constructor keyword arguments.

## There Is No Executor-Level Listener

`Failsafe` and `AsyncFailsafe` take only policies and a clock. Listeners belong to policies, because a policy is what decides whether an outcome was a success or a failure.

To observe the final result of a composition, use the outermost policy's listeners — they see exactly what that policy decided:

```python
payments = Failsafe(
    Fallback(
        value=CACHED,
        on_success=lambda e: logger.info("connected: %r", e.result),
        on_failure=lambda e: logger.error("failed: %s", e.exception),
    ),
    retry,
    breaker,
)
```

For something that must run on every call regardless of composition, wrap the call site — a decorator or a `try`/`finally` is clearer than a hook whose firing conditions depend on what the innermost policy did.

## Policy Listeners

Policies that can be configured to handle specific results or exceptions — [`RetryPolicy`][retry], [`CircuitBreaker`][circuit-breakers], [`AdaptiveThrottler`][adaptive-throttlers], [`Fallback`][fallbacks] — provide listeners that fire when an attempt succeeds or fails according to *that policy's* [failure handling configuration][failure-handling]:

```python
RetryPolicy(
    on_success=lambda e: logger.info("connected: %r", e.result),
    on_failure=lambda e: logger.error("attempt failed: %s", e.exception),
)
```

Additional listeners are available per policy: `on_retry`, `on_state_change`, `on_limit_changed`, `on_full`, and so on. Each policy page documents its own.

## Lists, Not Slots

Listeners *append* rather than replace, and every keyword accepts a callable or a sequence of them:

```python
retry = RetryPolicy(on_retry=[log_retry, count_retry])
```

They can also be added after construction. `add` returns the function, so it doubles as a decorator:

```python
@retry.on_retry.add
def trace_retry(e):
    tracer.add_event("retry", attempt=e.attempts)
```

Listeners are called in registration order.

## Events

| Event | Fields |
|---|---|
| `ExecutionEvent` | `execution`, `result`, `exception`, plus `attempts`, `retries`, `elapsed` |
| `ScheduledRetryEvent` | the above, plus `delay` — the delay about to elapse |
| `ExecutionCompletedEvent` | `execution`, `result`, `exception` |
| `StateChangedEvent` | `previous_state`, `state` |
| `LimitChangedEvent` | `old_limit`, `new_limit` |
| `ThresholdChangedEvent` | `old_threshold`, `new_threshold` |

All are frozen dataclasses. `e.result` is typed `Any`, because the result type is inferred per call rather than fixed on the policy; see [type safety][type-safety].

## Listeners Are Sync

Listeners are plain functions in both drivers. A coroutine listener cannot be awaited from the sync driver, and accepting one in only half the API would leak function colouring into the event model.

Listeners are for logging and metrics. If one genuinely needs to do I/O, hand the work off:

```python
RetryPolicy(on_retry=lambda e: asyncio.get_running_loop().create_task(report(e)))
```

## Listener Exceptions Are Logged

A listener that raises is logged and the execution continues: a bug in your metrics code must not break a production request.

This means a silently broken listener stays broken. Check your logs for `failsafe` warnings if a listener seems not to be working.

## Alternative Execution Results

Event listeners are for side effects. They do not influence the outcome of an execution — a listener's return value is ignored, and a raised exception is swallowed. To provide an alternative result, use a [`Fallback`][fallbacks].

{% include common-links.html %}
