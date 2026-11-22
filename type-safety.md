---
layout: default
title: Type Safety
---

# Type Safety
{: .no_toc }

1. TOC
{:toc}

failsafe-py ships [`py.typed`][py-typed] and is checked with `mypy --strict` and pyright. Types are inferred from the function you execute, so correctly typed code needs no annotations of its own.

## Result Types Are Inferred per Call

<!-- TODO(ndumazet): inspect — per-call R inference vs Generic[R]. -->

Policies are not generic; `Failsafe.call` is. The result type comes from the function you execute, not from the policy you built:

```python
retry = RetryPolicy(max_retries=3)
fs = Failsafe(retry)

response = fs.call(send_request, url)   # response: Response
count = fs.call(count_rows, table)      # count: int
```

Both calls go through the same composition, and each is typed by the function passed to it. Nothing needs a type argument, and nothing has to agree with anything else.

This is deliberate. A `Generic[R]` executor defaulting to `Any` needs [PEP 696] type parameter defaults, which land in Python 3.13; on the 3.11 floor `Failsafe(retry)` would infer `Never` and every example on this site would read `Failsafe[Response](retry)`.

[PEP 696]: https://peps.python.org/pep-0696/

## Decorated Functions Keep Their Signature

<!-- TODO(ndumazet): inspect — ParamSpec on the decorator. -->

The decorator is typed with [`ParamSpec`][paramspec], so arguments and return type survive:

```python
payments = Failsafe(retry, breaker)

@payments
def charge(account: str, amount: Decimal) -> Receipt: ...

charge("acct-1", Decimal("10"))   # Receipt
charge("acct-1", 10)              # error: Argument 2 has incompatible type "int"
```

## Typing Conditions and Listeners

<!-- TODO(ndumazet): inspect — Condition type and Any-typed event results. -->

`handle` and `abort` accept the same [conditions][failure-handling] everywhere — an exception type, a tuple of them, a bare value, a predicate, or a list mixing them:

`Condition` is typed `Any`, deliberately: bare values are accepted, so the set of legal arguments is almost anything, and a union spelling it out would reject valid code while promising a precision it cannot deliver. Genuinely ambiguous shapes raise `TypeError` at construction instead.

Predicates and listeners are typed against the event, not against a policy type parameter:

```python
def on_failure(e: ExecutionEvent) -> None:
    logger.error("attempt %d failed: %s", e.attempts, e.exception)

retry = RetryPolicy(on_failure=on_failure)
```

Because the result is not carried in the policy's type, `e.result` is `Any`. A narrow consumer should say what it expects:

```python
def log_status(e: ExecutionEvent) -> None:
    response = cast(Response, e.result)
    logger.error("failed attempt", extra={"status": response.status_code})
```

That cast is the cost of inferring `R` per call rather than fixing it at construction, and it is paid only inside listeners.

{% include common-links.html %}
