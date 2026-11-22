---
layout: default
title: Execution Prioritization
---

# Execution Prioritization
{: .no_toc }

1. TOC
{:toc}

Some policies, including [adaptive limiters][adaptive-limiters] and [adaptive throttlers][adaptive-throttlers], support execution prioritization, where an overloaded policy rejects executions based on their priority. Prioritization draws from the idea of [criticality], as described in the [Google SRE book][sre-book]. Adaptive limiters also support prioritization based on individual usage.

## Priorities

Five priority classes are supported, as an `IntEnum`:

```python
from failsafe import Priority

Priority.VERY_HIGH
Priority.HIGH
Priority.MEDIUM
Priority.LOW
Priority.VERY_LOW
```

Different priorities can be assigned to different types of executions — internal requests may be prioritized over user requests, for example. When a policy is overloaded, lower priority executions are rejected before higher priority ones.

Absence of a priority is `None`, which cannot be mistaken for a valid level the way a sentinel number can.

## Prioritizers

To use prioritized rejection, first create a `Prioritizer`. There is one per policy family, because each computes overload differently:

```python
from failsafe import queue_prioritizer, throttle_prioritizer

prioritizer = queue_prioritizer()      # for adaptive limiters
prioritizer = throttle_prioritizer()   # for adaptive throttlers
```

A `Prioritizer` stores the levels of recent executions and calibrates a rejection threshold from those levels and the registered policies' stats. A shared prioritizer determines one threshold across multiple policies.

Then build a prioritized policy from it:

```python
limiter = AdaptiveLimiter(queueing=(2.0, 3.0)).prioritized_by(prioritizer)
throttler = AdaptiveThrottler().prioritized_by(prioritizer)
```

`prioritized_by` registers the policy and returns it, rather than producing a separate `PriorityLimiter` type. One type per policy keeps the surface smaller and lets the same instance be metered and composed uniformly.

Prioritization only matters when a policy is overloaded and must reject something. Each policy determines how overloaded it is; the `Prioritizer` combines that across policies into a global rejection rate.

## Calibration

A prioritizer should be calibrated regularly to update its rejection threshold. Call `calibrate()` on your own schedule, or scope a background thread to a block:

```python
prioritizer.calibrate()

with prioritizer.scheduled_calibrations(1.0):
    serve_forever()
```

## Prioritized Execution

To perform an execution with a priority, enter a priority scope:

```python
from failsafe import Priority, priority_scope

with priority_scope(Priority.HIGH):
    response = Failsafe(limiter).call(fetch_data)
```

When a policy is exceeded, executions are rejected based on the prioritizer's rejection threshold.

## Usage Tracking

Adaptive limiters can track usage per user, so users with higher usage are shed before those with lower usage. Configure a `UsageTracker` on the prioritizer:

```python
from failsafe import UsageTracker, user_scope

prioritizer = queue_prioritizer(usage_tracker=UsageTracker())
limiter = AdaptiveLimiter(queueing=(2.0, 3.0)).prioritized_by(prioritizer)

with priority_scope(Priority.HIGH), user_scope(account_id):
    response = Failsafe(limiter).call(fetch_data)
```

Without this, every execution at a priority competes equally and one heavy user can crowd out many light ones. With it, a user's level within their priority falls as their usage rises relative to everyone else's. Totals are re-ranked by `calibrate()`, not on every call.

```python
UsageTracker(window=300.0, max_users=10000)
```

## Priorities vs Levels

In order to enable more granular prioritization of executions, priorities are internally converted to more granular levels, with 100 levels per priority class. In practice, prioritizers use these levels to determine which executions to reject, allowing more precise rejection rates.

To use an exact level rather than one drawn from a priority:

```python
from failsafe import level_scope

with level_scope(250):
    ...
```

## Features

### Event Listeners

A `Prioritizer` can notify you when its rejection threshold changes:

```python
prioritizer = queue_prioritizer(
    on_threshold_changed=lambda e: logger.info(
        "threshold %d -> %d", e.old_threshold, e.new_threshold
    ),
)
```

### Metrics

| | |
|---|---|
| `prioritizer.rejection_rate` | share being rejected, 0 to 1 |
| `prioritizer.rejection_threshold` | the level below which executions are rejected |
| `prioritizer.registered_policies` | how many policies report to it |

## Standalone Usage

Policies that support prioritization accept a priority on their standalone permit methods:

```python
permit = limiter.acquire_permit(priority=Priority.HIGH)
limiter.can_acquire_permit(priority=Priority.LOW)
throttler.try_acquire_permit(priority=Priority.HIGH)
```

A priority passed explicitly overrides whatever is in scope.

## Best Practices

Prioritizers can and should be shared across multiple limiters when possible. This allows a combined rejection threshold to be determined across limiters, which takes their combined queueing into account and leads to more stable rejection behaviour.

{% include common-links.html %}
