# SageCell Server

This repository provides a containerized SageCell server for two related uses:

1. a **general standalone SageCell service** for public use; and
2. the Sage computation worker used by **Ximera/Xronos**, with optional
   Ximera-specific integration layered on top.

The standalone container is intentionally useful without Ximera. If you only
want a working containerized SageCell `/service` endpoint, you can follow the
quick-start instructions below and ignore the Ximera-specific architecture
material.

## Build profiles at a glance

| Profile | SageMath | Status | Purpose |
| --- | --- | --- | --- |
| Reviewed/reproducible | **10.9** | Supported and compatibility-tested | Default build; controlled versions for reproducibility and Ximera legacy-content compatibility |
| Latest-stable compatibility | upstream `sagemath/sagemath:latest` | **Experimental container profile** | Lets public users try the newest stable SageMath image with current dependencies |
| Ximera/Xronos augmentation | same SageCell worker | Optional / evolving | Adds future authentication, authorization, caching, routing, and integration around the standalone worker |

**Important:** “experimental” above refers to this repository's
containerization/integration compatibility with a moving SageMath target. It
does **not** mean that the profile intentionally uses an experimental SageMath
release. The experimental profile defaults to upstream `latest`, meaning the
latest stable SageMath image published by the SageMath project.

As of the most recent repository validation on 2026-09-07, upstream `latest`
resolved to SageMath 10.9, so the experimental mechanism was tested against the
same SageMath release as the reviewed build while allowing newer dependency
resolution.

See:

- `EXPERIMENTAL-LATEST.md` for the latest-stable compatibility workflow;
- `DEPLOYMENT-PROFILES.md` for the standalone-versus-Ximera organization;
- `FUTURE-GATEWAY.md` for the planned optional Ximera Sage gateway layer;
- `BUILD-PROVENANCE.md` for the exact reviewed compatibility baseline.

## What the reviewed build provides

The default container currently uses:

- SageMath 10.9, pinned by immutable base-image digest;
- SageCell commit
  `281fc2356c52929fb08f4cd4cbfd8655e4ddd236`;
- a local in-container Sage kernel provider;
- the SageCell `/service` API;
- a maximum decoded Sage `code` size of 200,000 characters;
- pinned operating-system and important Python dependency versions.

The default is deliberately conservative. Unexpected SageMath, SageCell,
Python, Jupyter, or operating-system dependency changes can alter behavior of
existing Sage code, including published mathematical content. Reviewed updates
are therefore made manually and tested before becoming the new default.

## Important security warning

SageCell executes Sage/Python code.

Do not expose a raw SageCell server directly to the public Internet unless you
understand the security implications of allowing arbitrary code execution and
have designed an appropriate isolation and authorization model.

For local testing, the instructions below bind SageCell only to `127.0.0.1`,
which means it is reachable only from the same computer.

For Ximera deployments, the intended long-term architecture places a separate
application-controlled gateway in front of the SageCell worker. Standalone
users do not need that optional layer.

---

# Quick start for Ubuntu using Podman

This section is the **standalone SageCell quick start**. No Ximera installation
or knowledge is required.

A **container image** is the packaged SageCell system.

A **container** is a running copy of that image.

Podman is the container program used in the examples below. Docker can also be
used; Docker instructions appear later in this README.

## 1. Install the required tools

On Ubuntu:

    sudo apt-get update
    sudo apt-get install -y git curl podman

Check that they are available:

    git --version
    curl --version
    podman --version

## 2. Clone this repository

    git clone https://github.com/xronosuf/sagecell-server.git
    cd sagecell-server

You should see files including:

    Dockerfile
    Dockerfile.experimental
    README.md
    smoke-test.sh
    compatibility-report.sh
    patch_sagecell.py
    packages-known-good.txt
    requirements-known-good.txt

## 3. Build the reviewed SageCell image

Run:

    podman build \
      --format docker \
      -t sagecell-server:local \
      .

The final `.` tells Podman to use the current directory as the build context.

The first build can download a substantial SageMath base image and the pinned
dependencies.

A successful build should create:

    sagecell-server:local

