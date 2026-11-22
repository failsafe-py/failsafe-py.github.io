---
layout: default
title: HTTP Support
---

# HTTP Support
{: .no_toc }

1. TOC
{:toc}

failsafe-py makes it easy to use any policies with [httpx].

```bash
pip install 'failsafe-py[httpx]'
```

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

<!-- TODO(ndumazet): inspect — confirm the retryable set. -->

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

A failing response is still a response. When the retries are exhausted, `retry_policy()` returns the last response instead of raising [`RetriesExceeded`][retry], so the caller can inspect the status and body:

```python
response = client.get(url)   # a 500 after 3 attempts, not an exception
```

This is `return_last_failure=True`, which `retry_policy()` sets by default. Pass `return_last_failure=False` to raise instead.

## Handling Retry-After

Other policies that support delays, such as [circuit breakers][circuit-breakers], can also be configured with `retry_after_delay`, which delays according to a `Retry-After` header:

```python
from failsafe import CircuitBreaker, Result
from failsafe.httpx import retry_after_delay

breaker = CircuitBreaker(handle=Result(429), delay=retry_after_delay)
```

{% include common-links.html %}
