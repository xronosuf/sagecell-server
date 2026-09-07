# Deployment profiles

This repository intentionally serves two related but distinct audiences.

The shared foundation is the same in both cases: a reproducible,
containerized SageCell service exposing the SageCell `/service` API.

## Profile 1: standalone SageCell container

This is the most general and public-facing use of the repository.

The goal is to provide a containerized SageCell server that can be built and
run independently of Ximera/Xronos. This is useful for developers,
researchers, instructors, and other projects that need a working SageCell
execution service without reproducing the historically fragile upstream
containerization process themselves.

The standalone profile should remain:

- easy to build from a fresh Linux host;
- documented without requiring Ximera knowledge;
- usable with Podman or Docker;
- self-contained except for normal container/runtime prerequisites;
- explicit about SageCell's arbitrary-code-execution security model;
- independently smoke-testable;
- compatible with the upstream SageCell `/service` request/response contract.

A user following the main quick-start path should not need to install or
understand Ximera-specific authentication, caching, routing, or gateway
components.

This profile is the baseline that the repository must continue to preserve.

## Profile 2: Ximera/Xronos Sage service

Ximera/Xronos uses the same SageCell container as a computation worker behind
an application-controlled service boundary.

For this profile, the standalone SageCell worker is only one component in a
larger architecture. The intended direction is to add an optional Sage gateway
layer responsible for Ximera-specific concerns such as:

- request authentication and authorization;
- exact-request or exact-code response caching;
- in-flight request coalescing;
- health-aware routing and reliability policy;
- privacy-safe diagnostics and support tracing;
- future browser-originated request authorization.

These capabilities should remain outside the SageCell worker itself so the
core container continues to be useful to non-Ximera users.

See `FUTURE-GATEWAY.md` for the current architectural handoff and design
constraints for this optional layer.

## Repository organization principle

The preferred organization is one shared `main` branch rather than separate
"generic" and "Ximera" branches.

The reason is that the SageCell worker should remain the same tested artifact
for both audiences. Ximera-specific functionality should be additive and
optional rather than maintained as a divergent fork.

A likely long-term layout is approximately:

```text
sagecell-server/
    Dockerfile
    smoke-test.sh
    ... standalone worker files ...

    optional Ximera integration/
        gateway container
        gateway configuration
        named Podman network definitions
        integration tests
        deployment/service definitions
```

The exact directory names are not fixed yet. The important constraint is that
Ximera augmentation must not make the standalone quick-start path harder to
understand or use.

## Documentation priority

The README should continue to lead with the general standalone SageCell use
case.

Ximera/Xronos-specific material should appear as a clearly labeled optional
section or linked document after the core build/run/test instructions. This
keeps the repository approachable to public users while preserving enough
architectural context for Ximera server development.

## Compatibility ownership

Both profiles share the same compatibility-controlled Sage environment.
Changes to SageMath, SageCell, operating-system packages, Python dependencies,
or local compatibility patches should therefore be validated against the
standalone smoke tests first and then, where relevant, against Ximera content
and integration tests.

This shared baseline is intentional: Ximera-specific integration should build
on a generally usable SageCell container rather than depend on a separate,
private implementation.
