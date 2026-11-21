---
layout: default
title: Porting from failsafe-go
---

# Porting from failsafe-go
{: .no_toc }

1. TOC
{:toc}

failsafe-py is a port of [failsafe-go]: same policies, same composition model, same failure-handling semantics, same event model. This page is for people who already know the Go library — it covers what is named differently and, more importantly, where behaviour differs.

If you have not used failsafe-go, you do not need this page. Start at [Getting Started][home].

## What Is the Same

Composition order, failure-handling semantics, and policy behaviour are ported deliberately, including the parts that are easy to get wrong:

- Conditions are OR'ed, and a result-only condition does **not** replace the default "any error is a failure".
- Half-open admits a bounded number of trial executions, not every waiting caller.
- A retry delay is clamped so a long backoff never overshoots `max_duration`.
- A `Timeout` overwrites an already-recorded inner result, and can be retried by an outer retry policy.
- A bulkhead permit is held per *attempt*, so an inner retry re-acquires it.
- Time-based windows expire buckets on write only: a window nobody has written to still reports its last totals.
- The throttler's execution padding keeps the rejection rate strictly below 1 at low execution counts.
- A smooth rate limiter reserves the interval *before* the permit, so the first caller of an idle limiter waits zero.

Go's own test corpus for the circuit breaker, retry policy, rate limiter, bulkhead, adaptive limiter, throttler and prioritizer was ported alongside the code, which is what pins these.

## Name Mapping

| failsafe-go | failsafe-py |
|---|---|
| `failsafe.With(p1, p2).Get(fn)` | `Failsafe(p1, p2).call(fn)` |
| `failsafe.With(p1, p2).Run(fn)` | `Failsafe(p1, p2).call(fn)` — no `Run`/`Get` split |
| `failsafe.With(...).RunAsync(fn)` | `asyncio.create_task(AsyncFailsafe(...).call(fn))` |
| `retrypolicy.NewBuilder[R]().WithMaxRetries(3).Build()` | `RetryPolicy(max_retries=3)` |
| `.HandleErrors(e)` / `.HandleErrorTypes(e)` | `handle=SomeError` |
| `.HandleResult(v)` | `handle=Result(v)` |
| `.HandleIf(pred)` | `handle=lambda result, exc: ...` |
| `.AbortOnErrors(e)` / `.AbortIf(pred)` | `abort=SomeError` / `abort=lambda r, e: ...` |
| `.WithDelay(d)` | `delay=1.0` |
| `.WithBackoff(d, max)` | `delay=Backoff(1.0, 30.0)` |
| `.WithJitterFactor(f)` | `delay=Backoff(1.0, 30.0, jitter=Jitter(factor=f))` |
| `.WithMaxAttempts(n)` | `max_retries=n - 1` — only `max_retries` is provided |
| `.OnRetry(listener)` | `on_retry=listener` |
| `exec.Context()` | `current_execution()` |
| `circuitbreaker.NewWithDefaults[any]()` | `CircuitBreaker()` |
| `ratelimiter.NewSmooth(n, p)` / `NewBursty(n, p)` | `RateLimiter.smooth(n, p)` / `RateLimiter.bursty(n, p)` |
| `adaptivelimiter.NewBuilder[R]().BuildPrioritized(p)` | `AdaptiveLimiter().prioritized_by(p)` |
| `priority.High.AddTo(ctx)` | `with priority_scope(Priority.HIGH):` |
| `priority.ContextWithUser(ctx, u)` | `with user_scope(u):` |
| `failsafehttp.NewRoundTripper(...)` | `failsafe.httpx.FailsafeTransport(...)` |
| `Policy[R]` / `ResultAgnosticPolicy[any]` | one `Policy` base — see [type safety][type-safety] |
| `ComposeAny`, `WithAny`, `ToExecutor(typeToken)` | not needed |

Builders are gone everywhere: every policy takes keyword arguments, and union-typed parameters collapse the clusters Go spreads across many setters. `delay=` alone replaces `WithDelay`, `WithDelayFunc`, `WithBackoff`, `WithBackoffFactor`, `WithRandomDelay`, `WithJitter` and `WithJitterFactor`.

## Behavioural Differences

These are the ones that will surprise you. The rest of the differences are mechanical.

### 1. Hedging Is Async-Only

[`HedgePolicy`][hedge] works under `AsyncFailsafe`. Under `Failsafe` it raises `NotImplementedError`.

Hedging needs cancellable concurrency. Sync Python has none, and a thread-pool version would silently leak a thread per losing hedge while shipping weaker-than-Go semantics under the same policy name. This is the one capability gap versus failsafe-go.

### 2. No Externally-Triggered Cancellation in Sync Mode

`exec.IsCanceled()` and `exec.Canceled()` have no sync equivalent, and `Execution` has no `cancelled` attribute. Sync code gets **deadlines**: `Execution.remaining()`, `Timeout`, and `max_duration`.

No mainstream sync Python library accepts a cancel token — `requests`, `urllib` and the DB-API drivers all take a timeout — so a cancellation channel would be API surface nothing cooperates with. Async mode has real cancellation, via asyncio. See [cancellation and deadlines][execution-cancellation].

### 3. No Async Execution Handle

`RunAsync` and `ExecutionResult` are not ported. Use [`asyncio.Task`][asyncio-task], which already provides done, result and cancel. See [async execution][async-execution].

### 4. Listener Exceptions Are Logged, Not Propagated

Go lets a panic in a listener escape. Here a raising listener is logged and the execution continues: a metrics bug must not break a production request.

### 5. Listeners Are Lists, Not Single Slots

