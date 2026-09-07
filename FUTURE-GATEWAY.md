# Planned Sage gateway architecture

This document records the intended direction for integrating this SageCell
worker with the next-generation Ximera server.

It is deliberately a design handoff rather than a finished gateway
specification. The current repository still provides a standalone SageCell
computation worker. The gateway described here is expected to be implemented
as a later, optional deployment layer once the new Ximera server begins its
Sage integration work.

## Current role of this repository

The SageCell container in this repository is intentionally narrow:

- execute Sage/Python code through the SageCell `/service` API;
- provide a reproducible, compatibility-controlled Sage environment;
- expose health and support-trace behavior needed by Ximera/Xronos;
- remain independent of the Ximera application implementation.

The SageCell worker should not become responsible for deciding whether a
browser, student, course page, or application server is authorized to execute
a particular Sage program.

For the initial standalone deployment, SageCell is bound only to
`127.0.0.1:8888` so it is not remotely reachable.

## Why a separate gateway is planned

The current Xronos server contains a prototype Sage proxy layer that performs
several responsibilities outside SageCell itself, including request routing,
exact-code response caching, in-flight request coalescing, reliability/fallback
handling, and support diagnostics.

The next-generation Ximera server is expected to be substantially rewritten
and should not be required to carry that prototype implementation internally.
Instead, those responsibilities should move to a separate Sage-facing service
that can evolve independently of the Ximera application server.

The intended long-term boundary is therefore approximately:

```text
Ximera server or authorized client
             |
             | authenticated / authorized Sage request
             v
      Sage gateway / cache
             |
             | validated internal request
             v
        SageCell worker
```

The gateway is expected to become the externally consumed Sage API. Raw
SageCell should remain an internal computation service behind that gateway.

## Likely deployment shape

A natural deployment is to run the gateway and SageCell as separate containers
on the same host and attach both to a named Podman network, for example:

```text
Podman network: sagecell-net

    sage-gateway
         |
         | http://sagecell:8888/service
         v
      sagecell
```

In that arrangement SageCell would not need a host-visible port at all. Only
the gateway would expose whatever network endpoint the Ximera deployment
requires.

The exact container names, ports, implementation language, and process
supervision mechanism are not yet fixed by this document.

A later deployment may also place the gateway and SageCell on different hosts
or scale SageCell to multiple workers. The API boundary should therefore avoid
assuming that same-host Podman networking is a permanent requirement.

## Responsibilities expected to move into the gateway

The future gateway is expected to be the natural home for capabilities such as:

- authentication of calling Ximera servers or other trusted clients;
- authorization of Sage execution requests;
- exact-request or exact-code response caching;
- in-flight request deduplication/coalescing;
- request-size and rate controls above SageCell's own safety limits;
- health-aware worker routing;
- retry/fallback policy when multiple Sage workers exist;
- privacy-safe request correlation and diagnostics;
- cache observability and support tracing.

The existing Xronos Sage proxy/cache behavior is a useful prototype for several
of these responsibilities, but it should not be treated as the final gateway
API or implementation.

## Browser-originated requests

A possible future Ximera architecture may allow a student's browser to initiate
a Sage request more directly than the current Xronos deployment does.

That must not mean exposing unrestricted SageCell execution to arbitrary
browser traffic.

A future browser-capable flow should still establish that the requested Sage
program is genuinely authorized Ximera content before SageCell executes it.
Possible mechanisms to investigate later include:

- short-lived signed requests;
- exact Sage code hashes;
- build-time or publication-time manifests of authorized Sage programs;
- tokens bound to a course/page/build/request identity;
- server-to-server credentials or mutual TLS where appropriate.

No particular mechanism is selected here. The important architectural
constraint is that authorization belongs at the gateway/trust boundary, not
inside the SageCell computation worker.

## Cache identity and compatibility

The current Xronos prototype uses exact Sage request identity for successful
response caching. A future gateway should preserve the important property that
responses are not reused across materially different Sage programs.

Before the gateway cache format is finalized, its cache identity should also
consider whether it needs to incorporate compatibility information such as the
Sage/SageCell environment version or image identity. This matters when a
worker compatibility baseline changes while cached results remain available.

The exact cache persistence, eviction, storage backend, and invalidation model
are intentionally left for the gateway design work.

## Near-term acceptance testing

The current AWS SageCell deployment does not need the future gateway in order
to prove that the architecture works in principle.

The near-term acceptance target is instead to verify the contract below the
future gateway:

```text
realistic Ximera-style caller
           |
           | form POST containing Sage code
           | optional support-trace header
           v
      SageCell /service
           |
           v
       JSON response
```

A reusable integration-contract test should therefore be able to target an
arbitrary SageCell service URL and verify at least:

- `application/x-www-form-urlencoded` Sage code submission;
- successful generated-Sage-style execution;
- expected JSON response shape;
- expression/stdout preservation;
- support-trace header acceptance;
- controlled behavior for Sage execution errors;
- request-size boundary behavior where appropriate.

Today that test can target `http://127.0.0.1:8888/service`. Later the same test
can be run from a Ximera or gateway host against a privately reachable SageCell
worker.

## Optional augmented deployment

The repository may later grow an optional augmented-install area containing
components such as:

- a gateway container;
- a named `sagecell-net` Podman network;
- gateway configuration examples;
- service-to-service authentication material or setup instructions;
- cache configuration;
- integration and deployment tests;
- systemd/Quadlet or equivalent service definitions.

This should remain optional. A user who only needs the standalone SageCell
worker should continue to be able to build and test the worker without also
installing the gateway stack.

## Design constraints to preserve now

Until the gateway work begins, SageCell deployment choices should preserve the
following properties:

1. SageCell remains a replaceable computation worker.
2. Raw SageCell is not treated as the permanent public API.
3. The worker can be attached to a named container network later.
4. Authentication and cache policy are not baked into SageCell patches.
5. Ximera-specific authorization logic remains outside the SageCell worker.
6. Integration tests should target the service contract rather than depend on
   one particular Ximera server implementation.

These constraints let the current standalone installation remain simple while
leaving a clear path to the planned gateway architecture.