Confirm it exists:

    podman images sagecell-server:local

## 4. Run SageCell locally

Start a container:

    podman run -d \
      --name sagecell-server \
      -p 127.0.0.1:8888:8888 \
      sagecell-server:local

Explanation:

- `-d` runs the container in the background.
- `--name sagecell-server` gives it an easy-to-remember name.
- `-p 127.0.0.1:8888:8888` maps port 8888 inside the container to port
  8888 on the local computer only.
- `sagecell-server:local` is the image built in the previous step.

SageCell takes a short time to initialize.

Check the running container:

    podman ps --filter name=sagecell-server

## 5. Wait for the health check

Run:

    podman inspect sagecell-server \
      --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'

Initially, health may be reported as:

    Health=starting

After SageCell has initialized, it should become:

    Status=running Health=healthy

To watch startup messages:

    podman logs -f sagecell-server

Press `Ctrl-C` to stop watching the logs. This does not stop the container.

## 6. Verify SageCell with a real calculation

Run:

    curl \
      --data-urlencode 'code=print(6*7)' \
      http://127.0.0.1:8888/service

A healthy server should return JSON containing output equivalent to:

    "stdout": "42\n"

and:

    "success": true

You can also test a bare Sage expression:

    curl \
      --data-urlencode 'code=2+3' \
      http://127.0.0.1:8888/service

The response should contain the result `5` and report success.

## 7. Run the repository smoke test

If the container named `sagecell-server` from the previous step is still
running, stop and remove it first so the test port is available:

    podman stop sagecell-server
    podman rm -v sagecell-server

Then run:

    ./smoke-test.sh sagecell-server:local

The smoke test starts a temporary container, waits for SageCell, checks normal
execution, verifies the 200,000-character request boundary and pinned SageCell
commit, and removes the temporary container and its anonymous volume when it
finishes.

A successful run ends with:

    SageCell smoke test passed.

## 8. Start the normal container again

If you want SageCell to remain running after the smoke test:

    podman run -d \
      --name sagecell-server \
      -p 127.0.0.1:8888:8888 \
      sagecell-server:local

---

# Optional: try the latest stable SageMath image

The reviewed default is intentionally pinned. Public users who want to test the
latest stable SageMath image can use the separate experimental compatibility
profile without weakening the default build.

First run the diagnostic compatibility report:

    ./compatibility-report.sh

By default it checks:

    docker.io/sagemath/sagemath:latest

The report shows:

- the SageMath and Sage Python versions in the selected base image;
- reviewed OS package versions that are still available;
- OS package versions requiring review;
- reviewed Python packages already present at matching versions;
- Python packages present at different versions;
- Python packages absent from the base image and therefore expected to be
  installed or resolved during the experimental build.

`UPDATE` in the report means a different installed version is already present.
`ABSENT` means only that the package is not included in the base SageMath
image; absence by itself is **not** an incompatibility.

The report's observed candidate or installed versions are not claims about the
minimum compatible version. A real build and smoke test are still required.

Build the latest-stable compatibility image with:

    podman build \
      --format docker \
      -f Dockerfile.experimental \
      -t sagecell-server:experimental \
      .

Then test it:

    ./smoke-test.sh sagecell-server:experimental

The experimental Dockerfile deliberately uses `sagemath/sagemath:latest`, not
SageMath's development image. Advanced users who intentionally want a different
SageMath image may provide one explicitly, but should expect to diagnose
compatibility problems themselves.

You can also run the compatibility report against a specific SageMath image,
which is useful when investigating an intermediate release:

    ./compatibility-report.sh docker.io/sagemath/sagemath:<tag>

See `EXPERIMENTAL-LATEST.md` for detailed guidance and interpretation.

---

# Optional Ximera/Xronos integration

The same standalone SageCell worker is also the computation component for
Ximera/Xronos.

The Ximera-specific architecture is intentionally **additive and optional**.
A standalone SageCell user can ignore this entire section and the linked Ximera
documents.

The intended direction is for Ximera to place a separate gateway/service in
front of the raw SageCell worker. That layer is expected to own concerns such
as:

