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
/workspaces/chromerdp-files/filename` in the Codespace terminal.

To upload a downloaded file to a website such as Telegram Web or Google Drive,
open that site in the Chromium desktop on port `6080` and use its normal attach
or upload button. In the file picker, open `/workspaces/chromerdp-files` and
select the file. If the picker has a location field, you can enter the full file
path there. The file must be present in that folder; downloads made on your own
computer are not automatically available in the Codespace browser.

Port `6081` is optional and only moves files between your PC and the Codespace;
it does not upload files to Telegram, Google Drive, or other websites. Transfers
are streamed and support files up to 1 GB, including files around 500 MB. Files
and the browser profile are stored in the Codespace workspace.

To start or check the services manually:

```sh
.devcontainer/start-chrome.sh
```
