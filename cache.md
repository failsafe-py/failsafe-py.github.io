---
layout: default
title: Cache
---

# Cache
{: .no_toc }

1. TOC
{:toc}

Cache policies limit unnecessary load by serving previous execution results, skipping the execution entirely on a hit.

## Usage

```python
from failsafe import CachePolicy, Failsafe

cache = CachePolicy(backend, key=lambda user_id: f"user:{user_id}")
users = Failsafe(cache)

user = users.call(fetch_user, 42)   # miss: calls fetch_user, stores the result
user = users.call(fetch_user, 42)   # hit: fetch_user is never called
```

Composed outermost, a hit skips every policy inside it, which is usually what you want: a cached result needs no retry, no circuit breaker and no rate limiter.

```python
Failsafe(cache, retry, breaker).call(fetch_user, 42)
```

## Cache Keys Come from the Arguments

The `key` callable receives the call's arguments and returns the key, shaped like [`functools.lru_cache`][lru-cache]:

```python
CachePolicy(backend, key=lambda user_id: f"user:{user_id}")
CachePolicy(backend, key=lambda method, url, **kw: f"{method}:{url}")
```

failsafe-go reads a cache key from the `Context`, because that is its only ambient channel. The key is a function of the arguments in nearly every case, and a callable says so without a parallel ambient mechanism. [Priority][execution-prioritization] remains a contextvar, because that genuinely is request-scoped ambient data propagated across hops.

Returning `None` skips the cache for that call, which is how you exclude requests that should never be served from cache:

```python
CachePolicy(backend, key=lambda req: None if req.no_cache else req.url)
```

[lru-cache]: https://docs.python.org/3/library/functools.html#functools.lru_cache

## The Cache Backend

A backend needs two methods:

```python
class Cache(Protocol):
    def get(self, key: str) -> tuple[Any, bool]: ...   # (value, was_present)
    def set(self, key: str, value: Any) -> None: ...
```

The protocol is structural, so a `dict` subclass, an LRU, or a Redis wrapper all satisfy it without importing anything from this library:

```python
class DictCache:
    def __init__(self): self._d = {}
    def get(self, key): return (self._d.get(key), key in self._d)
    def set(self, key, value): self._d[key] = value
```

`get` returns a presence flag rather than a sentinel, so a cached `None` is a hit rather than a miss.

Backends own their eviction, expiry and thread safety. The library deliberately ships no cache implementation: `cachetools`, `redis` and a plain dict already exist, and expiry policy is an application decision.

## Configuration

### Conditional Caching

By default any execution that did not raise is cached, since caching a failure serves it to every later caller. `cache_if` narrows that further, taking the same [`Condition`][failure-handling] type as everywhere else:

```python
CachePolicy(backend, key=by_url, cache_if=lambda response, exc: response.status_code == 200)
```

### Event Listeners

```python
CachePolicy(
    backend,
    key=by_url,
    on_hit=lambda e: metrics.incr("cache.hit"),
    on_miss=lambda e: metrics.incr("cache.miss"),
    on_cached=lambda e: logger.debug("cached %r", e.result),
)
```

{% include common-links.html %}
