---
layout: default
title: Execution Budgets
---

# Execution Budgets
{: .no_toc }

1. TOC
{:toc}

Budgets cap the share of in-flight work that retries and hedges may consume, preventing them from causing the overload they were meant to paper over.

A retry storm is self-inflicted load: the attempts meant to cover a few failures become most of the traffic to an already struggling service. One budget shared between policies bounds that, letting extra attempts through only while they stay a small fraction of normal traffic.

## Usage

```python
from failsafe import Budget, Failsafe, RetryPolicy

budget = Budget(max_rate=0.2, min_concurrency=3)

api = Failsafe(RetryPolicy(budget=budget))
search = Failsafe(RetryPolicy(budget=budget))
```

The same budget works for [hedges][hedge]:

```python
hedged = AsyncFailsafe(HedgePolicy(0.1, budget=budget))
```

One budget can serve both, which is usually right: retries and hedges are the same extra load from the dependency's point of view.

## How It Works

Budgets permit extra attempts up to a share of the executions in flight. Beyond that:

- a [`RetryPolicy`][retry] stops retrying and fails with `BudgetExceeded`
- a [`HedgePolicy`][hedge] simply stops hedging, leaving the attempts already running to produce a result

The rate is measured against executions **in flight right now**, not over a time window. That needs no clock and reacts immediately, where a windowed rate lags exactly when a storm is building.

## Comparison

Budgets are similar to [bulkheads][bulkheads] in that both limit concurrency. But a bulkhead limits the concurrency of *all* executions wherever it is used; a budget limits the concurrency of *just retries and hedges*. Normal traffic is never refused by a budget.

## Configuration

### Max Rate

The share of in-flight executions that may be retries or hedges:

```python
Budget(max_rate=0.5)
```

### Min Concurrency

Extra attempts always allowed regardless of the rate, so a quiet service still retries:

```python
Budget(min_concurrency=5)
```

Without this, a service with one request in flight could never retry it — one retry out of one execution is a rate of 1.0, over any sane threshold.

### Event Listeners

```python
Budget(on_exceeded=lambda e: logger.warning("budget spent: %s at %.2f", e.kind, e.rate))
```

The event carries the `execution`, the `kind` — `"retry"` or `"hedge"` — and the `rate` at the moment of refusal.

### Metrics

`budget.rate` is the share of in-flight executions that are currently retries or hedges.

## Best Practices

**Share one instance across the policies guarding the same dependency.** A budget per policy bounds nothing, since the dependency sees their sum. This is the same hoisting rule as every other stateful policy — see [policy sharing][policy-sharing].

```python
# wrong: each policy gets its own 20%, so the dependency sees 40%
Failsafe(RetryPolicy(budget=Budget()))
Failsafe(RetryPolicy(budget=Budget()))
```

## Standalone Usage

```python
budget.record_execution()
try:
    if budget.try_acquire_permit():
        try:
            do_retry()
        finally:
            budget.release_permit()
finally:
    budget.release_execution()
```

{% include common-links.html %}
