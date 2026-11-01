# Security policy

Help keep Momentum and the people using it safe by reporting vulnerabilities privately.

## Report privately

Email **[kavishcan2002@gmail.com](mailto:kavishcan2002@gmail.com?subject=Momentum%20security%20report)** with the subject **Momentum security report**.

Do not open a public issue, pull request, or discussion with exploit details, private task data, credentials, or database contents. Email is the configured private reporting route for this project.

A useful report includes:

- The affected Momentum release and macOS version/architecture.
- A concise description of the issue and its potential impact.
- Reproduction steps or a minimal proof of concept, preferably with synthetic data.
- Relevant logs with personal content and secrets removed.
- Whether you would like to be credited when the issue is resolved.

Start with the description rather than sending a full personal database. If a private diagnostic file is needed, agree on what to share with the maintainer first.

## Supported versions

Security work targets the **latest published release**. Older versions do not have a separate maintained security branch. Include the version where you found the issue; checking the latest release is useful when safe and practical, but is not a prerequisite for sending an initial report.

## Scope

Security-relevant areas include:

- Unauthorized access to or disclosure of task, routine, timer, or backup data caused by Momentum.
- Unsafe handling of imported legacy data or malicious database inputs.
- Injection, filesystem-path handling, unintended permissions, and exploitable app behavior.
- Compromise of the repository's build/release process or published downloads.

Momentum currently uses local SQLite storage and optional local notifications. It has no cloud account, synchronization server, or automatic updater. Bugs in GitHub, macOS, or other outside products should also be reported to their respective maintainers when those products are the affected component.

Normal bugs without a security impact belong in [Issues](https://github.com/Kavishcan/momentum/issues/new/choose).

## Disclosure and response

Maintenance is best-effort; this policy does not promise a response or fix deadline, paid bounty, or dedicated security team. Please allow time to investigate and coordinate any public disclosure with the maintainer. Reporter credit can be included with consent.

Current downloads are ad-hoc signed development builds, not Developer ID signed or notarized. That known distribution status is documented in the README and release notes; it is not a claim of completed security certification. Verify downloads against the checksums attached to the [official release](https://github.com/Kavishcan/momentum/releases/latest).

For storage and sharing details, see [Privacy](docs/PRIVACY.md).