- request authentication and authorization;
- exact-request or exact-code response caching;
- in-flight request coalescing;
- health-aware routing and reliability policy;
- privacy-safe diagnostics and support tracing;
- future browser-originated request authorization.

Those responsibilities should remain outside the core SageCell image so the
standalone container stays generally useful.

See `DEPLOYMENT-PROFILES.md` and `FUTURE-GATEWAY.md` for the current design
handoff and planned direction.

---

# Stopping and starting SageCell

Stop the container without deleting it:

    podman stop sagecell-server

Start that same container again:

    podman start sagecell-server

View its status:

    podman ps -a --filter name=sagecell-server

View recent logs:

    podman logs --tail 100 sagecell-server

Remove the container and any anonymous volume attached to it:

    podman rm -f -v sagecell-server

Removing a container does **not** delete the image from which it was created.

---

# Updating to a newer version of this repository

Enter the cloned repository:

    cd sagecell-server

Download repository changes:

    git pull --ff-only

Rebuild the reviewed image:

    podman build \
      --format docker \
      -t sagecell-server:local \
      .

If an old container exists, remove it:

    podman rm -f -v sagecell-server

Then start a new container from the rebuilt image:

    podman run -d \
      --name sagecell-server \
      -p 127.0.0.1:8888:8888 \
      sagecell-server:local

Verify it again:

    curl \
      --data-urlencode 'code=print(6*7)' \
      http://127.0.0.1:8888/service

---

# Using Docker instead of Podman

The reviewed image is also intended to build with Docker.

Install Docker Engine using the installation instructions for your operating
system, then clone this repository as described above.

Build:

    docker build \
      -t sagecell-server:local \
      .

Run:

    docker run -d \
      --name sagecell-server \
      -p 127.0.0.1:8888:8888 \
      sagecell-server:local

Check status:

    docker ps --filter name=sagecell-server

Verify SageCell:

    curl \
      --data-urlencode 'code=print(6*7)' \
      http://127.0.0.1:8888/service

Stop and remove it:

    docker stop sagecell-server
    docker rm -v sagecell-server

The repository smoke test and compatibility-report script currently use
Podman directly. Docker users can perform the equivalent manual verification
or adapt those scripts.

---

# Building without silently upgrading dependencies

The reviewed build intentionally pins the compatibility baseline.

The default Dockerfile pins the SageMath base image by immutable image digest
and pins SageCell to a specific Git commit.

`packages-known-good.txt` records exact reviewed operating-system package
versions.

`requirements-known-good.txt` constrains important Python dependencies.

If a pinned dependency disappears from an upstream package repository, the
preferred behavior is for the reviewed build to **fail** instead of silently
replacing it with a newer version.

Such a failure means that a new compatibility baseline needs to be reviewed
and tested.

The separate `Dockerfile.experimental` intentionally relaxes those exact
version constraints for users who want to probe the latest stable SageMath
environment. That experimental behavior must not be confused with the reviewed
default.

---

# Request-size behavior

The `/service` endpoint accepts a decoded Sage `code` value containing up to
200,000 characters.

The following boundary has been tested:

- 200,000 characters: accepted;
- 200,001 characters: HTTP 413 response.

The limit applies to the decoded `code` form field, not to the total
URL-encoded HTTP request. Therefore an HTTP POST may be larger than 200,000
bytes while still containing no more than 200,000 characters of Sage source.

---

# Compatibility testing before changing reviewed pins

Do not update SageMath, SageCell, or pinned dependencies in the reviewed build
solely because a newer release is available.

A reviewed compatibility update should include:

1. explicitly changing the intended pin;
2. rebuilding the image;
3. reviewing operating-system and Python dependency changes;
4. running `smoke-test.sh`;
5. testing representative Sage/Ximera activities where relevant;
6. testing large generated Sage programs;
7. running a broader Xronos/Ximera integration audit when available;
8. documenting the compatibility change in `CHANGELOG.md`.

The goal is not to prevent updates. The goal is to make updates deliberate and
testable so existing authored mathematical content does not change behavior
unexpectedly.

---

# Troubleshooting

## `podman: command not found`

Install Podman:

    sudo apt-get update
    sudo apt-get install -y podman

