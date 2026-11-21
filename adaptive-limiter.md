---
layout: default
title: Adaptive Limiter
---

# Adaptive Limiter
{: .no_toc }

1. TOC
{:toc}

Adaptive limiters are concurrency limiters that continually adjust their limit based on indications of overload, taking inspiration from [Uber's Cinnamon][cinnamon] and [Netflix's concurrency-limits][concurrency-limits]. Unlike other ways of preventing overload, adaptive limiters automatically detect overload for any type of resource, adapt to changes in load, and adapt to changes or degradations in a system's capacity.

## Usage

Everything has a default, so the common case is one line:

```python
from failsafe import AdaptiveLimiter, Failsafe

limiter = AdaptiveLimiter()
response = Failsafe(limiter).call(fetch_data)
```

Tuning is keyword-only:

```python
limiter = AdaptiveLimiter(
    min_limit=1,
    max_limit=100,
    initial_limit=20,
    recent_window_min_duration=1.0,
    recent_window_max_duration=30.0,
    recent_window_min_samples=50,
    baseline_window_age=10,
    queueing=(2.0, 3.0),
)
```

A [`Bulkhead`][bulkheads] enforces a limit you picked; this one discovers it.

## How it Works

Adaptive limiters adjust a concurrency limit up or down based on indications of overload. Overload is detected by observing changes in execution times, throughput, and inflight executions. As these change, a modified [TCP Vegas][vegas] thresholding algorithm determines when to adjust the limit:

- If overload is detected, the limit may be decreased
- If overload is not detected, the limit may be increased

Executions are permitted until the number of concurrent executions hits the limit, after which they either fail with `LimitExceeded` or queue until permitted.

## How it Behaves

When not overloaded, a limiter increases its limit up to a multiple of the current inflight executions. This provides headroom for bursts without being so high that it cannot come down quickly when overload is detected.

When overload is detected, the limiter gradually reduces its limit, converging on the capacity of whatever resource is constrained, then oscillating around it until the overload ends. In this way the limiter detects the effective capacity of a system for any constrained resource: CPU, disk IO, network IO.

To get a feel for how adaptive limiters behave and to see overload handling in action, see the load simulation tool [Tripwire].

## Policy Comparison

Adaptive limiters are similar to [circuit breakers][circuit-breakers] and [adaptive throttlers][adaptive-throttlers] in that they react to signs of overload. But where those policies need *failures* — timeouts, errors — to drive them, adaptive limiters detect overload on their own. That is where they excel: spotting unusual latency before large numbers of timeouts occur, which can protect a system from overload before it happens.

## Configuration

### Limits

```python
AdaptiveLimiter(min_limit=1, max_limit=100, initial_limit=20)
```

The max limit factor controls how high the limit may go as a multiple of the current inflight executions:

```python
AdaptiveLimiter(max_limit_factor=5.0)
```

A decay reduces the max limit factor for each order of magnitude increase in inflight executions, with a floor:

```python
AdaptiveLimiter(max_limit_factor_decay=1.0, min_limit_factor=1.0)
```

This provides more headroom for bursts when inflights are low, and less when they are high.

The inflight count that the factor applies to can be smoothed over a window, so a brief dip in traffic cannot pull the limit down:

```python
AdaptiveLimiter(max_limit_stabilization_window=5.0)
```

### Execution Times

The primary indicator of overload is execution time: when a system is overloaded, work queues and execution times increase. The limiter aggregates recent execution times in a window and compares them to a baseline to estimate whether work is queueing inside the system.

Configure the min and max durations of the recent sampling window, and the min samples needed before the limit is adjusted:

```python
AdaptiveLimiter(
    recent_window_min_duration=1.0,
    recent_window_max_duration=30.0,
    recent_window_min_samples=50,
)
```

When the window's conditions are met, a quantile of recent execution times is compared against the baseline. The p90 is used by default, so tail latency drives the decision:

```python
AdaptiveLimiter(recent_quantile=0.5)
```

Recent quantiles feed a baseline window, a weighted moving average representing execution times over a longer term:

```python
AdaptiveLimiter(baseline_window_age=10)
```

