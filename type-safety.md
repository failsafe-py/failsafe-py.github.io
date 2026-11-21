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

Go parameterises the policy: `retrypolicy.NewBuilder[*http.Response]()` fixes the result type at construction, and every policy in a composition must agree on it.

failsafe-py parameterises the *call* instead. Policies are not generic; `Failsafe.call` is:

```python
retry = RetryPolicy(max_retries=3)
fs = Failsafe(retry)

response = fs.call(send_request, url)   # response: Response
count = fs.call(count_rows, table)      # count: int
```

Both calls go through the same composition, and each is typed by the function passed to it. Nothing needs a type argument, and nothing has to agree with anything else.

This is a deliberate choice, not an accident of erasure. A `Generic[R]` executor defaulting to `Any` needs [PEP 696] type parameter defaults, which land in Python 3.13; on the 3.11 floor `Failsafe(retry)` would infer `Never` and every example on this site would read `Failsafe[Response](retry)`.

[PEP 696]: https://peps.python.org/pep-0696/

## Decorated Functions Keep Their Signature

The decorator is typed with [`ParamSpec`][paramspec], so arguments and return type survive:

```python
payments = Failsafe(retry, breaker)

@payments
def charge(account: str, amount: Decimal) -> Receipt: ...

charge("acct-1", Decimal("10"))   # Receipt
charge("acct-1", 10)              # error: Argument 2 has incompatible type "int"
```

## What Go Needs and Python Does Not

Go's type parameters force a split that disappears here. All of this is gone, with nothing replacing it:

| failsafe-go | failsafe-py |
|---|---|
| `Policy[R]` vs `ResultAgnosticPolicy[any]` | one `Policy` protocol |
| `ComposeAny`, `WithAny` | `compose`, and plain construction |
| `ToExecutor(typeToken)` | not needed |
| `circuitbreaker.NewWithDefaults[any]()` composed into a typed executor | `CircuitBreaker()` composes with anything |

A breaker shared across call sites that return different types is just a breaker:

```python
breaker = CircuitBreaker()                       # no result type

connection = Failsafe(breaker).call(connect)     # Connection
response = Failsafe(retry, breaker).call(send)   # Response
```

## Typing Conditions and Listeners

`handle` and `abort` accept the same [`Condition`][failure-handling] type everywhere — an exception type, a tuple of them, a `Result(value)`, a predicate, or a sequence of those:

```python
Condition = (
    type[Exception] | tuple[type[Exception], ...]
    | Result
    | Callable[[Any, Exception | None], bool]
    | Sequence[Condition]
)
```

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

That cast is the one place where Go's typed listeners buy something this design does not. It is the price of inferring `R` per call rather than fixing it at construction, and it is paid only inside listeners.

## Checking Your Own Code

Nothing special is required — the package is typed, so `mypy` and pyright resolve it from the installed wheel:

```bash
mypy --strict your_package
```

If a type checker reports `Skipping analyzing "failsafe"`, the installed distribution is not failsafe-py. The package name on PyPI is `failsafe-py`; the import name is `failsafe`.

{% include common-links.html %}
