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

## Codex cloud icon (optional)

`fonts/CodexIcon.ttf` is a one-glyph font with the Codex cloud-and-prompt icon
at U+F9000. Terminals can only draw text, so the icon needs this font:

1. Download and install the font:
   [CodexIcon.ttf](https://github.com/BlockedPath/herdr-agent-icons/raw/main/fonts/CodexIcon.ttf).
   - Linux: save it to `~/.local/share/fonts/` and run `fc-cache -f`.
   - macOS: save it to `~/Library/Fonts/`.
   - Windows (for WSL): download it in Windows, right-click the file and
     choose Install.

   On Linux, in one go:

   ```bash
   mkdir -p ~/.local/share/fonts && curl -fsSL -o ~/.local/share/fonts/CodexIcon.ttf https://github.com/BlockedPath/herdr-agent-icons/raw/main/fonts/CodexIcon.ttf && fc-cache -f
   ```

2. Make your terminal fall back to it. Many terminals pick up installed fonts
   on their own. Windows Terminal needs it listed in the profile's font face,
   for example `"face": "FiraCode Nerd Font, Codex Icon"`, and a full restart.
3. Point the plugin at the glyph and re-apply:

```bash
printf 'codex=\xf3\xb9\x80\x80\n' >> "$(herdr plugin config-dir blockedpath.agent-icons)/icons.conf"
herdr plugin action invoke blockedpath.agent-icons.apply
```

If you see an empty box, the terminal has not loaded the font. This has only
been tested in Windows Terminal with WSL. To color it, use
`{ equals = "\U000F9000", fg = "#7b8cff" }` in the rules below.

## Make your own icon

`tools/make-icon-font.py` traces any image into a one-glyph font, the same way
`CodexIcon.ttf` was made. Use a PNG with a white or transparent background;
the shape is everything that is opaque and not near-white. Fonts hold a single
color, so gradients become a flat shape that you tint with a color rule.

```bash
pip install fonttools numpy pillow potracer
python tools/make-icon-font.py icon.png MyIcon.ttf --family "My Icon" --codepoint F9001 --preview preview.png
```

- `--codepoint` is a private-use codepoint in hex. Give each icon its own,
  for example `F9001`, `F9002`, ... (`F9000` is the Codex cloud).
- `--sharp` keeps hard corners, for pixel art.
- `--preview` writes a PNG so you can check the trace before installing.

Then install `MyIcon.ttf` and add its family name to your terminal's fallback
fonts, as in the Codex steps above. The script prints the `printf` line that
adds the glyph to `icons.conf`; replace `AGENT` with the agent id.

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

MIT for the code. The glyph in `fonts/CodexIcon.ttf` is traced from OpenAI's
Codex app icon; that logo belongs to OpenAI and is not covered by the MIT
license.
