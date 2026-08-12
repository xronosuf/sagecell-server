# Ximera SageCell Server

This repository builds the SageCell server container used by Ximera/Xronos.

It is designed to provide a **reproducible, compatibility-controlled Sage
environment** for Ximera course content. SageMath, SageCell, important Python
dependencies, and the additional operating-system packages are intentionally
pinned instead of automatically following the newest upstream releases.

That is deliberate: an unexpected SageMath or SageCell update can change the
behavior of Sage code that already appears in published course material.

## What this repository provides

The container built from this repository currently uses:

- SageMath 10.9;
- SageCell commit
  `281fc2356c52929fb08f4cd4cbfd8655e4ddd236`;
- a local in-container Sage kernel provider;
- the SageCell `/service` API needed by Ximera/Xronos;
- a maximum decoded Sage `code` size of 200,000 characters;
- pinned operating-system and important Python dependency versions.

See `BUILD-PROVENANCE.md` for the exact base-image digest and dependency
information.

## Important security warning

SageCell executes Sage/Python code.

Do not expose a SageCell server directly to the public Internet unless you
understand the security implications of allowing arbitrary code execution and
have designed an appropriate isolation and authorization model.

This container was built primarily as the computation service behind a
Ximera/Xronos server. The Ximera/Xronos deployment is expected to control how
requests reach SageCell.

For local testing, the instructions below bind SageCell only to
`127.0.0.1`, which means it is reachable only from the same computer.

---

# Quick start for Ubuntu using Podman

This section assumes very little prior container experience.

A **container image** is the packaged SageCell system.

A **container** is a running copy of that image.

Podman is the container program used in the examples below. Docker can also
be used; Docker instructions appear later in this README.

## 1. Install the required tools

On Ubuntu:

    sudo apt-get update
    sudo apt-get install -y git curl podman

Check that they are available:

    git --version
    curl --version
    podman --version

## 2. Clone this repository

Choose a directory where you want the source code to live, then run:

    git clone https://github.com/xronosuf/sagecell-server.git

Enter the repository:

    cd sagecell-server

You can confirm that you are in the correct directory with:

    pwd
    ls

You should see files including:

    Dockerfile
    README.md
    smoke-test.sh
    patch_sagecell.py
    packages-known-good.txt
    requirements-known-good.txt

## 3. Build the SageCell image

Run:

    podman build \
      --format docker \
      -t sagecell-server:local \
      .

The final `.` is important. It tells Podman to use the current directory as
the build context.

The first build can download a substantial SageMath base image and the pinned
dependencies.

A successful build should end with output indicating that the image was
created and tagged as:

    sagecell-server:local

Confirm that the image exists:

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

If you want to watch the startup messages:

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
running, stop it first so port 8888 is available:

    podman stop sagecell-server
    podman rm sagecell-server

Then run:

    ./smoke-test.sh sagecell-server:local

The smoke test starts a temporary container, waits for SageCell, checks normal
execution, verifies the 200,000-character request boundary, and removes the
temporary container when it finishes.

A successful run ends with:

    SageCell smoke test passed.

## 8. Start the normal container again

If you want SageCell to remain running after the smoke test:

    podman run -d \
      --name sagecell-server \
      -p 127.0.0.1:8888:8888 \
      sagecell-server:local

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

Remove the container:

    podman rm -f sagecell-server

Removing a container does **not** delete the image from which it was created.

---

# Updating to a newer version of this repository

Enter the cloned repository:

    cd sagecell-server

Download repository changes:

    git pull --ff-only

Rebuild the image:

    podman build \
      --format docker \
      -t sagecell-server:local \
      .

If an old container exists, remove it:

    podman rm -f sagecell-server

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

The image is also intended to build with Docker.

Install Docker Engine using the installation instructions for your operating
system from the official Docker documentation.

After Docker is installed, clone the repository exactly as described above:

    git clone https://github.com/xronosuf/sagecell-server.git
    cd sagecell-server

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
    docker rm sagecell-server

