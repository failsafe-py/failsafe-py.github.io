---
layout: default
title: HTTP Support
---

# HTTP Support
{: .no_toc }

1. TOC
{:toc}

failsafe-py integrates with [httpx] through a transport, so any [policy composition][policy-composition] applies to every request a client makes.

```bash
pip install 'failsafe-py[httpx]'
```

[httpx] is the only client supported. It has both sync and async transports — the same dual shape as the core — and a transport hook that sees every request a client makes. `requests` is sync-only with no cancellation story.

## Clients

Pass a `FailsafeTransport` to an `httpx.Client`:

```python
import httpx
from failsafe.httpx import FailsafeTransport, retry_policy

client = httpx.Client(transport=FailsafeTransport(retry_policy(max_retries=3), breaker))

client.get("https://example.com")
```

The async client takes `AsyncFailsafeTransport`, which shares policy state with its sync counterpart when built from the same policy objects — one circuit breaker can guard both:

```python
from failsafe.httpx import AsyncFailsafeTransport

async_client = httpx.AsyncClient(transport=AsyncFailsafeTransport(retry_policy(), breaker))
```

Either transport wraps `httpx.HTTPTransport` by default; pass `transport=` to wrap something else, such as a mock in tests.

## Retrying HTTP Failures

`retry_policy()` builds a [`RetryPolicy`][retry] that knows which HTTP failures are worth retrying and honours `Retry-After`:

```python
from failsafe import Backoff
from failsafe.httpx import retry_policy

retry = retry_policy(max_retries=3, delay=Backoff(1.0, 30.0))
```

It is an ordinary `RetryPolicy` with two defaults filled in, so every retry parameter is available and overridable.

### What Counts as Retryable

`is_retryable` is the default condition, and is usable on its own:

```python
from failsafe.httpx import is_retryable

breaker = CircuitBreaker(handle=is_retryable)
```

| Retryable | Not retryable |
|---|---|
| Any `httpx.TransportError`: connection failures, timeouts, read errors | 4xx the server answered deliberately, other than 408 and 429 |
| Status 408, 429, and 5xx other than 501 | Unsupported scheme, invalid URL, too many redirects |

{: .callout }
> **408 is treated as retryable.** It is the server saying it gave up waiting for the request, which is exactly the transient condition a retry addresses.

### Return Value

`retry_policy()` defaults `return_last_failure=True`: exhausting the retries on a failing *response* yields that response rather than raising `RetriesExceeded`. A 500 is still an answer the caller may want to inspect.

## Handling Retry-After

`retry_after_delay` delays according to a response's `Retry-After` header, and works anywhere a callable delay is accepted:

```python
from failsafe import CircuitBreaker, Result
from failsafe.httpx import retry_after_delay

breaker = CircuitBreaker(handle=Result(429), delay=retry_after_delay)
```

Both header forms RFC 9110 allows are honoured: delay-seconds, and an HTTP-date converted to a delay from now. Only 429 and 503 responses are consulted.

A missing, past, or malformed header yields `0.0`, so the request is retried without an extra wait.

## Error Handling

A policy rejection that never reached the network — an open breaker, a full bulkhead — surfaces as `httpx.TransportError`, with the original chained as `__cause__`:

```python
try:
    client.get(url)
except httpx.HTTPError as e:
    original = e.__cause__      # CircuitBreakerOpen, BulkheadFull, ...
```

httpx callers catch `httpx.HTTPError`, so a bare `FailsafeError` escaping a transport would slip past every such block in existing code.

## Request Bodies and Streaming

A streaming request body is buffered once so a retry can resend it. Without that, a retry silently sends an empty body — a correctness issue, not an optimisation. A body httpx already holds in memory is left alone.

Responses are returned with their stream intact, so `client.stream(...)` works through the transport:

```python
with client.stream("GET", url) as response:
    for chunk in response.iter_bytes():
        ...
```

{: .callout }
> Policies judge the **response headers**, which arrive before the body is read. A stream that fails midway has already been recorded as a success.

## Cancellation and Timeouts

In async mode, cancelling the task cancels the in-flight request: asyncio cancellation reaches httpx for free. A [`Timeout`][timeouts] composed around the transport therefore interrupts the request itself.

In sync mode there is no cancellation, only deadlines. Pass the remaining budget to httpx:

```python
from failsafe import current_execution

def get(url):
    return client.get(url, timeout=current_execution().remaining())
```

Both transports accept `clock=`, so a `Retry-After` test need not sleep for real:

```python
FailsafeTransport(retry_policy(), clock=fake_clock)
```

{% include common-links.html %}
