---
layout: default
title: Hedge
---

# Hedge
{: .no_toc }

1. TOC
{:toc}

Hedge policies are a way of bringing down long tail latencies by performing additional executions, after some delay, if the initial execution is slow to complete. This differs from a [retry policy][retry] since multiple hedged executions may be in progress at the same time. After the first successful execution is returned, the remaining executions are cancelled.

## Async Only

`HedgePolicy` is supported under [`AsyncFailsafe`][async-execution]. Under `Failsafe` it raises `NotImplementedError`, since a synchronous call cannot be cancelled and the losing hedges would run to completion.

## Usage

```python
from failsafe import AsyncFailsafe, HedgePolicy

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

With this in mind, you can configure a dynamic delay, computed per attempt:

```python
HedgePolicy(lambda ex: p95_latency(), max_hedges=2)
```

Returning `None` stops hedging for that execution.

The policy can also track the quantile for you:

```python
HedgePolicy(quantile=0.95)
HedgePolicy(quantile=0.95, quantile_age=30, warmup=20)
```

Exactly one of `delay` and `quantile` is required. `quantile_age` is how many executions the estimate remembers, and `warmup` is how many to observe before hedging begins.

### Cancellation

By default, any outstanding hedges are cancelled after the first result is returned. You can also specify which results, exceptions, or conditions should cancel outstanding hedges:

```python
HedgePolicy(0.1, cancel_on=True)
HedgePolicy(0.1, cancel_on=ConnectionError)
HedgePolicy(0.1, cancel_on=lambda result, exc: result is not None and result.status_code < 500)
```

### Budgets

[Budgets][budgets] can be added to hedge policies to control the max outstanding hedges across a system:

```python
HedgePolicy(0.1, budget=budget)
```

### Event Listeners

A `HedgePolicy` can notify you before each hedged attempt starts:

```python
HedgePolicy(0.1, on_hedge=lambda e: metrics.incr("hedge.started"))
```

## Execution Info

Hedges count as attempts, and [`is_hedge`][execution-info] distinguishes a hedged attempt from the original:

```python
async def send_request():
    if current_execution().is_hedge:
        logger.debug("hedged attempt")
```

{% include common-links.html %}