Larger baseline windows make the limiter slower to adjust to changes in baseline load.

### Throughput Correlation

Changes in execution times are a good indicator of overload, but not a perfect one. As a second indicator, limiters track the *correlation* between inflight executions and throughput. If inflight executions are increasing but throughput is flat or falling, the system is likely overloaded and the limit is decreased.

```python
AdaptiveLimiter(correlation_window_size=50)
```

### Queueing

Since the limiter sets its limit from detected capacity, a burst can fill it quickly and cause rejections. To avoid excess rejections, allow some queueing in front of the limiter rather than rejecting immediately.

Rejections are gradual, from an *initial* rejection threshold up to a *max*, both expressed as multiples of the current limit. For example: with a current limit of 10, an initial factor of 2, and a max factor of 3:

- Up to 10 inflight executions run before the limiter is full
- Up to 20 additional executions queue before rejections gradually begin
- After 30 are queued, all additional executions are rejected

Configuring queue sizes as a multiple of the current limit lets the queue scale across workloads without per-workload configuration:

```python
AdaptiveLimiter(queueing=(2.0, 3.0))
AdaptiveLimiter(queueing=(2.0, 3.0), max_wait_time=1.0)
```

`max_wait_time=None` — the default with queueing enabled — waits indefinitely.

### Execution Prioritization

Adaptive limiters can decide which executions to reject by priority, rejecting lower priority executions first, and can prioritize based on individual users' usage. See [execution prioritization][execution-prioritization]:

```python
from failsafe import UsageTracker, queue_prioritizer

prioritizer = queue_prioritizer(usage_tracker=UsageTracker())
limiter = AdaptiveLimiter(queueing=(2.0, 3.0)).prioritized_by(prioritizer)
```

### Event Listeners

In addition to the standard [policy listeners][policy-listeners], an `AdaptiveLimiter` can notify you when the limit changes or is exceeded:

```python
AdaptiveLimiter(
    on_limit_changed=lambda e: logger.info("limit %d -> %d", e.old_limit, e.new_limit),
    on_limit_exceeded=lambda e: metrics.incr("limiter.rejected"),
)
```

### Metrics

| | |
|---|---|
| `limiter.limit` | the current concurrency limit |
| `limiter.inflight` | executions running right now |
| `limiter.queued` | executions waiting for a permit |
| `limiter.max_inflight` | peak inflight during the last sampling window |
| `limiter.queueing` | whether queueing is enabled |

## Standalone Usage

An `AdaptiveLimiter` can be manually operated. A permit must be told whether the execution is a usable latency sample:

```python
permit = limiter.acquire_permit()
try:
    send_request()
except Exception:
    permit.drop()      # release without recording a sample
    raise
else:
    permit.record()    # record the duration, release the permit
```

There is a sync and an async method, and either can take a priority:

```python
permit = await limiter.acquire_permit_async(priority=Priority.HIGH)

if (permit := limiter.try_acquire_permit()) is not None:
    ...

limiter.can_acquire_permit(priority=Priority.LOW)
```

## Best Practices

Adaptive limiters can be shared across an entire service, or separate limiters can protect different workloads that use different resources or downstream services. When using multiple limiters, use a shared [prioritizer][execution-prioritization] so the rejection threshold accounts for their combined queueing.

## Additional Details

### Determining Overload

When recent execution times change relative to the baseline, it could mean the system is overloaded — or it could mean the *kind* of work has shifted and the baseline needs to move. A system that was processing fast requests and is now handling slow ones is not necessarily overloaded.

The limiter distinguishes these *experimentally*: it lowers the limit and observes. As the limit falls, recent and baseline latencies eventually equalize and the limit is raised again. In a true overload, recent times spike again and the limit adjusts down in response. Otherwise the limit keeps increasing, with a new baseline having been set.

[cinnamon]: https://www.uber.com/blog/cinnamon-using-century-old-tech-to-build-a-mean-load-shedder/
[concurrency-limits]: https://github.com/Netflix/concurrency-limits
[vegas]: https://en.wikipedia.org/wiki/TCP_Vegas

{% include common-links.html %}
