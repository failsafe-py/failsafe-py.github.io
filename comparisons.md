---
layout: default
title: Comparisons
---

# Comparisons
{: .no_toc }

1. TOC
{:toc}

How failsafe-py differs from the Python libraries that solve part of the same problem. Only libraries in wide use are covered; obscure ones are a disservice to compare against.

The honest summary: if you need **only** retries, [tenacity] is mature, widely deployed and a perfectly good choice. failsafe-py earns its place when you need several policies that must work together, or when you need the same policy to guard sync and async callers.

## Retries

### failsafe-py vs tenacity

[tenacity] is the de-facto Python retry library, and a fork of the older `retrying`. It differs from failsafe-py's [RetryPolicy][retry] in a few ways:

- failsafe-py retries are one policy among several that **compose**. tenacity solves retries only; a circuit breaker or bulkhead alongside it is a separate library with its own ordering semantics to reason about.
- failsafe-py combines retry settings through a single constructor. tenacity composes `stop_*`, `wait_*` and `retry_*` objects, which is flexible but spreads one policy across several imports.
- failsafe-py shares one policy instance between sync and async callers. tenacity has `Retrying` and `AsyncRetrying` as separate classes.
- failsafe-py retries can be [aborted][aborts] on specific results, exceptions, or conditions, failing fast rather than exhausting the attempts.
- failsafe-py retries can be bounded system-wide by a [budget][budgets], which caps the share of in-flight work that retries may become. tenacity has no cross-call notion of retry load.
- failsafe-py never retries `BaseException`. `asyncio.CancelledError` is terminal by construction, which is the most common correctness bug in this category.
- failsafe-py jitter is attached to the delay, so it cannot be configured where it does nothing.
- tenacity's `before`/`after`/`retry_error_callback` hooks are broadly equivalent to failsafe-py's [listeners][retry-listeners], with one difference: a raising listener here is logged, not propagated.

tenacity also offers things failsafe-py does not: `@retry` with zero configuration, `reraise` semantics tuned over many years, and `retry_if_exception_message`. If retries are your whole problem, that maturity is worth something.

### failsafe-py vs backoff

[backoff] is a decorator-based retry library with exponential backoff and jitter. It is less actively developed than tenacity but still widely installed.

- Same compositional point as above: backoff is retries only.
- backoff decorates a function at definition time. failsafe-py's [`Failsafe`][policy-sharing] object is built once and applied at as many call sites as you like, which matters for the stateful policies it composes with.
- backoff's `max_time` and failsafe-py's `max_duration` are equivalent; failsafe-py additionally clamps the delay so a long backoff never overshoots the budget.

## Circuit Breakers

### failsafe-py vs pybreaker

[pybreaker] is the most established Python circuit breaker, a port of Michael Nygard's pattern with a listener model and optional Redis-backed state.

- failsafe-py offers **count based and time based** thresholding, including a failure *rate* over a period. pybreaker thresholds on consecutive failures only, which cannot express "20% of the last minute".
- failsafe-py's half-open state admits a **bounded** number of concurrent trials. pybreaker admits callers into half-open without that cap, so every caller queued during the reset timeout can hit a recovering service at once.
- failsafe-py breakers [compose][policy-composition] with retries, timeouts, bulkheads and fallbacks under one ordering model.
- failsafe-py breakers can threshold on **results**, not just exceptions — useful when a 500 response is not an exception.
- pybreaker offers distributed state via Redis, which failsafe-py does not. If you need breaker state shared across processes, that is a real advantage and failsafe-py has no answer for it today.

### failsafe-py vs circuitbreaker

[circuitbreaker] is a small decorator-only circuit breaker.

- It is deliberately minimal: a decorator, a failure threshold, a recovery timeout. failsafe-py's breaker is a superset.
- It has no half-open trial cap, no rate thresholding, and no composition with other policies.
- Its decorator-per-function model makes the [fragmentation hazard][policy-sharing] the default: each decorated function gets its own breaker state unless you pass a shared instance.

## Load Limiting

Here there is no close comparison to draw. [Adaptive limiters][adaptive-limiters], [adaptive throttlers][adaptive-throttlers] and [prioritized load shedding][execution-prioritization] have no widely-used Python equivalent — the nearest implementations are in Go and Java — so the comparison would be against nothing.

`limits` and `pyrate-limiter` cover [rate limiting][rate-limiters] specifically, and do it well, with backing stores failsafe-py does not provide. They do not limit *concurrency*, which is usually what protects a system; see [load limiting][load-limiting] for why that distinction matters.

## Hedging

No widely-used Python hedging library exists. failsafe-py's [HedgePolicy][hedge] is async-only, for reasons covered on that page.

{% include common-links.html %}

[tenacity]: https://github.com/jd/tenacity
[backoff]: https://github.com/litl/backoff
[pybreaker]: https://github.com/danielfm/pybreaker
[circuitbreaker]: https://github.com/fabfuel/circuitbreaker
