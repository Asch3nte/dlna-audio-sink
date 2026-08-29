# Contributing

Reports from devices other than the one this was written against are the most
useful thing you can send. Failures especially.

## Reporting a device

Open an issue with:

- the output of `dlna-audio-sink --list`
- a `--verbose` run showing the negotiation
- the make, model and firmware version
- whether audio actually came out, and through which output

Redact your UDN and local addresses if you would rather not publish them; they
are not needed to diagnose most problems.

## Pull requests

Every change goes through a pull request and is reviewed before merging —
including mine. `main` is protected; nothing lands on it directly.

Please keep changes focused, and explain *why* in the commit message rather
than restating what the diff shows.

## Ground rules

**No third-party dependencies.** The tool is one file using only the Python
standard library, and it should stay that way. That is not minimalism for its
own sake: it means a user can read the whole program, and there is no package
supply chain to compromise. A pull request adding a dependency needs a very
good argument.

**Actions are pinned by commit SHA**, never by tag — a tag can be moved to
point at malicious code. Dependabot updates the pins.

**CI must not run untrusted code with credentials.** The workflow uses
`pull_request`, never `pull_request_target`. If you need something the current
CI cannot do, say so in the issue rather than reaching for a trigger that
gives a fork's code access to this repository.

**Device quirks belong behind a flag**, defaulting to the behaviour that works
for the most devices. `--no-content-length` is the model: a real device needed
it, so it exists, but it is off by default.

## Style

Match the surrounding code. Comments explain reasoning, not mechanics — the
interesting comments in this project are the ones recording *why* a renderer
misbehaves, because that knowledge is not recoverable from the code.

Run `ruff check --target-version py39 dlna-audio-sink` before pushing.