## The reviewed build fails while installing an exact package version

Do not immediately remove or loosen the version pin.

The project intentionally fails rather than silently moving to an untested
dependency version. Review the unavailable package and establish a new
compatibility baseline if an update is required.

If your goal is instead to experiment with the latest stable SageMath and
current dependencies, use the separate experimental profile rather than
loosening the reviewed Dockerfile.

## Port 8888 is already in use

Find containers using the port:

    podman ps

You can stop the existing SageCell container:

    podman stop sagecell-server

Or choose another host port, for example 18888:

    podman run -d \
      --name sagecell-server \
      -p 127.0.0.1:18888:8888 \
      sagecell-server:local

Then test it at:

    curl \
      --data-urlencode 'code=print(6*7)' \
      http://127.0.0.1:18888/service

## The container starts but SageCell does not answer yet

Check its health:

    podman inspect sagecell-server \
      --format 'Status={{.State.Status}} Health={{.State.Health.Status}}'

Read its logs:

    podman logs --tail 200 sagecell-server

SageCell can require some startup time before its first Sage kernel is ready.

## Remove everything and rebuild locally

Remove the container and anonymous volume:

    podman rm -f -v sagecell-server

Remove the local image:

    podman rmi sagecell-server:local

Then rebuild:

    podman build \
      --format docker \
      -t sagecell-server:local \
      .

---

# Files in this repository

`Dockerfile`
: Builds the reviewed, pinned SageMath/SageCell container.

`Dockerfile.experimental`
: Opt-in latest-stable SageMath compatibility build with moving dependency
  resolution.

`compatibility-report.sh`
: Compares a selected SageMath base image with the reviewed OS/Python baseline
  and identifies exact differences requiring review.

`EXPERIMENTAL-LATEST.md`
: Detailed latest-stable compatibility workflow and interpretation guidance.

`DEPLOYMENT-PROFILES.md`
: Explains the standalone public profile and optional Ximera/Xronos profile.

`FUTURE-GATEWAY.md`
: Architectural handoff for the planned optional Ximera authentication/cache
  gateway in front of SageCell.

`patch_sagecell.py`
: Applies compatibility changes needed by this service-only deployment.

`sagecell_config.py`
: SageCell configuration copied into the image.

`sagecell_log.py`
: SageCell logging configuration and support-trace handling.

`docker-entrypoint.sh`
: Starts the SageCell web service inside the container.

`healthcheck.sh`
: Container health check using a small Sage calculation.

`smoke-test.sh`
: Standalone runtime and request-boundary test. Temporary anonymous volumes are
  removed during cleanup.

`packages-known-good.txt`
: Exact reviewed Ubuntu package versions added to the SageMath base image.

`requirements-known-good.txt`
: Important pinned/constrained Sage/Python dependencies for the reviewed build.

`BUILD-PROVENANCE.md`
: Exact reviewed compatibility baseline and upstream provenance.

`CHANGELOG.md`
: Compatibility release history.

---

# Upstream projects and licensing

This repository builds on the upstream SageCell and SageMath projects.

Upstream SageCell states that most of its files use a modified BSD license,
some files use GPLv2+, and the SageCell repository as a whole is GPLv2+.

SageMath is also distributed as free/open-source software under GPLv2+ with
components under compatible licenses.

See the upstream projects and the license files included with their source for
the authoritative licensing terms.

---

# License

This repository is distributed under the GNU General Public License, version 2
or (at your option) any later version (`GPL-2.0-or-later`).

See `LICENSE` for the full GPL version 2 license text.

The container also incorporates upstream SageCell, SageMath, and their
dependencies, which retain their respective upstream copyright and licensing
terms.

---

# Project scope

This is a **service-only SageCell build**. It intentionally does not build the
full upstream embedded SageCell browser frontend and its JavaScript/JSmol
assets.

For standalone users, the result is a containerized `/service` computation API
that can be integrated into another application.

For Ximera/Xronos, that same worker is intended to sit behind an optional
application-controlled gateway rather than absorb Ximera-specific caching,
authorization, and routing logic into the core SageCell image.
