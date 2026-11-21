---
layout: default
title: Load Limiting
---

# Load Limiting
{: .no_toc }

1. TOC
{:toc}

Systems become overloaded when usage exceeds the capacity of resources such as CPU, memory, disk and network IO, thread pools, and so on. failsafe-py offers several policies that can prevent and sometimes detect system overload, including [Adaptive Limiters][adaptive-limiters], [Adaptive Throttlers][adaptive-throttlers], [Circuit Breakers][circuit-breakers], [Bulkheads][bulkheads], [Rate Limiters][rate-limiters], [Timeouts][timeouts], and [Caches][caches]. We'll discuss below how these policies differ, and when you might choose one over another.

## Types of Load Limiting

There are two general approaches: *proactive*, where we estimate when a system might be overloaded and limit it in advance, and *reactive*, where we react to a signal that the system actually is overloaded.

### Proactive Load Limiting

[Bulkheads][bulkheads], [Rate Limiters][rate-limiters], and [Timeouts][timeouts] are *proactive* limiters. They must be statically configured to limit load at some point. Ideally that configuration is chosen through load testing, to start limiting before the system is overloaded but not so early that its resources are underutilized. While it is better to limit sooner than later, choosing configuration that actually matches a workload and a system's capacity is hard, especially as both change over time.

### Reactive Load Limiting

*Reactive* limiters wait for a signal that a system is becoming overloaded before they limit. The benefit is that they work with any sized system, without carefully chosen configuration.

[Adaptive limiters][adaptive-limiters] are reactive: they detect overload through changes in latency and throughput. [Adaptive throttlers][adaptive-throttlers] and time based [circuit breakers][circuit-breakers] are also reactive, limiting only when the recent failure rate exceeds a threshold — 10% in the last minute, for example.

## Best Practices

For overload prevention, prefer a *reactive* limiter. [Adaptive Limiters][adaptive-limiters] are first among those, followed by [Adaptive Throttlers][adaptive-throttlers] and time based [Circuit Breakers][circuit-breakers]. For other use cases, such as maintaining per-user quotas, [Rate Limiters][rate-limiters] or [Bulkheads][bulkheads] are useful.

All load limiters can be used on the *client* side or the *server* side. If your client talks to only a few servers, a limiter per server on the client side may make sense. If you have many servers, placing the limiter on the server avoids every client needing one per server.

{: .callout }
> Server-side helpers are not yet ported from failsafe-go. Today's limiters are client-side; the policies themselves are agnostic, but there is no ASGI middleware yet. See [porting][not-ported].

## Policy Comparisons

### Rate Limiters vs Bulkheads

[Rate limiters][rate-limiters] and [bulkheads][bulkheads] are both proactive and both configured from a system's capacity, but bulkheads handle varied workloads better. [Little's Law][littles-law] explains why: average concurrency inside a system relates to the average request rate and the average response time.

For example: 100 reqs/sec × 1 sec/req is an average concurrency of 100. Limit the request rate to 100 and the load on the system is 100 — *as long as* requests take 1 second. If more expensive requests arrive that take 2 seconds, concurrency inside the system rises to 200.

Bulkheads avoid this because they limit concurrency, and therefore load, directly. When the request rate or response times change, the concurrency limit is unchanged. Of course, bulkheads still require static configuration. For something that adapts to changes in load or capacity, consider an [adaptive limiter][adaptive-limiters].

### Adaptive Limiters vs Circuit Breakers

Both react to overload, but a [circuit breaker][circuit-breakers] needs *failures* — timeouts, errors — to drive it, while an [adaptive limiter][adaptive-limiters] detects unusual latency before large numbers of timeouts occur. A breaker also rejects everything for a period; a limiter maintains a working concurrency limit throughout.

### Adaptive Throttlers vs Circuit Breakers

Both limit on recent failures. A [circuit breaker][circuit-breakers] is open or closed for everyone; an [adaptive throttler][adaptive-throttlers] rejects *probabilistically*, in proportion to the failure rate. Execution flows stay smoother, and recovery is detected sooner because probe traffic never stops.

## Preferences

For guarding against system overload, prefer reactive limiters, and in particular prefer adaptive limiters over circuit breakers, since they respond more quickly to indications of overload.

When load must be shed, shed it selectively rather than at random: see [execution prioritization][execution-prioritization], which rejects low-priority executions — and the heaviest users — before high-priority ones.

{% include common-links.html %}
