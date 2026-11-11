---
name: ego-tiny
description: Browser automation through ego tiny, the telemetry-free build of the ego browser installed alongside ego lite. Use it to open and operate websites, fill forms, click, take screenshots, extract page data and test web apps when the user asks for ego tiny, or when a task must not send anything to the browser vendor's servers. ego tiny has its own profile, so sites the user signed in to in ego lite are not signed in here. The `ego-browser` skill drives ego lite; this skill drives ego tiny with the `ego-tiny` command.
metadata:
  bootstrap: "true"
---

# ego-tiny

Before any browser task, run:

```bash
ego-tiny skill
```

and follow its output. It prints the usage guide for the runtime this build
ships, with every command already written as `ego-tiny`.

The guide ends with a line starting `[ego-browser:skill] end of guide`. If that
line is missing, the output was truncated: save it to a file and read the file
in parts, for example `ego-tiny skill > "$TMPDIR/ego-tiny-skill.md"`.

## How ego tiny differs from ego lite

- Command: `ego-tiny`, never `ego-browser`. `ego-browser` talks to ego lite.
- App: `/Applications/ego tiny.app`. If `ego-tiny` reports that the browser is
  not running, start it with `open -g "/Applications/ego tiny.app"`.
- Profile and task spaces are separate from ego lite's.
- `ego-tiny upgrade` is disabled. The app is rebuilt from the ego-tiny
  repository (`tiny/build-tiny.sh --install`), not updated in place.
- Requests to the vendor's hosts (`*.citrolabs.ai`, `*.ego.app`), PostHog,
  Sentry and Langfuse fail by design. Do not treat that as a network fault.
