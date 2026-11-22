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

The async client takes `AsyncFailsafeTransport`:

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
| Any `httpx.TransportError`: connection failures, timeouts, read errors | A 4xx the server answered deliberately |
| [429][429], and 5xx other than [501][501] | Unsupported scheme, invalid URL, too many redirects |

### Return Value

A failing response is still a response. When the retries are exhausted, `retry_policy()` returns the last response instead of raising [`RetriesExceeded`][retry], so the caller can inspect the status and body:

```python
response = client.get(url)   # a 500 after 3 attempts, not an exception
```

This is [`return_last_failure=True`][retry-return-value], which `retry_policy()` sets by default. Pass `return_last_failure=False` to raise instead.

## Timeouts

A [`Timeout`][timeouts] composed into the transport bounds the round trip, in sync as well as async. The transport narrows each phase of httpx's own timeout to the execution's remaining budget, so httpx enforces the deadline rather than merely reporting it afterwards:

```python
client = httpx.Client(transport=FailsafeTransport(Timeout(2.0)))
client.get(url)   # fails in ~2s even against a server that never replies
```

A stricter timeout you configured yourself is kept — each phase is the lower of the two.

This is the exception to the [sync caveat][timeouts]: the transport cooperates on your behalf, so no `remaining()` plumbing is needed for HTTP.

## Handling Retry-After

Other policies that support delays, such as [circuit breakers][circuit-breakers], can also be configured with `retry_after_delay`, which delays according to a `Retry-After` header:

```python
from failsafe import CircuitBreaker
from failsafe.httpx import retry_after_delay

breaker = CircuitBreaker(handle=lambda r, e: r is not None and r.status_code == 429, delay=retry_after_delay)
```

Only [429][429] and [503][503] responses are consulted.

{% include common-links.html %}

[429]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/429
[501]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/501
[503]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/503
