# Interactive Chromium in GitHub Codespaces

This Codespace starts Chromium with a desktop session, a browser-based viewer,
and a private file-transfer page. You can search the web, visit sites, install
and use browser extensions, and move files between your computer and the browser.

## Use it

Open this repository in a GitHub Codespace. The devcontainer installs Chromium
and starts the services automatically. Open the **Ports** tab and use:

| Port | Purpose |
| --- | --- |
| `6080` | Interactive Chromium desktop (`/vnc.html?autoconnect=true&resize=remote&path=websockify`) |
| `6081` | Upload files from your computer and download files from the Codespace |
| `9222` | Chrome DevTools Protocol (CDP) |

All forwarded ports are configured as **private**. Keep them private: the CDP
endpoint allows browser control and has no built-in authentication.

Browser downloads are saved directly on the Codespace server under
`/workspaces/chromerdp-files`; they do not need to pass through your PC. To fetch
a file from a URL, open that URL in Chromium, or run `curl -L 'URL' -o
/workspaces/chromerdp-files/filename` in the Codespace terminal. Then open
YouTube in the Codespace browser, choose **Upload videos**, and select the file
from `/workspaces/chromerdp-files` in the file picker. If needed, use the
file-picker location field to enter that full path.

Port `6081` is optional: use its private page only when you want to move a file
between your PC and the Codespace. Transfers are streamed and support files up
to 1 GB, including files around 500 MB. Files and the browser profile are stored
in the Codespace workspace.

To start or check the services manually:

```sh
.devcontainer/start-chrome.sh
```
