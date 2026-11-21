# failsafe-py docs — section review against failsafe-go.dev

I added a lot of prose the Go docs do not have: **+41% overall** (7,708 → 10,878 words),
with 60+ sections that have no Go counterpart. This file lists every one so you can rule
on them in bulk instead of finding them page by page.

## How to use this

Each section below has a `VERDICT: ?` line. Replace `?` with:

| verdict | meaning |
|---|---|
| `cut` | delete the section |
| `trim` | keep it, drop the implementation detail |
| `keep` | fine as is |
| *free text* | tell me what you want instead |

Blanket rules work too — write them here and I will apply them everywhere:

    BLANKET: ?

e.g. `BLANKET: cut every NEW section that explains internals; keep NEW sections that
document a parameter or method that exists in Python but not Go`.

Sections left as `?` are untouched.

## Tags

- **NEW** — no Go counterpart. I wrote it.
- **GROWN** — exists in Go, my version is materially longer.
- **SAME** / **SHRUNK** — not listed in the index below; shown in the detail only.

---

## Index

| page | go→py words | NEW | GROWN |
|---|---|---|---|
| [`comparisons.md`](#comparisonsmd) | 349 → 676 (+327) | 6 | 1 |
| [`extending.md`](#extendingmd) | 87 → 397 (+310) | 6 | 0 |
| [`execution-cancellation.md`](#execution-cancellationmd) | 123 → 422 (+299) | 7 | 0 |
| [`async-execution.md`](#async-executionmd) | 70 → 331 (+261) | 5 | 0 |
| [`hedge.md`](#hedgemd) | 222 → 475 (+253) | 2 | 4 |
| [`execution-prioritization.md`](#execution-prioritizationmd) | 449 → 678 (+229) | 3 | 3 |
| [`execution-info.md`](#execution-infomd) | 86 → 295 (+209) | 5 | 0 |
| [`timeout.md`](#timeoutmd) | 193 → 387 (+194) | 3 | 1 |
| [`policies.md`](#policiesmd) | 667 → 853 (+186) | 5 | 2 |
| [`http.md`](#httpmd) | 342 → 495 (+153) | 5 | 2 |
| [`type-safety.md`](#type-safetymd) | 108 → 261 (+153) | 4 | 0 |
| [`execution-budgets.md`](#execution-budgetsmd) | 216 → 336 (+120) | 1 | 4 |
| [`event-listeners.md`](#event-listenersmd) | 190 → 306 (+116) | 3 | 0 |
| [`cache.md`](#cachemd) | 118 → 221 (+103) | 2 | 1 |
| [`bulkhead.md`](#bulkheadmd) | 271 → 359 (+88) | 1 | 2 |
| [`index.md`](#indexmd) | 181 → 254 (+73) | 2 | 1 |
| [`retry.md`](#retrymd) | 318 → 380 (+62) | 3 | 1 |
| [`adaptive-throttler.md`](#adaptive-throttlermd) | 383 → 416 (+33) | 1 | 3 |
| [`fallback.md`](#fallbackmd) | 122 → 145 (+23) | 0 | 1 |
| [`rate-limiter.md`](#rate-limitermd) | 419 → 440 (+21) | 0 | 2 |
| [`load-limiting.md`](#load-limitingmd) | 603 → 603 (+0) | 2 | 1 |
| [`circuit-breaker.md`](#circuit-breakermd) | 674 → 587 (-87) | 0 | 2 |
| [`adaptive-limiter.md`](#adaptive-limitermd) | 1222 → 990 (-232) | 1 | 0 |
| **total** | **7708 → 10878 (+3170)** | **67** | **31** |

---


## `comparisons.md`

go 349w → py 676w (+327)


### NEW · `# Comparisons` (intro) · 0w → 73w

VERDICT: ?

_Go page has no prose here._

py:

> How failsafe-py differs from the Python libraries that solve part of the same problem. Only libraries in wide use are covered; obscure ones are a disservice to compare against. The honest summary: if you need **only** retries, [tenacity] is mature, widely deployed and a perfectly good choice. failsafe-py earns its place when you need several policies that must work together, or when you need the same policy to guard sync and async callers.


### NEW · `### failsafe-py vs tenacity` · 0w → 226w

VERDICT: ?

py:

> [tenacity] is the de-facto Python retry library, and a fork of the older `retrying`. It differs from failsafe-py's [RetryPolicy][retry] in a few ways: - failsafe-py retries are one policy among several that **compose**. tenacity solves retries only; a circuit breaker or bulkhead alongside it is a separate library with its own ordering semantics to reason about. - failsafe-py combines retry settings through a single constructor. tenacity composes `stop_*`, `wait_*` and `retry_*` objects, which is flexible but spreads one policy across several imports. - failsafe-py shares one policy instance between sync and async callers. tenacity has `Retrying` and `AsyncRetrying` as separate classes. - failsafe-py retries can be [aborted][aborts] on specific results, exceptions, or conditions, failing fast rather than exhausting the attempts. - failsafe-py retries can be bounded system-wide by a [budget][budgets], which caps the share of in-flight work that retries may become. tenacity has no cross-call notion of retry load. - failsafe-py never retries `BaseException`. `asyncio.CancelledError` is terminal by construction, which is the most common correctness bug in this category. - failsafe-py jitter is attached to the delay, so it cannot be configured where it does nothing. - tenacity's …


### NEW · `### failsafe-py vs backoff` · 0w → 86w

VERDICT: ?

py:

> [backoff] is a decorator-based retry library with exponential backoff and jitter. It is less actively developed than tenacity but still widely installed. - Same compositional point as above: backoff is retries only. - backoff decorates a function at definition time. failsafe-py's [`Failsafe`][policy-sharing] object is built once and applied at as many call sites as you like, which matters for the stateful policies it composes with. - backoff's `max_time` and failsafe-py's `max_duration` are equivalent; failsafe-py additionally clamps the delay so a long backoff never overshoots the budget.


### NEW · `### failsafe-py vs pybreaker` · 0w → 152w

VERDICT: ?

py:

> [pybreaker] is the most established Python circuit breaker, a port of Michael Nygard's pattern with a listener model and optional Redis-backed state. - failsafe-py offers **count based and time based** thresholding, including a failure *rate* over a period. pybreaker thresholds on consecutive failures only, which cannot express "20% of the last minute". - failsafe-py's half-open state admits a **bounded** number of concurrent trials. pybreaker admits callers into half-open without that cap, so every caller queued during the reset timeout can hit a recovering service at once. - failsafe-py breakers [compose][policy-composition] with retries, timeouts, bulkheads and fallbacks under one ordering model. - failsafe-py breakers can threshold on **results**, not just exceptions — useful when a 500 response is not an exception. - pybreaker offers distributed state via Redis, which failsafe-py does not. If you need breaker state shared across processes, that is a real advantage and failsafe-py has no answer for it today.


### NEW · `### failsafe-py vs circuitbreaker` · 0w → 65w

VERDICT: ?

py:

> [circuitbreaker] is a small decorator-only circuit breaker. - It is deliberately minimal: a decorator, a failure threshold, a recovery timeout. failsafe-py's breaker is a superset. - It has no half-open trial cap, no rate thresholding, and no composition with other policies. - Its decorator-per-function model makes the [fragmentation hazard][policy-sharing] the default: each decorated function gets its own breaker state unless you pass a shared instance.


### NEW · `## Load Limiting` · 0w → 58w

VERDICT: ?

py:

> There is no close comparison to draw. [Adaptive limiters][adaptive-limiters], [adaptive throttlers][adaptive-throttlers] and [prioritized load shedding][execution-prioritization] have no widely-used Python equivalent. `limits` and `pyrate-limiter` cover [rate limiting][rate-limiters] specifically, and do it well, with backing stores failsafe-py does not provide. They do not limit *concurrency*, which is usually what protects a system; see [load limiting][load-limiting] for why that distinction matters.


### NEW · `## Hedging` · 0w → 16w

VERDICT: ?

py:

> No widely-used Python hedging library exists. failsafe-py's [HedgePolicy][hedge] is async-only, for reasons covered on that page.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Failsafe-go vs cenkalti/backoff`
- `### Failsafe-go vs gobreaker`
- `## Hedges`
- `### Failsafe-go vs cristalhq/hedgedhttp`


## `extending.md`

go 87w → py 397w (+310)


### NEW · `## The Policy Protocol` · 0w → 80w

VERDICT: ?

py:

> A policy wraps an inner step and returns a new one: A `Step` is a callable taking the [`Execution`][execution-info] and returning a **generator** that yields *instructions* and finally returns an `Outcome`. The generator is the policy's logic; the driver decides how to service what it yields. This is why the same policy works in both sync and async mode: a policy never sleeps, never blocks, and never spawns anything. It yields `Sleep(1.0)` and the driver calls `time.sleep` or `await asyncio.sleep`.


### NEW · `## A Minimal Policy` · 0w → 35w

VERDICT: ?

py:

> A policy that logs each attempt and passes everything through: `yield from inner(ex)` is how policies nest: it forwards every instruction the inner policies yield out to the driver, and gives back their final `Outcome`.


### NEW · `## Instructions` · 0w → 64w

VERDICT: ?

py:

> | Instruction | Serviced as | |---|---| | `Invoke()` | Call the user function, capturing an `Outcome`. Catches `Exception`, never `BaseException` | | `Sleep(seconds)` | `time.sleep` or `await asyncio.sleep`, interruptible by cancellation | | `Acquire(semaphore, timeout)` | A blocking or awaiting permit acquisition against one shared semaphore | | `Race(inner, seconds, interrupt)` | Run `inner` under a deadline | A retry policy is roughly:


### NEW · `## Rules` · 0w → 108w

VERDICT: ?

py:

> **Release in `finally`.** A driver may abandon an execution by closing the generator — a deadline elapsing, a hedge losing. Anything acquired must be released on the way out: **Per-execution state belongs in the generator.** Policies are shared across concurrent executions, so anything that varies per execution — a backoff's current delay, an attempt counter — lives in the generator's local scope. Anything on `self` is shared and needs a lock. **Never catch `BaseException`.** `CancelledError` must propagate. **Failure conditions, if you have them**, should reuse `Condition` so your policy's `handle=` behaves like everyone else's, including the rule that a result-only condition does not replace the default error handling.


### NEW · `## Reference Implementations` · 0w → 42w

VERDICT: ?

py:

> The built-in policies are the best reference, and they are small. [`Fallback`][fallbacks] is about 30 lines of logic and shows the minimum shape; [`RetryPolicy`][retry] shows delays and listeners; [`Bulkhead`][bulkheads] shows permit handling with `finally`; [`CircuitBreaker`][circuit-breakers] shows shared locked state. See the [source][github].


### NEW · `## Private API` · 0w → 53w

VERDICT: ?

py:

> `Step`, `Outcome`, `Invoke`, `Sleep`, `Acquire` and `Race` live in `failsafe._core` and are not exported from the package root. They are stable enough to build against — every built-in policy uses them — but they are not covered by the public API's compatibility promise. If you ship a policy publicly, pin a version range.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Custom Policies`


## `execution-cancellation.md`

go 123w → py 422w (+299)


### NEW · `# Cancellation and Deadlines` · 0w → 81w

VERDICT: ?

py:

> `Failsafe` and `AsyncFailsafe` differ here more than anywhere else. Async has real cancellation; sync has deadlines only. | | Async | Sync | |---|---|---| | Deadline from a [`Timeout`][timeouts] | Interrupts the attempt | Cooperative, or a worker thread with `interrupt=True` | | Deadline from `max_duration` | Enforced between attempts | Enforced between attempts | | Externally triggered cancellation | `task.cancel()` | **Not supported** | | Reaching downstream code | Cancellation propagates for free | Pass `remaining()` to your I/O |


### NEW · `## Async Cancellation` · 0w → 90w

VERDICT: ?

py:

> Async cancellation is ordinary asyncio cancellation — there is nothing library-specific to learn: [`CancelledError`][cancelled-error] propagates out untouched. No policy retries it, records it, or substitutes a fallback for it; the core catches `Exception`, never `BaseException`. A cancelled task is not a failing backend. A [`Timeout`][timeouts] in async mode interrupts the attempt via [`asyncio.timeout`][asyncio-timeout] and surfaces as `TimeoutExceeded`, which *is* an ordinary failure and can be retried by an outer [`RetryPolicy`][retry]. That distinction is the whole reason `Timeout` exists alongside cancellation. Outstanding [hedge][hedge] executions are cancelled once a successful result arrives.


### NEW · `## Deadlines in Sync Mode` · 0w → 58w

VERDICT: ?

py:

> Sync code sets a deadline; it does not get cancelled from another thread. `remaining()` returns the seconds left before the nearest deadline — from a `Timeout`, a retry `max_duration`, or both — or `None` when nothing has set one. The deadline is enforced between attempts; *within* an attempt, cooperation is yours, which is what the snippet above does.


### NEW · `### Why There Is No Sync Cancellation` · 0w → 72w

VERDICT: ?

py:

> `Execution` has no `cancelled` attribute. Python cannot interrupt a running call, so a cancellation channel would only work if downstream code polled it. No mainstream sync library accepts one: `requests`, `urllib` and the DB-API drivers all take a *timeout*. A `threading.Event` on the execution would be API surface that nothing cooperates with, and it would look like a cancellation guarantee while providing none. Removing the concept is more honest than faking it.


### NEW · `### Interrupting Timeouts` · 0w → 56w

VERDICT: ?

py:

> `Timeout(..., interrupt=True)` is the escape hatch when the call you wrap accepts no timeout of its own: The caller is freed on time. The abandoned worker thread runs to completion — Python has no way to kill a thread — so this bounds *caller latency*, not resource use. Prefer a real I/O timeout where one exists.


### NEW · `## Propagating Cancellation Downstream` · 0w → 26w

VERDICT: ?

py:

> In async mode, propagation is free. Cancelling the task cancels whatever it is awaiting, including an in-flight [httpx][http] request: In sync mode, propagate the deadline instead:


### NEW · `## Timeout vs Cancellation` · 0w → 39w

VERDICT: ?

py:

> A `TimeoutExceeded` can be retried by an outer `RetryPolicy`; a `CancelledError` cannot. Prefer a `Timeout` when you want to bound execution time or combine it with retries, and cancel the task when you want the whole execution to stop.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `# Execution Cancellation`
- `## Propagating Cancellations`
- `## Cooperative Cancellation`
- `## Timeout vs Context Cancellation`


## `async-execution.md`

go 70w → py 331w (+261)


### NEW · `## It Is Just a Coroutine` · 0w → 27w

VERDICT: ?

py:

> `AsyncFailsafe.call` returns a coroutine, so everything asyncio offers works on it. There is no execution handle to learn: Fan-out is whatever asyncio offers, not a bespoke API:


### NEW · `## Sharing Policies Between Both Worlds` · 0w → 104w

VERDICT: ?

py:

> A policy object carries its own state and is safe to use from `Failsafe` and `AsyncFailsafe` at once. One `CircuitBreaker` guarding a backend sees every caller, whether that caller is a thread or a task: A failure recorded through `sync_payments` opens the breaker for `async_payments` too. The same holds for a [`Bulkhead`][bulkheads], [`RateLimiter`][rate-limiters] or [`AdaptiveLimiter`][adaptive-limiters]: one permit count serves both, with waiters admitted in arrival order regardless of which driver they came from. This matters wherever a sync worker and an async service talk to the same backend, and it is the reason the library is built around one engine rather than two implementations.


### NEW · `## Cancellation` · 0w → 50w

VERDICT: ?

py:

> Async cancellation is ordinary asyncio cancellation. Cancelling the task cancels the in-flight attempt, and [`CancelledError`][cancelled-error] propagates out untouched — it is never treated as a retryable failure, never swallowed by a [`Fallback`][fallbacks], and never recorded by a breaker. Sync mode has deadlines but no externally-triggered cancellation. See [cancellation and deadlines][execution-cancellation].


### NEW · `## What Only Works in Async Mode` · 0w → 65w

VERDICT: ?

py:

> - [Hedging][hedge] requires cancelling the losing attempts, which sync Python cannot do. `HedgePolicy` under `Failsafe` raises `NotImplementedError`. - [`Timeout`][timeouts] interrupts the attempt itself, via [`asyncio.timeout`][asyncio-timeout]. In sync mode a timeout is cooperative unless `interrupt=True`, which frees the caller but leaves the abandoned thread running. Everything else — retries, circuit breaking, rate limiting, bulkheads, adaptive limiting, throttling, fallbacks, caching, budgets — is identical in both modes.


### NEW · `## Listeners Are Sync` · 0w → 35w

VERDICT: ?

py:

> [Event listeners][event-listeners] are plain functions, not coroutines — a coroutine listener cannot be awaited from sync code. Listeners are for logging and metrics; if one needs to do I/O, hand the work to a task:


## `hedge.md`

go 222w → py 475w (+253)


### GROWN · `# Hedge` · 55w → 107w

VERDICT: ?

<details><summary>go</summary>

> [Hedge policies][HedgePolicy] are a way of bringing down long tail latencies by performing additional executions, after some delays, if the initial execution is slow to complete. This differs from retry policies since multiple hedged executions may be in progress at the same time. After the first successful execution is returned, the remaining executions are canceled.

</details>

py:

> Hedge policies bring down long tail latencies by starting additional executions, after some delay, if the initial execution is slow to complete. This differs from a [retry policy][retry] since multiple hedged executions may be in progress at the same time. After the first accepted result arrives, the remaining executions are cancelled. The tail of a latency distribution is usually not the service being slow but one request being unlucky: a stalled connection, an unlucky GC pause, a node about to be replaced. Retrying only after a timeout pays the timeout first; a hedge starts a second attempt while the first is still running and takes whichever finishes.


### NEW · `## Async Only` · 0w → 47w

VERDICT: ?

py:

> `HedgePolicy` is supported under [`AsyncFailsafe`][async-execution]. Under `Failsafe` it raises `NotImplementedError`. Hedging needs cancellable concurrency. A synchronous call cannot be cancelled, so the losing attempts would run to completion against the very service the policy is trying to protect, and each would hold a thread until it did.


### GROWN · `### Dynamic Delay` · 66w → 128w

VERDICT: ?

<details><summary>go</summary>

> The hedging pattern was first described in [The Tail at Scale][tail-at-scale], which recommends setting a hedging delay equal to the current p95 or p99 latency of your executions. This ensures that if latencies change, you're only targeting long tail requests and don't unintentionally perform hedged executions too early. With this in mind, you can configure a dynamic delay for a [HedgePolicy], based on a function result:

</details>

py:

> The hedging pattern was first described in [The Tail at Scale][tail-at-scale], which recommends a hedging delay equal to the current p95 or p99 latency. That way, if latencies change, you keep targeting the long tail rather than hedging too early. A callable delay computes one per attempt from the [execution][execution-info]: Returning `None` stops hedging for that execution. The policy can also track the quantile itself, which is the usual reason to want a dynamic delay: Exactly one of `delay` and `quantile` is required. `quantile_age` is how many executions the estimate remembers — smaller adapts faster, larger is steadier. `warmup` is how many executions to observe before hedging at all: hedging on an estimate drawn from a handful of samples is how a cold start becomes a thundering herd.


### GROWN · `### Cancellation` · 31w → 50w

VERDICT: ?

<details><summary>go</summary>

> By default, any outstanding hedges are canceled after the first result is returned. You can also specify that only certain results, errors, or conditions should cause outstanding hedges to be canceled:

</details>

py:

> By default any outstanding hedges are cancelled after the first result arrives, whatever it is. You can specify which results, exceptions, or conditions should end the execution, using the same [`Condition`][failure-handling] type as everywhere else: An outcome that does not match is not accepted, and the remaining attempts keep running.


### GROWN · `### Budgets` · 16w → 60w

VERDICT: ?

<details><summary>go</summary>

> [Budgets][budgets] can be added to hedge policies to control the max outstanding hedges across a system:

</details>

py:

> Hedges multiply load. Every attempt is a real request, so a policy that hedges eagerly turns a slow dependency into an overloaded one. Hedge on a delay well into the tail, and give the policy a [`Budget`][budgets] when the dependency is shared: When the budget is spent the policy simply stops hedging; the attempts already running still produce a result.


### NEW · `## Execution Info` · 0w → 34w

VERDICT: ?

py:

> Hedges count as attempts. `Execution.attempts` and `Execution.hedges` both increment, and `is_hedge` distinguishes a hedged attempt from the original: The winning attempt cancels the losers with its own result, rather than with a cancellation error.


## `execution-prioritization.md`

go 449w → py 678w (+229)


### NEW · `## Calibration Is Yours to Schedule` · 0w → 89w

VERDICT: ?

py:

> Nothing recalculates on its own. Call `calibrate()` on whatever schedule you already have: Or scope a background thread to a block, which joins it on exit: A library silently owning an OS thread interacts badly with `fork`, with test suites, and with anyone running under an event loop who never asked for a thread. The context manager makes the thread's lifetime lexical. There is no async variant. Calibration is pure CPU over in-memory counters with no awaits, so an asyncio user can call `calibrate()` from their own [`TaskGroup`][task-group] loop.


### GROWN · `## Prioritized Execution` · 30w → 53w

VERDICT: ?

<details><summary>go</summary>

> To perform an execution with a priority, provide a context containing the priority to Failsafe: When a policy is exceeded, executions are rejected based on the associated Prioritizer's rejection threshold.

</details>

py:

> Priority is ambient, carried in a [contextvar][contextvars] rather than threaded through every signature: Contextvars propagate into tasks and threads the library starts, so a nested helper several frames down executes at the right priority without a parameter reaching it. When a policy is exceeded, executions are rejected based on the prioritizer's rejection threshold.


### GROWN · `## Priorities vs Levels` · 40w → 77w

VERDICT: ?

<details><summary>go</summary>

> In order to enable more granular prioritization of executions, priorities are internally converted to more granular levels, with 100 levels per priority class. In practice, Prioritizers use these levels to determine which executions to reject, allowing more precise rejection rates.

</details>

py:

> To enable more granular prioritization, priorities are internally converted to levels, with 100 levels per priority class, numbered 0–499. Prioritizers use levels to determine what to reject, allowing precise rejection rates: load within a single priority sheds gradually rather than all at once. A level is normally picked at random within the priority in scope. To pin an exact one: Read what is in scope with `current_priority()`, `current_level()` and `current_user()`; all return `None` when nothing is set.


### NEW · `### Metrics` · 0w → 35w

VERDICT: ?

py:

> | | | |---|---| | `prioritizer.rejection_rate` | share being rejected, 0 to 1 | | `prioritizer.rejection_threshold` | the level below which executions are rejected | | `prioritizer.registered_policies` | how many policies report to it |


### NEW · `### HTTP Support` · 0w → 18w

VERDICT: ?

py:

> When using HTTP, priority and level information can be propagated from clients to servers. See the [HTTP docs][http-priorities].


### GROWN · `## Best Practices` · 37w → 80w

VERDICT: ?

<details><summary>go</summary>

> [Prioritizers][Prioritizer] can and should be shared across multiple limiters when possible. This allows a combined rejection threshold to be determined across limiters, which takes their combined queueing levels into account, and leads to more stable rejection behavior.

</details>

py:

> Prioritizers can and should be shared across multiple limiters where possible. A combined threshold across limiters accounts for their combined queueing and leads to more stable rejection behaviour. {: .callout } > A prioritized limiter with exactly **one** registered policy short-circuits on local capacity and ignores the threshold, so it need not wait for the next calibration. With two or more it defers entirely to the shared threshold. Tests that want to exercise threshold behaviour must register a second policy.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Logging and Metrics`
- `### HTTP and gRPC Support`


## `execution-info.md`

go 86w → py 295w (+209)


### NEW · `## What It Carries` · 0w → 161w

VERDICT: ?

py:

> | Attribute | Meaning | |---|---| | `attempts` | Attempts started, including hedges | | `executions` | Attempts that actually reached the function | | `retries` | Retries performed so far | | `hedges` | Hedged attempts started | | `start_time` | When the execution began, on the configured clock | | `elapsed` | Seconds since the execution began | | `attempt_start_time` | When the current attempt began | | `elapsed_attempt` | Seconds since the current attempt began | | `last_result` | The previous attempt's result | | `last_exception` | The previous attempt's exception | | `args` / `kwargs` | The arguments the execution was called with | | `is_first_attempt` | Whether this is the first attempt | | `is_retry` | Whether this attempt is a retry | | `is_hedge` | Whether this attempt is a hedge | | `deadline` | The absolute deadline, if any policy set one | | `remaining()` | Seconds left before the deadline, or `None` |


### NEW · `## Depending on a Previous Attempt` · 0w → 21w

VERDICT: ?

py:

> This is useful for executions that build on a previous attempt's result: Or for branching on how the attempt was reached:


### NEW · `## Deadlines` · 0w → 34w

VERDICT: ?

py:

> `remaining()` is how a sync execution cooperates with a [`Timeout`][timeouts] or a retry `max_duration`. Size your own I/O timeout from it: It returns `None` when nothing has set a deadline. See [cancellation and deadlines][execution-cancellation].


### NEW · `## In Listeners` · 0w → 16w

VERDICT: ?

py:

> [Event listeners][event-listeners] receive an event that carries the execution, so the same information is available there:


### NEW · `## Async` · 0w → 18w

VERDICT: ?

py:

> Identical — `current_execution()` works in a coroutine, because contextvars are per-task: Concurrent tasks each see their own execution.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Context`


## `timeout.md`

go 193w → py 387w (+194)


### GROWN · `## How It Works` · 28w → 89w

VERDICT: ?

<details><summary>go</summary>

> If an execution is canceled by a `Timeout`, the execution and policies composed inside the timeout will return `timeout.ErrExceeded`. See the [execution cancellation][execution-cancellation] page for more on cancellation.

</details>

py:

> When the limit elapses, the execution and any policies composed *inside* the timeout fail with `TimeoutExceeded`. How the attempt itself is affected: | | Behaviour | |---|---| | `AsyncFailsafe` | The attempt is interrupted, via [`asyncio.timeout`][asyncio-timeout]. `CancelledError` is raised inside the coroutine and converted to `TimeoutExceeded` at the boundary | | `Failsafe` | Cooperative by default. Python cannot interrupt a running call, so the limit is checked between attempts | | `Failsafe`, `interrupt=True` | The attempt runs on a worker thread and the caller is freed on time |


### NEW · `### Cooperative Timeouts in Sync Mode` · 0w → 58w

VERDICT: ?

py:

> A sync function that blocks for a minute under a one-second timeout still blocks for a minute — the timeout is observed once it returns. To make a sync timeout effective, read the remaining budget and hand it to whatever does the I/O: This is the sync pattern throughout the library: deadlines, not cancellation. See [cancellation and deadlines][execution-cancellation].


### NEW · `### Interrupting Timeouts` · 0w → 71w

VERDICT: ?

py:

> `interrupt=True` runs the attempt on a worker thread, so the caller is released on time: {: .callout } > The caller is freed, but **the abandoned thread runs to completion**. Python has no way to kill a thread. If the work it is doing is unbounded, this leaks a thread per timeout. Prefer passing `remaining()` into a real I/O timeout; use `interrupt=True` only when the call you wrap cannot accept one.


### NEW · `## Timeout vs Cancellation` · 0w → 79w

VERDICT: ?

py:

> A `TimeoutExceeded` can be retried by an outer `RetryPolicy`. An `asyncio.CancelledError` cannot: cancellation is terminal, propagates untouched, and is never treated as a failure by any policy. Prefer a `Timeout` when you want to bound execution time or combine it with retries. Cancel the task when you want the whole execution to stop. A timeout overwrites an already-recorded inner result: outer policies may still be processing that result, and must be interrupted rather than allowed to finish with it.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Timeout vs Context`


## `policies.md`

go 667w → py 853w (+186)


### NEW · `### Why `Result(...)` Is Explicit` · 0w → 32w

VERDICT: ?

py:

> `handle=None` would be ambiguous between "no condition configured" and "treat a returned `None` as a failure". Wrapping the value disambiguates it, which is what keeps `handle` from splitting into `handle=` and `handle_result=`.


### NEW · `### Results Do Not Replace Error Handling` · 0w → 30w

VERDICT: ?

py:

> A result-only condition **adds to** the default rather than replacing it. This policy retries both a `None` result and any exception: Only a condition that handles exceptions replaces the default.


### NEW · `### Exception Chains` · 0w → 53w

VERDICT: ?

py:

> An exception matches if it is an instance of a handled type, or if any exception in its `__cause__` chain is. The chain is walked depth-limited and only through `__cause__` — explicit chaining — because walking `__context__` would match exceptions raised incidentally while handling something else. For an `ExceptionGroup`, any matching leaf matches.


### GROWN · `## Policy Composition` · 65w → 110w

VERDICT: ?

<details><summary>go</summary>

> Policies can be composed in any way desired, including multiple policies of the same type. Policies are composed around a function from left to right, similar to have function composition works, where the inner-most policy handles a function result first. For example, consider: The same statement can also be written as: This results in the following composition when executing the `fn` and handling its result:

</details>

py:

> Policies can be composed in any way desired, including multiple policies of the same type. Policies are composed around a function from left to right, like function composition, where the inner-most policy handles a function result first: This results in the following composition when executing `fn` and handling its result: A composition is fixed at construction. To add a layer, build a new one from the same policy objects — which is safe, because policies are shareable: Both executors share `fallback` and `retry`, and `guarded` additionally applies `breaker`. There is no method that extends an executor in place, so a composition you hand to someone else cannot change under them.


### NEW · `### Composition and Exception Handling` · 0w → 60w

VERDICT: ?

py:

> While policies handle all `Exception` instances by default, it is common to configure a policy to handle something more specific, as [described above](#failure-handling): When doing so for a policy composed *around* other policies, you may also want it to handle the exceptions those inner policies raise: Every policy exception derives from `FailsafeError`, so `handle=FailsafeError` catches all of them at once.


### GROWN · `## Policy Sharing` · 46w → 76w

VERDICT: ?

<details><summary>go</summary>

> All policies are safe to share across different executions. While some policies such as [Retry Policy][retry] stateless, others such as [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Rate Limiter][rate-limiters], and [Bulkhead][bulkheads] are stateful, and are meant to be shared across different executions that access the same resources.

</details>

py:

> All policies are safe to share across executions, across threads, and between `Failsafe` and `AsyncFailsafe`. Some policies such as [Retry][retry] are stateless; others such as [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Rate Limiter][rate-limiters] and [Bulkhead][bulkheads] are stateful and are *meant* to be shared across executions that reach the same resource. A stateful policy models the health of a **backend**, not of a call site. Build the composition once, at module or DI scope, and reuse it:


### NEW · `### The Fragmentation Hazard` · 0w → 75w

VERDICT: ?

py:

> This is the mistake Python's decorator syntax makes easy: Each decorator builds its own breaker, so each sees a fraction of the traffic and none of them trips when the backend fails. No type checker can reject it — it is a valid constructor call — so it is a matter of discipline: hoist anything stateful. A lazy factory does not fix it either. Sharing is about *how many* policy objects get built, not *when*.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Composition and Error Handling`
- `### Mixing Result Types`


## `http.md`

go 342w → py 495w (+153)


### GROWN · `# HTTP Support` · 10w → 58w

VERDICT: ?

<details><summary>go</summary>

> Failsafe-go makes it easy to use any policies with HTTP.

</details>

py:

> failsafe-py integrates with [httpx] through a transport, so any [policy composition][policy-composition] applies to every request a client makes. [httpx] is the only client supported. It has both sync and async transports — the same dual shape as the core — and a transport hook that sees every request a client makes. `requests` is sync-only with no cancellation story.


### NEW · `### What Counts as Retryable` · 0w → 86w

VERDICT: ?

py:

> `is_retryable` is the default condition, and is usable on its own: | Retryable | Not retryable | |---|---| | Any `httpx.TransportError`: connection failures, timeouts, read errors | 4xx the server answered deliberately, other than 408 and 429 | | Status 408, 429, and 5xx other than 501 | Unsupported scheme, invalid URL, too many redirects | {: .callout } > **408 is treated as retryable.** It is the server saying it gave up waiting for the request, which is exactly the transient condition a retry addresses.


### NEW · `### Return Value` · 0w → 29w

VERDICT: ?

py:

> `retry_policy()` defaults `return_last_failure=True`: exhausting the retries on a failing *response* yields that response rather than raising `RetriesExceeded`. A 500 is still an answer the caller may want to inspect.


### GROWN · `## Handling Retry-After` · 22w → 58w

VERDICT: ?

<details><summary>go</summary>

> Other policies that support delays, such as [circuit breakers][circuit-breakers] can also be configured with a `failsafehttp.DelayFunc` that delays according to `Retry-After` headers:

</details>

py:

> `retry_after_delay` delays according to a response's `Retry-After` header, and works anywhere a callable delay is accepted: Both header forms RFC 9110 allows are honoured: delay-seconds, and an HTTP-date converted to a delay from now. Only 429 and 503 responses are consulted. A missing, past, or malformed header yields `0.0`, so the request is retried without an extra wait.


### NEW · `## Error Handling` · 0w → 45w

VERDICT: ?

py:

> A policy rejection that never reached the network — an open breaker, a full bulkhead — surfaces as `httpx.TransportError`, with the original chained as `__cause__`: httpx callers catch `httpx.HTTPError`, so a bare `FailsafeError` escaping a transport would slip past every such block in existing code.


### NEW · `## Request Bodies and Streaming` · 0w → 80w

VERDICT: ?

py:

> A streaming request body is buffered once so a retry can resend it. Without that, a retry silently sends an empty body — a correctness issue, not an optimisation. A body httpx already holds in memory is left alone. Responses are returned with their stream intact, so `client.stream(...)` works through the transport: {: .callout } > Policies judge the **response headers**, which arrive before the body is read. A stream that fails midway has already been recorded as a success.


### NEW · `## Cancellation and Timeouts` · 0w → 55w

VERDICT: ?

py:

> In async mode, cancelling the task cancels the in-flight request: asyncio cancellation reaches httpx for free. A [`Timeout`][timeouts] composed around the transport therefore interrupts the request itself. In sync mode there is no cancellation, only deadlines. Pass the remaining budget to httpx: Both transports accept `clock=`, so a `Retry-After` test need not sleep for real:


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Servers`
- `## Propagating Priorities`
- `## Context Cancellation`


## `type-safety.md`

go 108w → py 261w (+153)


### NEW · `## Result Types Are Inferred per Call` · 0w → 91w

VERDICT: ?

py:

> Policies are not generic; `Failsafe.call` is. The result type comes from the function you execute, not from the policy you built: Both calls go through the same composition, and each is typed by the function passed to it. Nothing needs a type argument, and nothing has to agree with anything else. This is deliberate. A `Generic[R]` executor defaulting to `Any` needs [PEP 696] type parameter defaults, which land in Python 3.13; on the 3.11 floor `Failsafe(retry)` would infer `Never` and every example on this site would read `Failsafe[Response](retry)`. [PEP 696]: https://peps.python.org/pep-0696/


### NEW · `## Decorated Functions Keep Their Signature` · 0w → 12w

VERDICT: ?

py:

> The decorator is typed with [`ParamSpec`][paramspec], so arguments and return type survive:


### NEW · `## Typing Conditions and Listeners` · 0w → 84w

VERDICT: ?

py:

> `handle` and `abort` accept the same [`Condition`][failure-handling] type everywhere — an exception type, a tuple of them, a `Result(value)`, a predicate, or a sequence of those: Predicates and listeners are typed against the event, not against a policy type parameter: Because the result is not carried in the policy's type, `e.result` is `Any`. A narrow consumer should say what it expects: That cast is the cost of inferring `R` per call rather than fixing it at construction, and it is paid only inside listeners.


### NEW · `## Checking Your Own Code` · 0w → 45w

VERDICT: ?

py:

> Nothing special is required — the package is typed, so `mypy` and pyright resolve it from the installed wheel: If a type checker reports `Skipping analyzing "failsafe"`, the installed distribution is not failsafe-py. The package name on PyPI is `failsafe-py`; the import name is `failsafe`.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Mixing Result Types`


## `execution-budgets.md`

go 216w → py 336w (+120)


### GROWN · `# Execution Budgets` · 37w → 70w

VERDICT: ?

<details><summary>go</summary>

> [Budgets][Budget] limit the total number of concurrent retries or hedges across a system to prevent them from causing overload. This can happen when a flood of retries or hedges come in and need to be handled gradually.

</details>

py:

> Budgets cap the share of in-flight work that retries and hedges may consume, preventing them from causing the overload they were meant to paper over. A retry storm is self-inflicted load: the attempts meant to cover a few failures become most of the traffic to an already struggling service. One budget shared between policies bounds that, letting extra attempts through only while they stay a small fraction of normal traffic.


### GROWN · `## How It Works` · 34w → 72w

VERDICT: ?

<details><summary>go</summary>

> Budgets permit executions to proceed up to some max number of concurrent retries or hedges, after which executions will fail with `budget.ErrExceeded`. This allows a system-wide cap to be placed on retries or hedges.

</details>

py:

> Budgets permit extra attempts up to a share of the executions in flight. Beyond that: - a [`RetryPolicy`][retry] stops retrying and fails with `BudgetExceeded` - a [`HedgePolicy`][hedge] simply stops hedging, leaving the attempts already running to produce a result The rate is measured against executions **in flight right now**, not over a time window. That needs no clock and reacts immediately, where a windowed rate lags exactly when a storm is building.


### GROWN · `### Min Concurrency` · 16w → 43w

VERDICT: ?

<details><summary>go</summary>

> You can also specify the min number of concurrent executions that can be retries or hedges:

</details>

py:

> Extra attempts always allowed regardless of the rate, so a quiet service still retries: Without this, a service with one request in flight could never retry it — one retry out of one execution is a rate of 1.0, over any sane threshold.


### GROWN · `## Best Practices` · 21w → 37w

VERDICT: ?

<details><summary>go</summary>

> A [Budget] should be shared across a system to make sure that all retries or hedges are counted towards the budget.

</details>

py:

> **Share one instance across the policies guarding the same dependency.** A budget per policy bounds nothing, since the dependency sees their sum. This is the same hoisting rule as every other stateful policy — see [policy sharing][policy-sharing].


### NEW · `## Standalone Usage` · 0w → 0w

VERDICT: ?

py:

> 


## `event-listeners.md`

go 190w → py 306w (+116)


### NEW · `## There Is No Executor-Level Listener` · 0w → 85w

VERDICT: ?

py:

> `Failsafe` and `AsyncFailsafe` take only policies and a clock. Listeners belong to policies, because a policy is what decides whether an outcome was a success or a failure. To observe the final result of a composition, use the outermost policy's listeners — they see exactly what that policy decided: For something that must run on every call regardless of composition, wrap the call site — a decorator or a `try`/`finally` is clearer than a hook whose firing conditions depend on what the innermost policy did.


### NEW · `## Events` · 0w → 81w

VERDICT: ?

py:

> | Event | Fields | |---|---| | `ExecutionEvent` | `execution`, `result`, `exception`, plus `attempts`, `retries`, `elapsed` | | `ScheduledRetryEvent` | the above, plus `delay` — the delay about to elapse | | `ExecutionCompletedEvent` | `execution`, `result`, `exception` | | `StateChangedEvent` | `previous_state`, `state` | | `LimitChangedEvent` | `old_limit`, `new_limit` | | `ThresholdChangedEvent` | `old_threshold`, `new_threshold` | All are frozen dataclasses. `e.result` is typed `Any`, because the result type is inferred per call rather than fixed on the policy; see [type safety][type-safety].


### NEW · `## Listeners Are Sync` · 0w → 37w

VERDICT: ?

py:

> Listeners are plain functions, not coroutines. A coroutine listener cannot be awaited from sync code, so neither driver accepts one. Listeners are for logging and metrics. If one genuinely needs to do I/O, hand the work off:


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Executor Listeners`


## `cache.md`

go 118w → py 221w (+103)


### GROWN · `## Usage` · 10w → 28w

VERDICT: ?

<details><summary>go</summary>

> Creating and using a [CachePolicy] for a [cache] is simple:

</details>

py:

> Composed outermost, a hit skips every policy inside it, which is usually what you want: a cached result needs no retry, no circuit breaker and no rate limiter.


### NEW · `## Cache Keys Come from the Arguments` · 0w → 66w

VERDICT: ?

py:

> The `key` callable receives the call's arguments and returns the key, shaped like [`functools.lru_cache`][lru-cache]: The key is a function of the arguments in nearly every case, and a callable says so directly. ([Priority][execution-prioritization] is ambient instead, because it genuinely is request-scoped data propagated across hops.) Returning `None` skips the cache for that call, which is how you exclude requests that should never be served from cache:


### NEW · `## The Cache Backend` · 0w → 78w

VERDICT: ?

py:

> A backend needs two methods: The protocol is structural, so a `dict` subclass, an LRU, or a Redis wrapper all satisfy it without importing anything from this library: `get` returns a presence flag rather than a sentinel, so a cached `None` is a hit rather than a miss. Backends own their eviction, expiry and thread safety. The library deliberately ships no cache implementation: `cachetools`, `redis` and a plain dict already exist, and expiry policy is an application decision.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Cache Keys`


## `bulkhead.md`

go 271w → py 359w (+88)


### GROWN · `## How It Works` · 33w → 63w

VERDICT: ?

<details><summary>go</summary>

> Executions are permitted in a bulkhead until it is full, meaning the max number of concurrent executions has been reached. Any further executions will either fail with `bulkhead.ErrFull` or will wait until permitted.

</details>

py:

> Executions are permitted until the bulkhead is full, meaning the max number of concurrent executions has been reached. Further executions either fail with `BulkheadFull` or wait until permitted. A permit is held for a single **attempt** and released when that attempt finishes, so a [`RetryPolicy`][retry] composed outside a bulkhead re-acquires for each retry rather than holding a permit across the delay between them.


### NEW · `### Metrics` · 0w → 28w

VERDICT: ?

py:

> | | | |---|---| | `bulkhead.max_concurrency` | the configured limit | | `bulkhead.used` | permits currently held | | `bulkhead.waiters` | callers blocked waiting for a permit |


### GROWN · `## Standalone Usage` · 29w → 49w

VERDICT: ?

<details><summary>go</summary>

> A [Bulkhead] can also be manually operated in a standalone way: Standalone permit methods do not call `OnFull`, `OnAcquired`, or `OnReleased`. These listeners only apply to executions through Failsafe.

</details>

py:

> A `Bulkhead` can also be manually operated: Blocking acquisition has a sync and an async method, both drawing on the same permit count: There is no `with` form; wrap it yourself if you want one: Standalone permit methods do not call `on_full`. That listener applies to executions through Failsafe.


## `index.md`

go 181w → py 254w (+73)


### GROWN · `# Overview` · 55w → 87w

VERDICT: ?

<details><summary>go</summary>

> Failsafe-go is a library for building resilient, fault tolerant Go applications. It works by wrapping functions with one or more resilience [policies], which can be combined and [composed][policy-composition] as needed. Policies include: - Failure handling: [Retry][retry], [Fallback][fallbacks] - Load limiting: [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Bulkhead][bulkheads], [Rate Limiter][rate-limiters], [Cache][caches] - Time limiting: [Timeout][timeouts], [Hedge][hedge]

</details>

py:

> failsafe-py is a library for building resilient, fault tolerant Python applications. It works by wrapping functions with one or more resilience [policies], which can be combined and [composed][policy-composition] as needed. Policies include: - Failure handling: [Retry][retry], [Fallback][fallbacks] - Load limiting: [Circuit Breaker][circuit-breakers], [Adaptive Limiter][adaptive-limiters], [Adaptive Throttler][adaptive-throttlers], [Bulkhead][bulkheads], [Rate Limiter][rate-limiters], [Cache][caches] - Time limiting: [Timeout][timeouts], [Hedge][hedge] Every policy works the same from sync and async code, and **one policy instance can be shared between both**: a circuit breaker tripped by a thread is seen open by a coroutine.


### NEW · `## Installation` · 0w → 0w

VERDICT: ?

py:

> 


### NEW · `### Reusing a Composition` · 0w → 50w

VERDICT: ?

py:

> A `Failsafe` *is* the reusable composition — build it once and call it many times: This is not just a convenience. Stateful policies model the health of a *backend*, so writing `@Failsafe(RetryPolicy(), CircuitBreaker())` on twenty functions builds twenty independent breakers, each seeing a twentieth of the traffic. See [policy sharing][policy-sharing].


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Executor`


## `retry.md`

go 318w → py 380w (+62)


### NEW · `### Max Retries` · 0w → 37w

VERDICT: ?

py:

> By default a `RetryPolicy` allows 2 retries, for a maximum of 3 attempts: Retries are counted, not attempts: `max_retries=2` permits three calls. To retry without a count limit — bounded only by `max_duration` or an outer [timeout][timeouts]:


### GROWN · `### Jitter` · 28w → 57w

VERDICT: ?

<details><summary>go</summary>

> You can also combine a delay with a random [jitter factor][WithJitterFactor]: Or a [time based jitter][WithJitter]: To cancel running executions, see the [execution cancellation][execution-cancellation] docs or [Timeout][timeouts] policy.

</details>

py:

> Jitter is an attribute of the delay rather than a separate parameter, because jitter without a delay does nothing: `Jitter(factor=...)` and `Jitter(seconds=...)` are spelled out because a bare float is ambiguous: `jitter=0.5` could mean half a second or ±50%. A plain `delay=1.0` carries no jitter and has nothing to leave half-configured. For deterministic tests, inject the randomness:


### NEW · `### Aborts` · 0w → 37w

VERDICT: ?

py:

> You can specify which results, exceptions, or conditions should [abort][failure-handling] retries, failing immediately with that outcome rather than `RetriesExceeded`: `abort` is only consulted for outcomes that `handle` already considers failures, and it takes the same `Condition` type.


### NEW · `### Raised Exception` · 0w → 53w

VERDICT: ?

py:

> By default, when an execution fails and the retries are exhausted, `RetriesExceeded` is raised, carrying the last result and exception, and chaining the original as `__cause__`: A `RetryPolicy` can instead return or raise the last failure itself: If additional handling or an alternative result is needed, compose a [fallback][fallbacks] around the retry policy.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Max Attempts`
- `### Abort`
- `### Return Value`


## `adaptive-throttler.md`

go 383w → py 416w (+33)


### GROWN · `### Event Listeners` · 7w → 31w

VERDICT: ?

<details><summary>go</summary>

> Adaptive throttlers support the standard [policy listeners][policy-listeners].

</details>

py:

> Adaptive throttlers support the standard [policy listeners][policy-listeners]: These do **not** fire for a throttled rejection: a rejection is not an execution result, and it is not recorded in the window either.


### GROWN · `### Metrics` · 9w → 40w

VERDICT: ?

<details><summary>go</summary>

> [AdaptiveThrottler] provides [metrics][AdaptiveThrottlerMetrics] that include the current rejection rate.

</details>

py:

> | | | |---|---| | `throttler.rejection_rate` | share currently being rejected, 0 to 1 | | `throttler.executions` | recorded within the thresholding period | | `throttler.successes` | successes in that period | | `throttler.failures` | failures in that period |


### NEW · `### Deterministic Tests` · 0w → 10w

VERDICT: ?

py:

> Rejection is a random draw, so the source is injectable:


### GROWN · `## Standalone Usage` · 11w → 28w

VERDICT: ?

<details><summary>go</summary>

> An [AdaptiveThrottler] can also be manually operated in a standalone way:

</details>

py:

> `record_result(outcome)` records an `Outcome` judged by the throttler's own `handle` condition, which is what the executor uses. A raising variant is available for both sync and async callers:


## `fallback.md`

go 122w → py 145w (+23)


### GROWN · `## Usage` · 31w → 53w

VERDICT: ?

<details><summary>go</summary>

> There are a few different options for creating a [Fallback]. You can provide an alternative result: An alternative error: Or compute a different result or error: Using a [Fallback] is simple:

</details>

py:

> A `Fallback` takes either an alternative result: Or a function that computes one from the [execution][execution-info]: The function receives the `Execution`, whose `last_result` and `last_exception` describe the failure being handled: An exception raised by that function replaces the original, which is how you substitute one exception for another: Using a `Fallback` is simple:


## `rate-limiter.md`

go 419w → py 440w (+21)


### GROWN · `## How It Works` · 28w → 49w

VERDICT: ?

<details><summary>go</summary>

> When the number of executions through the rate limiter exceeds the configured max per time period, further executions will either fail with `ratelimiter.ErrExceeded` or will wait until permitted.

</details>

py:

> When executions exceed the configured max per period, further executions either fail with `RateLimitExceeded` or wait until permitted. Both reserve permits by arithmetic: a reservation returns the time the caller must wait, so a reserved permit is never lost and the same instance can serve sync and async callers.


### GROWN · `## Standalone Usage` · 28w → 60w

VERDICT: ?

<details><summary>go</summary>

> A [RateLimiter] can also be manually operated in a standalone way: You can also integrate a standalone rate limiter with an external scheduler to wait for a permit:

</details>

py:

> Blocking acquisition has a sync and an async method, both against the same limiter: You can also integrate with an external scheduler by reserving a permit and getting back the wait: Multiple permits can be acquired at once, for a caller whose work costs more than one unit: `limiter.reset()` discards all reservations, as if the limiter had just been built.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Performance`


## `load-limiting.md`

go 603w → py 603w (+0)


### NEW · `### Adaptive Limiters vs Circuit Breakers` · 0w → 46w

VERDICT: ?

py:

> Both react to overload, but a [circuit breaker][circuit-breakers] needs *failures* — timeouts, errors — to drive it, while an [adaptive limiter][adaptive-limiters] detects unusual latency before large numbers of timeouts occur. A breaker also rejects everything for a period; a limiter maintains a working concurrency limit throughout.


### NEW · `### Adaptive Throttlers vs Circuit Breakers` · 0w → 39w

VERDICT: ?

py:

> Both limit on recent failures. A [circuit breaker][circuit-breakers] is open or closed for everyone; an [adaptive throttler][adaptive-throttlers] rejects *probabilistically*, in proportion to the failure rate. Execution flows stay smoother, and recovery is detected sooner because probe traffic never stops.


### GROWN · `## Preferences` · 26w → 54w

VERDICT: ?

<details><summary>go</summary>

> For guarding against system overload, prefer *reactive* limiters, and in particular, prefer adaptive limiters over circuit breakers since they respond more quickly to indications of overload.

</details>

py:

> For guarding against system overload, prefer reactive limiters, and in particular prefer adaptive limiters over circuit breakers, since they respond more quickly to indications of overload. When load must be shed, shed it selectively rather than at random: see [execution prioritization][execution-prioritization], which rejects low-priority executions — and the heaviest users — before high-priority ones.


## `circuit-breaker.md`

go 674w → py 587w (-87)


### GROWN · `### Half-Opening` · 53w → 80w

VERDICT: ?

<details><summary>go</summary>

> After opening, a breaker will delay for 1 minute by default before before transitioning to *half-open*. You can configure a different delay: Or a [computed delay][WithDelayFunc] based on an execution result. When in an *open* state, you can also get the [remaining delay][RemainingDelay], so that callers know how long to wait before retrying:

</details>

py:

> After opening, a breaker delays for 1 minute by default before transitioning to half-open. You can configure a different delay, using the same forms a [retry delay][retry] accepts: {: .callout } > A callable `delay=` yields no delay for a manual `breaker.open()`, which has no execution to compute one from. Pass a fixed delay if manual transitions need to stay open for a set time. While open, you can read the remaining delay, so callers know how long to wait:


### GROWN · `## Standalone Usage` · 11w → 24w

VERDICT: ?

<details><summary>go</summary>

> A [CircuitBreaker] can also be manually operated in a standalone way:

</details>

py:

> A `CircuitBreaker` can also be manually operated: `record(outcome)` records an `Outcome` judged by the breaker's own `handle` condition, which is what the executor uses.


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `## Additional Details`
- `### Time Based Resolution`
- `### Performance`


## `adaptive-limiter.md`

go 1222w → py 990w (-232)


### NEW · `### Metrics` · 0w → 48w

VERDICT: ?

py:

> | | | |---|---| | `limiter.limit` | the current concurrency limit | | `limiter.inflight` | executions running right now | | `limiter.queued` | executions waiting for a permit | | `limiter.max_inflight` | peak inflight during the last sampling window | | `limiter.queueing` | whether queueing is enabled |


### DROPPED · sections in the Go page with no py counterpart

VERDICT: ?

- `### Logging and Metrics`
- `## Additional Details`
- `## Thanks`
