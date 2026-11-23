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

Creating and using a [`CachePolicy`][CachePolicy] for a cache is simple:

```python
from failsafe import CachePolicy, Failsafe

# Store users under a "user:<id>" key in the cache
cache = CachePolicy(backend, key=lambda req: f"user:{req.user_id}")

# Get a user from the cache, else fetch one
user = Failsafe(cache).call(fetch_user, request)
```

Composed outermost, a cache hit skips every policy inside it.

## Cache Keys

There are two ways to supply a key. The `key` callable receives the call's arguments, shaped like [`functools.lru_cache`][lru-cache]:

```python
CachePolicy(backend, key=lambda req: f"user:{req.user_id}")
CachePolicy(backend, key=lambda req: f"{req.method}:{req.url}")
```

Returning `None` skips the cache for that call, which is how you exclude requests that should never be served from cache:

```python
CachePolicy(backend, key=lambda req: None if req.no_cache else req.url)
```

A `cache_key` block supplies one ambiently, for a key that belongs to the request rather than to the arguments — a tenant, a revision, a trace:

```python
from failsafe import cache_key

with cache_key(f"{tenant}:config"):
    config = api.call(fetch_config)
```

A `cache_key` block **takes precedence** over the policy's `key=`. One of the two must supply a key; with neither, the execution runs uncached.

`current_cache_key()` returns the key in scope, or `None`.

[lru-cache]: https://docs.python.org/3/library/functools.html#functools.lru_cache

## The Cache Backend

A backend is any mutable mapping. A plain `dict`, `cachetools` cache, or custom mapping
works directly:

```python
backend = {}
cache = CachePolicy(backend, key=lambda req: f"user:{req.user_id}")
```

Values are read with `backend[key]` and stored with `backend[key] = value`; `KeyError`
means a miss. This follows Python's mapping protocol, preserves cached `None`, and avoids
an adapter around existing cache implementations.

Backends own their eviction, expiry and thread safety.

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
