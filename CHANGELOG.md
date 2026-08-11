# Changelog

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
