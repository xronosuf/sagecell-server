# Experimental latest-stable SageMath build

The normal build in this repository is deliberately conservative and
reproducible. It currently uses the reviewed SageMath 10.9 base image pinned by
immutable digest together with reviewed operating-system and Python dependency
versions.

For public users who want to try a newer SageMath release, this repository also
provides an **experimental latest-stable compatibility path**.

## What "experimental" means here

"Experimental" refers to the compatibility of this containerization and
SageCell integration with a moving SageMath target.

It does **not** mean that the build intentionally uses a development or beta
version of SageMath.

By default, the experimental Dockerfile uses:

```text
docker.io/sagemath/sagemath:latest
```

which is intended to track the latest stable SageMath container published
upstream.

The repository does not automatically use SageMath `develop`. A user who
intentionally wants an upstream development image may override
`SAGEMATH_IMAGE` manually, but doing so is outside the supported and documented
experimental path and should be expected to require debugging.

## Important support distinction

There are therefore two different levels of compatibility:

| Build | SageMath selection | Status |
| --- | --- | --- |
| Normal `Dockerfile` | reviewed SageMath 10.9 image digest | compatibility-controlled and tested |
| `Dockerfile.experimental` | upstream `sagemath/sagemath:latest` | latest stable SageMath, but container compatibility is experimental |

The experimental build is provided so interested users can probe newer SageMath
environments without weakening the reproducibility guarantees of the normal
build.

A successful experimental build is not automatically promoted to the reviewed
baseline. Promotion should still involve deliberate compatibility testing.

## Run the compatibility report first

Before attempting the full experimental build, run:

```bash
./compatibility-report.sh
```

With no argument, the report checks:

```text
docker.io/sagemath/sagemath:latest
```

You can also inspect another SageMath container image explicitly:

```bash
./compatibility-report.sh docker.io/sagemath/sagemath:<tag-or-reference>
```

For example, this allows a user to examine an intermediate SageMath release
between the repository's reviewed baseline and the current upstream `latest`
image without editing repository files.

### What the report checks

The report prints:

1. the SageMath version and Sage Python version in the selected base image;
2. every reviewed Ubuntu package pin that is still available exactly;
3. every reviewed Ubuntu package pin that is no longer available, together
   with the current repository candidate when one can be determined;
4. every reviewed Python baseline package whose version differs from the
   selected SageMath base image;
5. a final **ACTION SUMMARY** that lists the exact package names and version
   differences requiring review.

Example shape:

```text
ACTION SUMMARY

OS package pins requiring review: 2
  - libexample: reviewed 1.2.3 -> repository candidate 1.2.4
  - curl: reviewed 8.x.y -> repository candidate 8.x.z

Python baseline differences requiring review: 3
  - tornado pinned=... base-image=...
  - jupyter_client pinned=... base-image=...
  - ipykernel pinned=... base-image=...
```

The report deliberately names each difference rather than only returning a
count.

### What the report cannot prove

The reported `available` or `base-image` version is **not claimed to be the
minimum compatible version**.

Determining the true minimum compatible version generally requires building
and testing combinations rather than inspecting package metadata alone.

Likewise, a version difference does not necessarily indicate an incompatibility.
Some packages are intentionally installed by the SageCell build rather than
being expected in the SageMath base image.

The compatibility report is therefore a triage and debugging aid, not a
replacement for an actual build.

## Build against latest stable SageMath

After reviewing the report, build the experimental image with:

```bash
podman build \
  --format docker \
  -f Dockerfile.experimental \
  -t sagecell-server:experimental \
  .
```

The experimental Dockerfile intentionally:

- starts from `sagemath/sagemath:latest`;
- uses the same operating-system package **names** as the reviewed build but
  allows the base distribution repositories to select current versions;
- installs the direct SageCell Python dependencies without the reviewed frozen
  constraint set;
- keeps the SageCell source commit pinned so that SageMath/dependency changes
  are easier to distinguish from simultaneous SageCell source changes;
- applies the same local SageCell compatibility patches and configuration as
  the normal build.

## Test the result

A successful image build is only the first compatibility check.

Run:

```bash
./smoke-test.sh sagecell-server:experimental
```

The smoke test exercises actual SageCell startup, normal execution, the request
size boundary, and the pinned SageCell source revision.

If either the build or smoke test fails, the failure is useful compatibility
information. It may indicate that a newer SageMath/Python/Jupyter environment
requires changes to dependency selection or the local SageCell compatibility
patches.

## Trying a specific SageMath image

Advanced users can override the base image without editing the Dockerfile:

```bash
podman build \
  --format docker \
  -f Dockerfile.experimental \
  --build-arg SAGEMATH_IMAGE=docker.io/sagemath/sagemath:<tag-or-reference> \
  -t sagecell-server:experimental \
  .
```

Run the compatibility report against that same image first so the diagnostic
output and build target refer to the same environment.

## Do not replace the reviewed build silently

The experimental mode exists alongside the reviewed build; it does not replace
it.

In particular, Ximera/Xronos deployments should continue using the deliberately
reviewed compatibility baseline until a newer SageMath version has been tested
against representative existing course content and intentionally promoted.