Go's `OnRetry(fn)` overwrites any previously registered listener. Ours appends, and every listener keyword accepts a callable or a sequence of them:

```python
retry = RetryPolicy(on_retry=[log_retry, count_retry])
retry.on_retry.add(trace_retry)
```

### 6. `CancelledError` Is Never a Failure

The core catches `Exception`, never `BaseException`. `KeyboardInterrupt`, `SystemExit` and especially `asyncio.CancelledError` propagate untouched: a cancelled task is not a retryable failure, and no policy records it, retries it, or substitutes a fallback for it.

### 7. No `Compose` — a Composition Is Fixed at Construction

Go's `Compose` mutates the receiver, so extending a shared `Executor` changes it for every existing user. There is no equivalent method; pass every policy to the constructor, and build a second `Failsafe` from the same policy objects when you want a different composition.

```python
plain = Failsafe(fallback, retry)
guarded = Failsafe(fallback, retry, breaker)
```

### 8. No `with` Form for Permit Policies

Standalone permits are plain methods:

```python
bulkhead.acquire_permit()
try:
    ...
finally:
    bulkhead.release_permit()
```

Anyone who wants a context manager can wrap it in three lines of `contextlib`; one shape with no per-policy exceptions was the simpler trade.

### 9. `max_duration` Is Compared With `>=`, Not Go's `>`

Go only escapes a strict comparison because its wall clock drifts past the budget. With an injected clock the retry delay is clamped to land exactly on `max_duration`, where `>` would loop forever.

### Smaller Divergences

| Area | Difference |
|---|---|
| Sync `Timeout` | Cooperative unless `interrupt=True`. With `interrupt=True` the caller is released on time, but the abandoned worker thread runs to completion |
| Cache keys | Derived from call arguments via a `key=` callable, not from a context value |
| `CircuitBreaker` manual transitions | A callable `delay=` yields no delay for `breaker.open()`. Go keeps `DelayFunc` and `Delay` in separate fields; a single `delay=` union has nothing to fall back to |
| `AdaptiveThrottler` | `record_result(outcome)` replaces `RecordResult` and `RecordError`; takes no `abort=`, because Go's builder exposes none |
| Throttled rejections | `on_success`/`on_failure` do not fire, matching Go: a rejection is not an execution result and is not recorded in the window |
| Randomness | `RetryPolicy`, `CircuitBreaker`, `AdaptiveThrottler` and `AdaptiveLimiter` each take `rng=`, where Go seeds the global `math/rand` |
| `RateLimiter` | Two classmethods replace Go's four constructors and two builders |
| Adaptive limiter quantiles | An exact sorted window replaces Go's t-digest. At the 50–500 samples this policy actually sees, the digest carries 0.4–2.7% error and the window carries none |
| Priority and user | `priority_scope`, `level_scope` and `user_scope` contextvars replace `ContextWithPriority` / `ContextWithLevel` / `ContextWithUser` |
| `Priority` | An `IntEnum`; absence is `None`, not Go's `-1`, which cannot be mistaken for a valid level |
| Prioritized policies | `prioritized_by(p)` instead of a separate `PriorityLimiter` / `PriorityThrottler` type from `BuildPrioritized` |
| Calibration | `Prioritizer.calibrate()` is explicit, and `scheduled_calibrations(interval)` is an opt-in context manager that joins its thread on exit, rather than Go's goroutine plus `CancelFunc` |

### HTTP Differences

| Area | Difference |
|---|---|
| `408 Request Timeout` | Retryable here; Go retries only 429 and 5xx-except-501. A 408 is the server saying it gave up waiting, which is exactly what a retry addresses |
| Policy rejections | Surface as `httpx.TransportError` with the original chained as `__cause__`, so existing `except httpx.HTTPError` blocks are not bypassed |
| `retry_policy()` | Defaults `return_last_failure=True`: exhausting retries on a failing *response* yields that response, as Go does |
| `retry_after_delay` | Also honours the HTTP-date form of `Retry-After`, which Go ignores. Returns `0.0` where Go's `DelayFunc` returns `-1` |
| `failsafehttp.Request` | No equivalent. httpx exposes the same hook for both cases, so one transport covers it |
| Clock injection | Both transports accept `clock=`, so a `Retry-After` test need not sleep for real |

## One Hazard Worth Stating Plainly

Stateful policies model the health of a **backend**, not of a call site. Python's decorator syntax makes the wrong thing easy to write by accident:

```python
# wrong: two independent breakers, each seeing half the traffic
@Failsafe(retry, CircuitBreaker())
def charge(amount): ...

@Failsafe(retry, CircuitBreaker())
def refund(txn): ...
```

```python
# correct: one breaker for everything that talks to this backend
payments = Failsafe(retry, CircuitBreaker(), AdaptiveThrottler())

@payments
def charge(amount): ...

@payments
def refund(txn): ...
```

Stateless policies — `RetryPolicy`, `Fallback`, `Timeout` — are safe to construct inline. Everything stateful must be hoisted: `CircuitBreaker`, `AdaptiveThrottler`, `AdaptiveLimiter`, `Bulkhead`, `RateLimiter`, `Budget`. This mirrors failsafe-go, where policies are documented as safe to share and intended to be shared.

## Not Ported

- **gRPC integration** (`failsafegrpc`) — out of scope.
- **Server-side HTTP helpers** (`NewHandler`, `NewHandlerWithLevel`) — deferred. When they land they will keep Go's `X-Failsafe-Priority` and `X-Failsafe-Level` header names so Python and Go services interoperate.

{% include common-links.html %}
