---
layout: default
title: Comparisons
---

# Comparisons
{: .no_toc }

1. TOC
{:toc}

## Retries

### failsafe-py vs tenacity

[tenacity] is the de-facto Python retry library. It differs from failsafe-py's [RetryPolicy][retry] in a few ways:

- failsafe-py retries are one policy among several that [compose][policy-composition]. tenacity solves retries only.
- failsafe-py retries can be [aborted][aborts] on specific results, exceptions, or conditions.
- failsafe-py retries can be bounded system-wide by a [budget][budgets].
- failsafe-py shares one policy instance between sync and async callers; tenacity has separate `Retrying` and `AsyncRetrying` classes.

If retries are your whole problem, tenacity is mature and widely deployed.

### failsafe-py vs backoff

[backoff] is a decorator-based retry library with exponential backoff and jitter. It is less actively developed than tenacity but still widely installed.

- Same compositional point as above: backoff is retries only.
- backoff decorates a function at definition time. failsafe-py's [`Failsafe`][policy-sharing] object is built once and applied at as many call sites as you like, which matters for the stateful policies it composes with.
- backoff's `max_time` and failsafe-py's `max_duration` are equivalent; failsafe-py additionally clamps the delay so a long backoff never overshoots the budget.

## Circuit Breakers

### failsafe-py vs pybreaker

[pybreaker] is the most established Python circuit breaker.

- failsafe-py offers count based and time based thresholding, including a failure *rate* over a period. pybreaker thresholds on consecutive failures only.
- failsafe-py's half-open state admits a bounded number of trial executions.
- failsafe-py breakers can threshold on results, not just exceptions.
- pybreaker offers distributed state via Redis, which failsafe-py does not.

### failsafe-py vs circuitbreaker

[circuitbreaker] is a decorator-only circuit breaker with a failure threshold and a recovery timeout. It has no rate thresholding and no composition with other policies.

## Load Limiting

There is no close comparison to draw. [Adaptive limiters][adaptive-limiters], [adaptive throttlers][adaptive-throttlers] and [prioritized load shedding][execution-prioritization] have no widely-used Python equivalent.

`limits` and `pyrate-limiter` cover [rate limiting][rate-limiters] specifically, and do it well, with backing stores failsafe-py does not provide. They do not limit *concurrency*, which is usually what protects a system; see [load limiting][load-limiting] for why that distinction matters.

## Hedging

No widely-used Python hedging library exists. failsafe-py's [HedgePolicy][hedge] is async-only, for reasons covered on that page.

{% include common-links.html %}

[tenacity]: https://github.com/jd/tenacity
[backoff]: https://github.com/litl/backoff
[pybreaker]: https://github.com/danielfm/pybreaker
[circuitbreaker]: https://github.com/fabfuel/circuitbreaker