The repository smoke test currently uses Podman directly. Docker users can
perform the manual verification commands above, or adapt the smoke test by
replacing `podman` with `docker`.

---

# Building without silently upgrading dependencies

This repository intentionally pins the compatibility baseline.

The Dockerfile pins the SageMath base image by immutable image digest and
pins SageCell to a specific Git commit.

`packages-known-good.txt` records exact reviewed operating-system package
versions.

`requirements-known-good.txt` constrains important Python dependencies.

If a pinned dependency disappears from an upstream package repository, the
preferred behavior is for the build to **fail** instead of silently replacing
it with a newer version.

Such a failure means that a new compatibility baseline needs to be reviewed
and tested.

---

# Request-size behavior

The `/service` endpoint accepts a decoded Sage `code` value containing up to
200,000 characters.

The following boundary has been tested:

- 200,000 characters: accepted;
- 200,001 characters: HTTP 413 response.

The limit applies to the decoded `code` form field, not to the total
URL-encoded HTTP request. Therefore an HTTP POST may be larger than 200,000
bytes while still containing less than 200,000 characters of Sage source.

---

# Compatibility testing before changing pins

Do not update SageMath, SageCell, or pinned dependencies solely because a
newer release is available.

A compatibility update should include:

1. explicitly changing the intended pin;
2. rebuilding the image from scratch;
3. reviewing operating-system and Python dependency changes;
4. running `smoke-test.sh`;
5. testing representative Ximera activities;
6. testing large generated Sage programs;
7. running a broader Xronos page/runtime audit when available;
8. documenting the compatibility change in `CHANGELOG.md`.

The goal is not to prevent updates. The goal is to make updates deliberate
and testable so existing authored mathematical content does not change
behavior unexpectedly.

---

# Troubleshooting

## `podman: command not found`

Install Podman:

    sudo apt-get update
    sudo apt-get install -y podman

## The build fails while installing an exact package version

Do not immediately remove or loosen the version pin.

The project intentionally fails rather than silently moving to an untested
dependency version. Review the unavailable package and establish a new
compatibility baseline if an update is required.

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

Remove the container:

    podman rm -f sagecell-server

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
: Builds the pinned SageMath/SageCell container.

`patch_sagecell.py`
: Applies the compatibility changes needed by this service-only deployment.

`sagecell_config.py`
: SageCell configuration copied into the image.

`sagecell_log.py`
: SageCell logging configuration and support-trace handling.

`docker-entrypoint.sh`
: Starts the SageCell web service inside the container.

`healthcheck.sh`
: Container health check using a small Sage calculation.

`smoke-test.sh`
: Standalone runtime and request-boundary test.

`packages-known-good.txt`
: Exact reviewed Ubuntu package versions added to the SageMath base image.

`requirements-known-good.txt`
: Important pinned/constrained Sage/Python dependencies.

`BUILD-PROVENANCE.md`
: Exact compatibility baseline and upstream provenance.

`CHANGELOG.md`
: Compatibility release history.

---

# Upstream projects and licensing

This repository builds on the upstream SageCell and SageMath projects.

Upstream SageCell states that most of its files use a modified BSD license,
some files use GPLv2+, and the SageCell repository as a whole is GPLv2+.

SageMath is also distributed as free/open-source software under GPLv2+ with
components under compatible licenses.

See the upstream projects and the license files included with their source
for the authoritative licensing terms.

---

# License

This repository is distributed under the GNU General Public License,
version 2 or (at your option) any later version (`GPL-2.0-or-later`).

See `LICENSE` for the full GPL version 2 license text.

The container also incorporates upstream SageCell, SageMath, and their
dependencies, which retain their respective upstream copyright and
licensing terms.

# Project scope

This is a **service-only SageCell build** for the computation API used by
Ximera/Xronos.

It intentionally does not build the full upstream embedded SageCell browser
frontend and its JavaScript/JSmol assets. Ximera/Xronos provides the
browser-facing activity interface and uses SageCell as the computation
service.
