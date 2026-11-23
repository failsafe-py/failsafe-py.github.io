---
layout: default
title: Execution Budgets
---

# Execution Budgets
{: .no_toc }

1. TOC
{:toc}

Budgets limit the total number of concurrent retries or hedges across a system to prevent them from causing overload. This can happen when a flood of retries or hedges come in and need to be handled gradually.

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

You can use the same budget for retries and hedges if you like.

## How It Works

Budgets permit executions to proceed up to some max share of concurrent retries or hedges, after which a [`RetryPolicy`][RetryPolicy] fails with [`BudgetExceeded`][BudgetExceeded] and a [`HedgePolicy`][HedgePolicy] stops hedging. This allows a system-wide cap to be placed on retries or hedges.

## Comparison

Budgets are similar to [bulkheads][bulkheads] in that both limit concurrency. But a bulkhead limits the concurrency of *all* executions wherever it is used; a budget limits the concurrency of *just retries and hedges*. Normal traffic is never refused by a budget.

## Configuration

### Max Rate

The share of in-flight executions that may be retries or hedges:

```python
Budget(max_rate=0.5)
```

### Min Concurrency

You can also specify the min number of concurrent executions that can be retries or hedges:

```python
Budget(min_concurrency=5)
```

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

{% include common-links.html %}
