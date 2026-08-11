# Build provenance

This project intentionally pins the major pieces of the SageCell runtime.

## SageMath base image

The container is based on SageMath 10.9 using the immutable OCI image digest:

`docker.io/sagemath/sagemath@sha256:e068670ae5863b54b2550e72437ec637b0283acb0dc712c8584c124dbf44e667`

## SageCell source

The SageCell source is pinned to Git commit:

`281fc2356c52929fb08f4cd4cbfd8655e4ddd236`

Upstream repository:

`https://github.com/sagemath/sagecell`

## Operating-system packages

`packages-known-good.txt` records the explicitly reviewed Ubuntu package
versions installed on top of the pinned SageMath image.

The build intentionally requests exact versions. If those exact packages are
no longer available from the configured package repositories, the preferred
behavior is for the build to fail rather than silently substitute newer
versions.

## Python environment

`requirements-known-good.txt` constrains the Sage/Python packages needed by
the SageCell layer to versions validated against the Ximera/Xronos workload.

## Compatibility patches

`patch_sagecell.py` applies the local compatibility changes required by this
deployment, including:

- running SageCell kernels locally inside the container rather than through
  the upstream SSH-provider architecture;
- compatibility with the modern Jupyter messaging environment in SageMath
  10.9;
- returning expression/display results through the `/service` endpoint;
- support-trace logging used for privacy-safe request correlation;
- increasing the Sage source-code limit for `/service` from 65,000 to
  100,000 characters.

The 100,000-character limit applies to the decoded Sage `code` form field,
not to the total encoded HTTP POST size.
