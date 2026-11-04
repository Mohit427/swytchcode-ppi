# Swytchcode custom API and GitHub tools

PowerShell tools built to learn Swytchcode and record what a first-time user runs into. The main one, `check-scam.ps1`, calls my own [Scam Investigator](https://github.com/Mohit427/scam-investigator) API through a Wrekenfile I created for it. Two others create and triage GitHub issues through Swytchcode's GitHub provider.

## Problem and intended user

A developer wants to log a bug from the terminal without opening GitHub or handling API tokens in a script.

- **`check-scam.ps1`** sends a suspicious message to Scam Investigator and prints the verdict, reasons, advice and evidence. It's for someone who wants to check a message from the terminal, or a developer who wants to call this API without writing HTTP code.
- **`report-bug.ps1`** takes a title and description, previews the request, asks for confirmation, creates the issue, and prints its link.
- **`triage.ps1`** lists open issues and lets you comment on one, or post a reason and close it. It previews every change and asks for confirmation first.

Swytchcode handles the GitHub login and sends the requests. These are scripts rather than AI agents. `triage.ps1` shows only the first 30 open issues.

## API and integration explored

- **Provider:** `GitHub.github@1.1.4`
- **Methods:**
  - `github.issue.create`: `POST /repos/{owner}/{repo}/issues`
  - `github.issue.get1`: `GET /repos/{owner}/{repo}/issues`
  - `github.issue.comments.create`: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`
  - `github.issue.update`: `PATCH /repos/{owner}/{repo}/issues/{issue_number}`
- **Authentication:** OAuth, through `swy auth connect github`
- **Workflows:** `swy list workflows` showed none installed

## Custom provider: Scam Investigator

Swytchcode's docs don't describe creating a provider, so I worked this out by using the downloaded GitHub bundle as a pattern. It's an undocumented workaround, not an official feature.

| File | Purpose |
|---|---|
| `.swytchcode/integrations/ScamInvestigator/api/1.0.0/wrekenfile.yaml` | Describes the two operations: `GET /health` and `POST /api/investigate` |
| `.swytchcode/integrations/ScamInvestigator/api/1.0.0/methods.json` | Lists the operation IDs for `swy list methods` |
| `.swytchcode/integrations/manifest.json` | Sets the base URL, timeouts and response size limit |

To register it after those files exist:

```powershell
swy add provider ScamInvestigator.api@1.0.0
swy add method scaminvestigator.health.get
swy add method scaminvestigator.investigate.create
```

It needed three workarounds:

| Problem | Fix |
|---|---|
| `"auth": {"type": "none"}` is rejected | Leave `auth` out, because the API is public |
| An investigation takes about a minute | Raise `http_timeout_ms` and `total_timeout_ms`, and set `max_retries` to `0` |
| The streaming response fails with `response is not valid JSON` | Use `swy exec --raw` and read the `data:` lines from `body` |

No `swy auth connect` step is needed for this provider.

## Setup and commands

Requires the Swytchcode CLI (`npm install -g swytchcode`), a Swytchcode account, and a GitHub repo where you can create issues.

```powershell
swy init --mode sandbox --editor claude
swy search github
swy get github
swy list methods
swy add method github.issue.create
swy add method github.issue.get1
swy add method github.issue.comments.create
swy add method github.issue.update
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

- **Custom API call:** `swy exec scaminvestigator.investigate.create --raw` returned a `likely_scam` verdict from my live API.
- **Two providers together:** the GitHub provider and my hand-written provider both work in this project.
- **Direct API call:** `swy exec` created [issue #1](https://github.com/Mohit427/swytchcode-ppi/issues/1).
- **Example script:** `report-bug.ps1` created [issue #2](https://github.com/Mohit427/swytchcode-ppi/issues/2) and printed its link.
- **Input check:** running the script without a title printed the usage line and made no API call.
- **Dry run:** the preview showed the request with the token replaced by `[REDACTED]`.
- **Triage script:** `triage.ps1` commented on and closed [issue #1](https://github.com/Mohit427/swytchcode-ppi/issues/1), confirmed with `gh issue view`.
- **Error handling:** a call to a nonexistent repo returned a clear `404` with `error_category`, `retryable` and `suggested_action` fields.

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
| Unclear method ID | Listing issues uses `github.issue.get1`, not a name like `list` | Found it by searching the Wrekenfile summaries |
| No docs for a custom API | I found no documented way to create a provider or Wrekenfile | Hand-wrote one with three workarounds (see above) |
| Stale list after closing | A closed issue still appeared in the next list, about 2 seconds later | Confirmed closed on GitHub; `triage.ps1` now hides issues it closed in that run. Cause unknown |

## How to reproduce

### Custom API

This repo already includes the provider files. Allow scripts for this PowerShell window, then run the tool. Use single quotes around the message so any double quotes inside it are kept:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\check-scam.ps1 -Message 'Your bank account will be blocked today. Share the OTP you received to keep it active.'
```

Add `-DryRun` to preview the request without sending it. Each real run uses the live app's API quota.

### GitHub tools

1. Complete the setup above.
2. Change `$swyArgs` in `report-bug.ps1` to use your own owner and repo.
3. Run the script and answer `y` once:

```powershell
powershell -ExecutionPolicy Bypass -File .\report-bug.ps1 -Title "Login button does nothing" -Description "Clicking Login on the home page has no effect."
```

This creates a real issue, so use a repo you own.

4. Run the triage tool on your own repo. Comments and closes are real, but each one asks for confirmation first:

```powershell
powershell -ExecutionPolicy Bypass -File .\triage.ps1 -Owner <owner> -Repo <repo>
```

To only list open issues, add `-ListOnly`.

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

I used Claude Code (Opus 5.5) to explain commands, debug problems, inspect the Wrekenfile, and draft `report-bug.ps1`, `triage.ps1`, `check-scam.ps1`, the custom Wrekenfile and this README. Claude also tested the custom provider against my live API. I ran the setup commands and API calls myself, and Claude ran some read-only checks such as listing methods and inspecting files. Exact prompts and whether each answer worked are in the AI usage log in [friction-diary.md](friction-diary.md).
