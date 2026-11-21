---
layout: default
title: Hedge
---

# Hedge
{: .no_toc }

1. TOC
{:toc}

Hedge policies bring down long tail latencies by starting additional executions, after some delay, if the initial execution is slow to complete. This differs from a [retry policy][retry] since multiple hedged executions may be in progress at the same time. After the first accepted result arrives, the remaining executions are cancelled.

The tail of a latency distribution is usually not the service being slow but one request being unlucky: a stalled connection, an unlucky GC pause, a node about to be replaced. Retrying only after a timeout pays the timeout first; a hedge starts a second attempt while the first is still running and takes whichever finishes.

## Async Only

`HedgePolicy` is supported under [`AsyncFailsafe`][async-execution]. Under `Failsafe` it raises `NotImplementedError`.

Hedging needs cancellable concurrency. A synchronous call cannot be cancelled, so the losing attempts would run to completion against the very service the policy is trying to protect. A thread-pool implementation would leak a thread per losing hedge while shipping weaker-than-Go semantics under the same policy name, so the gap is deliberate rather than papered over. This is the one capability gap versus [failsafe-go]; see [porting][porting-differences].

## Usage

```python
from failsafe import AsyncFailsafe, HedgePolicy

# Hedge once, 100ms after the original attempt starts
api = AsyncFailsafe(HedgePolicy(0.1))
response = await api.call(send_request)
```

## Configuration

### Max Hedges

By default a `HedgePolicy` performs a single hedged execution if the original is not done before the delay:

```python
HedgePolicy(0.1, max_hedges=2)
```

Each hedge waits the delay again, so with `max_hedges=2` and a delay of 100ms, attempts start at 0ms, 100ms and 200ms.

### Dynamic Delay

The hedging pattern was first described in [The Tail at Scale][tail-at-scale], which recommends a hedging delay equal to the current p95 or p99 latency. That way, if latencies change, you keep targeting the long tail rather than hedging too early.

A callable delay computes one per attempt from the [execution][execution-info]:

```python
HedgePolicy(lambda ex: p95_latency(), max_hedges=2)
```

Returning `None` stops hedging for that execution.

The policy can also track the quantile itself, which is the usual reason to want a dynamic delay:

```python
# Hedge when an execution exceeds the p95 of recent accepted durations
HedgePolicy(quantile=0.95)
HedgePolicy(quantile=0.95, quantile_age=30, warmup=20)
```

Exactly one of `delay` and `quantile` is required. `quantile_age` is how many executions the estimate remembers — smaller adapts faster, larger is steadier. `warmup` is how many executions to observe before hedging at all: hedging on an estimate drawn from a handful of samples is how a cold start becomes a thundering herd.

### Cancellation

By default any outstanding hedges are cancelled after the first result arrives, whatever it is. You can specify which results, exceptions, or conditions should end the execution, using the same [`Condition`][failure-handling] type as everywhere else:

```python
HedgePolicy(0.1, cancel_on=Result(True))
HedgePolicy(0.1, cancel_on=ConnectionError)
HedgePolicy(0.1, cancel_on=lambda result, exc: result is not None and result.status_code < 500)
```

An outcome that does not match is not accepted, and the remaining attempts keep running.

### Budgets

Hedges multiply load. Every attempt is a real request, so a policy that hedges eagerly turns a slow dependency into an overloaded one. Hedge on a delay well into the tail, and give the policy a [`Budget`][budgets] when the dependency is shared:

```python
budget = Budget(max_rate=0.2)
HedgePolicy(0.1, budget=budget)
```

When the budget is spent the policy simply stops hedging; the attempts already running still produce a result.

### Event Listeners

A `HedgePolicy` can notify you before each hedged attempt starts:

```python
HedgePolicy(0.1, on_hedge=lambda e: metrics.incr("hedge.started"))
```

## Execution Info

Hedges count as attempts. `Execution.attempts` and `Execution.hedges` both increment, and `is_hedge` distinguishes a hedged attempt from the original:

```python
async def send_request():
    if current_execution().is_hedge:
        logger.debug("hedged attempt")
    ...
```

The winning attempt cancels the losers with its own result, rather than with a cancellation error.

{% include common-links.html %}
