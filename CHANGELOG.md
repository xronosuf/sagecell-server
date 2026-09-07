# Changelog

## 2026-09-07

- Refreshed the reviewed Ubuntu package baseline after upstream Noble
  repositories removed the previously pinned curl/libcurl and libssh package
  revisions.
- Updated curl, `libcurl3t64-gnutls`, and `libcurl4t64` from
  `8.5.0-2ubuntu10.11` to `8.5.0-2ubuntu10.13`.
- Updated `libssh-4` from `0.10.6-2ubuntu0.4` to
  `0.10.6-2ubuntu0.5`.
- Verified the refreshed baseline with a clean container build and the full
  repository smoke test, including the 200,000-character request boundary.

## 2026-08-12

- `/service` Sage source limit increased from 100,000 to 200,000 characters
  so legitimate large Xronos canonical page programs can execute while
  retaining an explicit server-side request safety boundary.


## Unreleased

Initial standalone Ximera/Xronos SageCell container release.

Compatibility baseline:

- SageMath 10.9 pinned by immutable image digest.
- SageCell pinned to commit
  `281fc2356c52929fb08f4cd4cbfd8655e4ddd236`.
- Local in-container kernel provider.
- Modern Jupyter messaging compatibility.
- `/service` expression and display-result support.
- Privacy-safe support-trace correlation.
- `/service` Sage source limit increased from 65,000 to 100,000 characters.
- Exact reviewed operating-system package versions.
- Python dependency constraints matching the validated production
  environment.
