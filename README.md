# herdr-agent-icons

A [herdr](https://herdr.dev) plugin that shows an icon instead of the agent name
(`claude`, `codex`, `grok`, `pi`, ...) in the agent sidebar.

It sets each agent pane's display name with `herdr pane report-metadata --display-agent`:

- when the herdr server starts (existing panes)
- on `pane.agent_detected` (new agents)
- on demand: `herdr plugin action invoke blockedpath.agent-icons.apply`

## Install

Requires herdr 0.9.3+, `bash` and `jq`. Linux and macOS (including WSL).

```bash
herdr plugin install BlockedPath/herdr-agent-icons
```

Or link a local checkout:

```bash
herdr plugin link /path/to/herdr-agent-icons
```

Agents that are already running get their icons on the next herdr server start,
or right away with the `apply` action above.

## Icons

| Agent | Icon |
| --- | --- |
| claude | ✺ |
| codex | >_ |
| grok | 𝕏 |
| pi | π |
| gemini | ✦ |
| cursor | ➤ |
| open_code | ◇ |

To change or add icons, create `icons.conf` in the plugin's config directory
(`herdr plugin config-dir blockedpath.agent-icons`) with one `agent=icon` per
line. Keys are herdr's canonical agent ids. An empty icon keeps that agent's
name.

```ini
# icons.conf
claude=✳
codex=❁
gemini=
```

Any text works, including Nerd Font glyphs if your terminal font has them.

## Colors

Plugins only supply the icon text. Colors are sidebar rules in
`~/.config/herdr/config.toml`, matched against the icon:

```toml
[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  [{ token = "agent", rules = [
    { equals = "✺", fg = "#d97757" },
    { equals = ">_", fg = "#7b8cff" },
    { equals = "π", fg = "#cba6f7" },
    { equals = "𝕏", fg = "#ffffff" },
  ] }],
]
```

Then run `herdr server reload-config`.

## License

MIT
