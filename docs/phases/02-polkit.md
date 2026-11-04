# Phase 2 — Polkit agent

**Status:** implemented; cross-session isolation check pending
**Depends on:** Phase 1 (shared dialog patterns helpful)

## In scope

- [x] Register a session PolicyKit authentication agent from Quickshell
- [x] Dialog UX via **Quickshell** (A9), using the existing askpass dialog styling

## Acceptance tests

- [x] Polkit-auth action shows lumen / Quickshell UI (user-tested with `pkexec`)
- [x] Cancel denies; correct password grants; wrong password retries (user-tested with `pkexec`)
- [ ] Agent only active in intended session (Quickshell registers against its own logind session; live check pending)

## Notes / blockers

Quickshell's `Quickshell.Services.Polkit.PolkitAgent` registers its listener for the **logind session of the shell process** on the system bus. It owns the Polkit PAM conversation, including multiple prompts, visible/non-visible responses, identity selection, errors and retry. The dialog uses the same Quickshell shell and styling as sudo askpass. Polkit itself verifies credentials and authorization; **the sudo askpass broker does not verify passwords and must not treat a candidate secret as a Polkit approval**. No secret passes through a subprocess, command line, environment variable, or `org.lumen.Auth` for Polkit.

Run `lumen-shell` in the desired graphical logind session. A single Polkit authentication agent can register per session; if another agent (e.g. KDE) is running, Lumen logs a registration failure and Polkit continues to use the existing agent. Disable that agent's autostart/unit **before** starting Lumen to test or use Lumen as the agent; do not stop a live agent during an in-flight request. Check registration with `quickshell ipc --path shell/shell.qml call status polkit` (`registered`/`unregistered`; with a packaged shell, use its installed QML path). `pkexec "$(command -v id)"` or `pkcheck --action-id org.freedesktop.policykit.exec --process $$ --allow-user-interaction` can exercise an action, subject to local policy; a non-privileged test identity may be needed for a reliable prompt. Test Cancel, wrong password/retry, correct password/grant, and launch in a second logind session to confirm no cross-session prompts. The Polkit daemon and a graphical logind session are prerequisites.

Local QML static validation and a Wayland config load succeeded. The user confirmed that Polkit authentication through `pkexec`, Cancel, and wrong-password retry work with the Lumen agent. Cross-session isolation is not yet confirmed. The development session initially had a running `polkit-kde-authentication-agent-1`, which rejected duplicate registration; no existing agent was stopped during implementation.
