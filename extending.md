---
layout: default
title: Extending failsafe-py
---

# Extending failsafe-py
{: .no_toc }

1. TOC
{:toc}

A custom policy can be composed alongside the built-in ones. The contract is one method.

## The Policy Protocol

A policy wraps an inner step and returns a new one:

```python
class Policy(Protocol):
    def apply(self, inner: Step) -> Step: ...
```

A `Step` is a callable taking the [`Execution`][execution-info] and returning a **generator** that yields *instructions* and finally returns an `Outcome`. The generator is the policy's logic; the driver decides how to service what it yields.

This is why the same policy works in both sync and async mode: a policy never sleeps, never blocks, and never spawns anything. It yields `Sleep(1.0)` and the driver calls `time.sleep` or `await asyncio.sleep`.

## A Minimal Policy

A policy that logs each attempt and passes everything through:

```python
from failsafe import Execution

class Logged:
    def apply(self, inner):
        def step(ex: Execution):
            outcome = yield from inner(ex)
            logger.info("attempt %d -> %r", ex.attempts, outcome.value or outcome.exc)
            return outcome
        return step

Failsafe(Logged(), retry).call(connect, host)
```

`yield from inner(ex)` is how policies nest: it forwards every instruction the inner policies yield out to the driver, and gives back their final `Outcome`.

## Instructions

| Instruction | Serviced as |
|---|---|
| `Invoke()` | Call the user function, capturing an `Outcome`. Catches `Exception`, never `BaseException` |
| `Sleep(seconds)` | `time.sleep` or `await asyncio.sleep`, interruptible by cancellation |
| `Acquire(semaphore, timeout)` | A blocking or awaiting permit acquisition against one shared semaphore |
| `Race(inner, seconds, interrupt)` | Run `inner` under a deadline |

A retry policy is roughly:

```python
def apply(self, inner):
    def step(ex):
        while True:
            outcome = yield from inner(ex)
            if not self.is_failure(outcome) or exhausted(ex):
                return outcome
            yield Sleep(self.compute_delay(ex))
    return step
```

## Rules

**Release in `finally`.** A driver may abandon an execution by closing the generator — a deadline elapsing, a hedge losing. Anything acquired must be released on the way out:

```python
def step(ex):
    self.semaphore.acquire()
    try:
        return (yield from inner(ex))
    finally:
        self.semaphore.release()
```

**Per-execution state belongs in the generator.** Policies are shared across concurrent executions, so anything that varies per execution — a backoff's current delay, an attempt counter — lives in the generator's local scope. Anything on `self` is shared and needs a lock.

**Never catch `BaseException`.** `CancelledError` must propagate.

**Failure conditions, if you have them**, should reuse `Condition` so your policy's `handle=` behaves like everyone else's, including the rule that a result-only condition does not replace the default error handling.

## Reference Implementations

The built-in policies are the best reference, and they are small. [`Fallback`][fallbacks] is about 30 lines of logic and shows the minimum shape; [`RetryPolicy`][retry] shows delays and listeners; [`Bulkhead`][bulkheads] shows permit handling with `finally`; [`CircuitBreaker`][circuit-breakers] shows shared locked state. See the [source][github].

## Private API

`Step`, `Outcome`, `Invoke`, `Sleep`, `Acquire` and `Race` live in `failsafe._core` and are not exported from the package root. They are stable enough to build against — every built-in policy uses them — but they are not covered by the public API's compatibility promise. If you ship a policy publicly, pin a version range.

{% include common-links.html %}
