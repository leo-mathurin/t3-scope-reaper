# t3-scope-reaper

Stops [T3 Code](https://github.com/pingdotgg/t3code) agent scopes on Linux after their agent has exited, so leftover processes do not run forever.

## The problem

On Linux, T3 Code starts each agent in a transient systemd scope:

```
systemd-run --user --scope --unit=t3code-codex-1a2b3c4d.scope -- codex app-server
```

A scope stays active while it contains a process. When the agent exits, the processes it started stay in the scope, now children of `systemd --user`. T3 Code stops the scope for Claude, ACP, Pi and Muse agents ([pingdotgg/t3code#21299](https://github.com/pingdotgg/t3code/pull/21299)). It does not stop the scope of the shared Codex app-server.

In one case, two `portless list` processes started by a Codex agent each used 100% of a CPU core for 7.5 hours after the agent exited. The machine could not go to sleep, because its idle detector saw the load.

## How it works

A systemd user timer runs `t3-scope-reaper` every 5 minutes. For each `t3code-*.scope` in `app-t3code-agents.slice`:

1. If a process in the scope has a parent in `t3code.service`, the agent is alive. The scope is kept.
2. If not, the scope is orphaned. The script records when it first saw it.
3. After 10 minutes in the orphaned state, the script runs `systemctl --user stop` on the scope. Agent scopes use `KillMode=control-group`, so all of their processes stop.

The script does nothing while `t3code.service` is not active, because live agents have no parent in the service during a restart.

Terminal scopes (`t3code-terminal-*`) are skipped by default. A closed terminal can leave a process that you want to keep, for example a dev proxy or a server started with `nohup`.

Each stop goes to the journal with the list of stopped processes.

## Install

Requirements: Linux, a systemd user manager, cgroup v2, and T3 Code running as the `t3code.service` user unit.

```sh
git clone https://github.com/leo-mathurin/t3-scope-reaper.git
cd t3-scope-reaper
./install.sh
```

This installs `~/.local/bin/t3-scope-reaper` and the user units in `~/.config/systemd/user`, then enables the timer.

To remove it:

```sh
./install.sh --uninstall
```

## Use

```sh
t3-scope-reaper --dry-run                  # list orphaned scopes, change nothing
journalctl --user -u t3-scope-reaper       # see what was stopped
systemctl --user list-timers t3-scope-reaper.timer
```

## Configuration

Set these variables with `systemctl --user edit t3-scope-reaper.service`:

| Variable | Default | Effect |
| --- | --- | --- |
| `T3_SCOPE_REAPER_GRACE` | `600` | Seconds a scope must stay orphaned before it is stopped. |
| `T3_SCOPE_REAPER_TERMINALS` | `0` | Set to `1` to also stop orphaned terminal scopes. |
| `T3_SCOPE_REAPER_SERVICE` | `t3code.service` | Name of the T3 Code user unit. |

Example:

```ini
[Service]
Environment=T3_SCOPE_REAPER_TERMINALS=1
```

## Limits

- A background job that an agent started on purpose stops 10 to 15 minutes after its agent exits. T3 Code does the same for the agents it cleans up itself.
- When T3 Code fixes this for Codex, this tool has nothing left to do. You can then remove it.

## License

MIT
