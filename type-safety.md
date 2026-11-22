---
layout: default
title: Type Safety
---

# Type Safety
{: .no_toc }

1. TOC
{:toc}

failsafe-py ships [`py.typed`][py-typed] and is clean under `mypy --strict`. Python's type system only reaches so far into a library like this one, so this page is about what a type checker will catch for you, and what it will not.

## What Is Checked

The result type and the arguments both come from the function you execute:

```python
failsafe = Failsafe(retry, breaker)

response = failsafe.call(send_request, url)   # Response
rows = failsafe.call(count_rows, table)       # int

failsafe.call(send_request, 123)              # error: incompatible argument type
failsafe.call(send_request)                   # error: missing argument
```

One composition can guard calls returning different types, with no annotations and no type arguments. `call` is typed with a [`ParamSpec`][paramspec], which is what keeps the argument check.

The decorator preserves the signature for the same reason:

```python
@failsafe
def charge(account: str, amount: Decimal) -> Receipt: ...

charge("acct-1", Decimal("10"))   # Receipt
charge("acct-1", 10)              # error: incompatible argument type
```

## What Is Not

Policies are not parameterised by result type, so nothing ties a policy to the calls it guards. A type checker cannot catch these:

```python
# a fallback value unrelated to the result type
Failsafe(Fallback(value="n/a")).call(count_rows, table)   # inferred int, returns a str

# a condition that will never match
RetryPolicy(handle=12345)
```

[Conditions][failure-handling] are typed `Any` on purpose. Bare values are accepted, so the set of legal arguments is open-ended, and a union spelling it out would reject valid code while promising a precision it cannot deliver. Genuinely ambiguous shapes raise `TypeError` at construction instead — a runtime check where a static one is not available.

Event listeners are typed against the event rather than the result, so `e.result` is `Any`:

```python
def on_failure(e: ExecutionEvent) -> None:
    logger.error("attempt %d failed: %s", e.attempts, e.exception)
```

A listener that needs the concrete type has to say so:

```python
def log_status(e: ExecutionEvent) -> None:
    response = cast(Response, e.result)
    logger.error("failed attempt", extra={"status": response.status_code})
```

{% include common-links.html %}
