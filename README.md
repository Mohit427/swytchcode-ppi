# Swytchcode GitHub issue reporter

A small PowerShell script that creates a GitHub issue through Swytchcode, built to learn the tool and record what a first-time user runs into.

## Problem and intended user

A developer wants to log a bug from the terminal without opening GitHub or handling API tokens in a script.

`report-bug.ps1` takes a title and description, previews the request, asks for confirmation, creates the issue, and prints its link. Swytchcode handles the GitHub login and sends the request.

## API and integration explored

- **Provider:** `GitHub.github@1.1.4`
- **Method:** `github.issue.create` (`POST /repos/{owner}/{repo}/issues`)
- **Authentication:** OAuth, through `swy auth connect github`
- **Workflows:** `swy list workflows` showed none installed

## Setup and commands

Requires the Swytchcode CLI (`npm install -g swytchcode`), a Swytchcode account, and a GitHub repo where you can create issues.

```powershell
swy init --mode sandbox --editor claude
swy search github
swy get github
swy list methods
swy add method github.issue.create
swy auth connect github
swy auth status
```

GitHub has no sandbox endpoint, so change this line in `.swytchcode/tooling.json` before making a call:

```json
"mode": "production",
```

Preview the request, then send it:

```powershell
swy exec github.issue.create --input owner=<owner> --input repo=<repo> --body issue.json --dry-run
swy exec github.issue.create --input owner=<owner> --input repo=<repo> --body issue.json
```

## What worked

- **Direct API call:** `swy exec` created [issue #1](https://github.com/Mohit427/swytchcode-ppi/issues/1).
- **Example script:** `report-bug.ps1` created [issue #2](https://github.com/Mohit427/swytchcode-ppi/issues/2) and printed its link.
- **Input check:** running the script without a title printed the usage line and made no API call.
- **Dry run:** the preview showed the request with the token replaced by `[REDACTED]`.

## What did not work and errors encountered

The full details are in [friction-diary.md](friction-diary.md).

| Problem | What happened | Outcome |
|---|---|---|
| MCP server not visible | Registering from my home folder made it available only there | Fixed by running `swy init` in the project |
| Init in the wrong folder | `swy init` ran in my home folder with no warning | Removed the five created items and re-ran it |
| Sandbox mode | The dry run targeted `https://base-url-not-set.invalid` because GitHub's sandbox endpoint is empty | Switched to `production` |
| Authorization page | The page appeared stuck for about 10 minutes, with nothing below "Please authorize the connection below." | Connected on a later attempt; cause unknown |
| Quickstart example | It uses `github.issues.create`, but the installed ID is `github.issue.create`, and the inputs differ | Used `swy info` and the Wrekenfile instead |
| Wrekenfile location | `swy get` created it, not `swy init` as the assignment describes | Found it under `.swytchcode/integrations/` |
| Telemetry warnings | `posthog` warnings appear after routine commands | Harmless so far, not fixed |

## How to reproduce

1. Complete the setup above.
2. Change `$swyArgs` in `report-bug.ps1` to use your own owner and repo.
3. Run the script and answer `y` once:

```powershell
powershell -ExecutionPolicy Bypass -File .\report-bug.ps1 -Title "Login button does nothing" -Description "Clicking Login on the home page has no effect."
```

This creates a real issue, so use a repo you own.

## Demo

[Watch the demo](ADD-DEMO-LINK-HERE)

## Notes on the generated Wrekenfile

File: `.swytchcode/integrations/GitHub/github/1.1.4/wrekenfile.yaml` (93,653 lines).

| Section | What it holds |
|---|---|
| `VERSION` | The Wrekenfile format version (`2.0.2`) |
| `DEFAULTS` | The base URL (`https://api.github.com`) |
| `METHODS` | Each API operation: HTTP method, path, inputs, responses, errors, and ID |
| `STRUCTS` | The data shapes those operations use |

For `github.issue.create`:

- **Inputs:** `owner` and `repo` go in the URL. `body` is required and must include `title`.
- **Access:** the description says anyone with pull access to a repo can create an issue. If issues are disabled, the API returns `410 Gone`.
- **Responses:** success returns `201` with the issue. Listed errors are `400`, `403`, `404`, `410`, `422` and `503`.
- **Response formats:** custom media types (`raw`, `text`, `html`, `full`) control how the issue's body text is returned.

Open questions:

- `manifest.json` reports 1204 methods, but `methods.json` has 1026 IDs. I don't know why.
- `manifest.json` retries on `429`, `503` and `504` with idempotency set to `none`. I haven't confirmed whether a retried create could produce a duplicate issue.

## Security

- My GitHub connection is stored outside this project, in `~/.swytchcode`.
- `.swytchcode/workspace.json` is excluded with `.gitignore`.
- No API keys or tokens are committed.

## AI usage

I used Claude Code (Opus 5.5) to explain commands, debug problems, inspect the Wrekenfile, and draft `report-bug.ps1` and this README. I ran the setup commands and API calls myself, and Claude ran some read-only checks such as listing methods and inspecting files. Exact prompts and whether each answer worked are in the AI usage log in [friction-diary.md](friction-diary.md).
