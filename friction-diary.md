# Swytchcode Friction Diary

Author: A Mohit Kumar
Started: 2026-11-03
Environment: Windows, PowerShell, Swytchcode CLI installed via npm (global)

Each entry: step attempting, command/action, expected, actual (exact output, secrets redacted), what I tried next, resolved?

---

## Setup log

- [x] Installed the Swytchcode CLI (`swy` works in PowerShell)
- [x] Initialized a project (`SwytPPI`, sandbox mode, second attempt; see Friction #7)
- [x] Inspected the Wrekenfile
- [x] Executed one API operation (`github.issue.create`, created Mohit427/swytchcode-ppi#1)
- [x] Built the small example (`report-bug.ps1`, created Mohit427/swytchcode-ppi#2)
- [x] Created a new Wrekenfile for my own API (`scam-investigator`)
- [ ] Ran `check-scam.ps1` against the live API
- [ ] Wrote the 150-250 word explanation
- [ ] Created the marketing asset
- [x] README and GitHub repository (demo link still to add)
- [ ] Demo video (3 minutes max)
- [ ] Submitted the Google Form

---

## Friction #1: Alarming warnings after `swy mcp serve --claude`

**Step attempting:** Connecting Swytchcode to Claude Code right after install.

**Command:**

```
PS C:\Users\Mohit> swy mcp serve --claude
```

**Expected:** A server to start (the command says "serve"), or a clean success message.

**Actual:**

```
Registering Swytchcode with Claude Code...
Added stdio MCP server swytchcode with command: C:\Users\Mohit\AppData\Roaming\npm\node_modules\swytchcode\node_modules\swytchcode-cli-win32-x64\bin\swytchcode.exe mcp serve --profile agent to local config
File modified: C:\Users\Mohit\.claude.json [project: C:/Users/Mohit]

Successfully registered Swytchcode MCP server with Claude Code.
Claude will now automatically start the server when needed.
posthog 2026/11/03 07:43:13 WARN: shutdown timeout exceeded, some messages may be lost
posthog 2026/11/03 07:43:13 WARN: shutdown timeout: 1 batches still in flight
posthog 2026/11/03 07:43:13 WARN: sending request - Post "https://us.i.posthog.com/batch/": context canceled
```

**First reaction:** The WARN lines made it look like a failure, even though "Successfully registered" appeared above them.

**What I tried next:**

- Asked Claude to explain the output. Answer: the command only registers an MCP server entry in `.claude.json` and exits; the `posthog` lines are the CLI's analytics client failing to send a usage event on exit, unrelated to the registration. The explanation worked.
- Docs page/heading followed: docs.swytchcode.com Initialize Swytchcode for your editor

**Resolved?** Understood, not an error. Checked afterwards: the server does not show up from `SwytPPI` (see Friction #2).

**Feedback for Swytchcode:**

1. Telemetry warnings print right after a success message, so a new user can't tell harmless from fatal. Suppress them by default or flush before printing success.
2. `mcp serve --claude` sounds like it starts a server but only registers one. A name like `mcp install` or a one-line note would help.
3. The output says the scope is project `C:/Users/Mohit` (my home folder) but doesn't explain that other folders may not see the server.
4. The docs do cover telemetry and the opt-out: docs.swytchcode.com/cli/telemetry/ gives `swy config telemetry disable`. See Friction #3 for the unclear default.

---

## Friction #2: MCP server not visible from my project folder

**Step attempting:** Checking that the Swytchcode MCP server loads in Claude Code from `C:\Users\Mohit\Development\SwytPPI`.

**Command / action:** `claude mcp list`, run from `SwytPPI`.

**Expected:** `swytchcode` in the list, because registration said "Claude will now automatically start the server when needed."

**Actual:** `swytchcode` was not listed. The entry exists in `C:\Users\Mohit\.claude.json`, but only under the project `C:/Users/Mohit`, because `swy mcp serve --claude` registered it with local scope from my home folder.

**What I tried next:**

- Asked Claude to find the server (prompt in the AI usage log). It searched the config files and found the scope problem.
- Claude started the same binary directly and sent an MCP `tools/list` request. The server responded with 7 tools: `swytchcode_add`, `swytchcode_discover`, `swytchcode_exec`, `swytchcode_info`, `swytchcode_list`, `swytchcode_policy`, `swytchcode_search`. Stderr: `MCP server started (profile: agent - 7 tools)`.

**Resolved?** Yes. Running `swy init --mode sandbox --editor claude` in `SwytPPI` registered the server for this folder (`File modified: C:\Users\Mohit\.claude.json [project: C:/Users/Mohit/Development/SwytPPI]`), and `claude mcp list` now shows `swytchcode ... ✔ Connected`.

**Feedback for Swytchcode:** Say during registration that the server only applies to the current folder, and warn when that folder is the home directory.

---

## Friction #3: Telemetry default is unclear

**Step attempting:** Finding out whether the `posthog` warnings could be turned off.

**Command / action:** `swy config --help`, then `swy config telemetry status`. Docs page: docs.swytchcode.com/cli/telemetry/

**Expected:** Help text and status to agree.

**Actual:** Help says `telemetry_enabled   true|false   Share anonymous usage data (default: false)`, but status says `Telemetry: enabled`. I don't know whether I opted in at some point. The docs page does not state the default.

**What I tried next:** Read the telemetry docs page. The opt-out is `swy config telemetry disable`.

**Resolved?** Partly. The opt-out is known, but why it was enabled is not.

**Feedback for Swytchcode:** State the default in the docs, and show in `status` how the setting came to be enabled.

---

## Friction #4: `posthog` warnings on routine commands

**Step attempting:** Running basic read-only commands.

**Command / action:** `swy whoami`, `swy auth status`, `swy config telemetry status`, `swy demo list`, `swy examples list`

**Expected:** Clean output.

**Actual:** Each command ended with lines like these:

```
posthog 2026/11/03 07:57:25 WARN: shutdown timeout exceeded, some messages may be lost
posthog 2026/11/03 07:57:25 WARN: sending request - Post "https://us.i.posthog.com/batch/": context canceled
posthog 2026/11/03 07:57:25 ERROR: 1 messages dropped: shutdown timeout
posthog 2026/11/03 07:57:25 WARN: shutdown timeout: 1 batches still in flight
```

**What I tried next:** Compared the commands. The warnings were not limited to registration (Friction #1), and the commands still returned their results.

**Resolved?** Harmless so far, but not fixed. Not yet tested whether disabling telemetry removes them.

**Feedback for Swytchcode:** Don't show an `ERROR` line for a dropped analytics event, because it looks like the command failed.

---

## Friction #5: Sandbox mode is barely explained

**Step attempting:** Choosing a mode before running `swy init`.

**Command / action:** `swy init --help`. Docs page: docs.swytchcode.com/cli/projects/

**Expected:** An explanation of what changes between the modes, especially whether sandbox calls can affect real data.

**Actual:** Help only lists `--mode string   production | sandbox`. The docs say `sandbox` for development/testing, `production` for live execution, and don't describe any other difference.

**What I tried next:** Checked the projects page, CLI authentication page, CLI quickstart and docs index (`llms.txt`). None explain it further.

**Update after `swy get github`:** `.swytchcode/integrations/manifest.json` shows `"sandbox_endpoint": ""` and `"production_endpoint": "https://api.github.com"` for GitHub. `skills.md` says the mode selects the endpoint from this file, so GitHub has no sandbox endpoint and `swy init` gave no warning about it. Not yet tested: what `sandbox` mode does when it runs a call.

**Update after the first dry run:** Sandbox mode could not target GitHub. Command: `swy exec github.issue.create --input owner=Mohit427 --input repo=swytchcode-ppi --body issue.json --dry-run`. Output:

```
⚠ base URL for GitHub.github@1.1.4 (sandbox) is not set: "" (it is empty) - previewing with https://base-url-not-set.invalid; this provider runs on your own instance - set sandbox_endpoint for "GitHub.github@1.1.4" in .swytchcode/integrations/manifest.json, or set SWYTCHCODE_BASE_URL_GITHUB_GITHUB_SANDBOX
{"body":{"body":"Created through Swytchcode for the PPI assignment.","title":"Swytchcode test issue"},"headers":{"Authorization":"[REDACTED]","Content-Type":"application/json"},"method":"POST","url":"https://base-url-not-set.invalid/repos/Mohit427/swytchcode-ppi/issues"}
```

The warning says "this provider runs on your own instance", which is confusing for GitHub because `manifest.json` already lists `https://api.github.com` as its production endpoint. The dry run did show useful behaviour: it redacted the `Authorization` header and built the correct path and body.

**Resolved?** Yes. GitHub has no sandbox endpoint, so I changed `"mode"` to `"production"` in `.swytchcode/tooling.json`, re-ran the dry run, then ran the real call. It created issue Mohit427/swytchcode-ppi#1, which I confirmed on GitHub. There was no separate safe test environment, so I used my own new repo as the target.

**Feedback for Swytchcode:** Explain what sandbox changes for each provider, including whether a call can modify real data. Warn at `swy get` when the selected mode has no endpoint for that provider, rather than at the first `exec`, and make the warning suggest switching to `production` when a production endpoint exists.

---

## Friction #6: Wrekenfile is hard to find in the docs

**Step attempting:** Preparing to inspect the Wrekenfile before initializing.

**Command / action:** `swy get --help`, then a search of docs.swytchcode.com/llms.txt

**Expected:** A docs page explaining what a Wrekenfile is and where to find it.

**Actual:** `swy get --help` says `Fetch Wrekenfile bundles for a provider`, but the docs index has no Wrekenfile page, and the projects and CLI quickstart pages don't mention it. The docs say `init` writes `tooling.json` and an integrations folder, while the assignment says the Wrekenfile is generated during initialization.

**What I tried next:** Ran `swy init` (see Friction #7). It created `tooling.json`, `CLAUDE.md`, `skills.md` and an empty `integrations` folder, but no Wrekenfile. `swy doctor` reports `manifest.json missing (expected after first 'swytchcode get')`. `swy get github` then created `.swytchcode/integrations/GitHub/github/1.1.4/wrekenfile.yaml` (3,218,050 bytes, 93,653 lines), `methods.json` and `manifest.json`. `swy list workflows` printed only `Workflows:`, so no workflows are installed locally. `manifest.json` says `"methods": 1204`, but `methods.json` has 1026 canonical IDs, and I don't know why they differ.

**Resolved?** Yes for where it is: `swy get` creates the Wrekenfile, not `swy init` as the assignment describes. There is still no docs page explaining it.

**Feedback for Swytchcode:** Add a Wrekenfile page covering its purpose, location and structure, and have `swy get` print the path of the file it created. The onboarding brief should also say the file appears after `swy get`.

---

## Friction #7: `swy init` ran in my home folder without any warning

**Step attempting:** Initializing the project.

**Command / action:**

```
PS C:\Users\Mohit> swy init --mode sandbox --editor claude
```

**Expected:** I meant to initialize `SwytPPI` but was still in my home folder. I expected a warning, or at least a clean result. My AI-generated hourly plan left out the `cd` step.

**Actual:**

```
MCP server swytchcode already exists in local config
⚠ could not register MCP server with Claude Code - configure it manually if needed
› initialized project at C:\Users\Mohit
```

`swy doctor` then reported `All checks passed (no errors).`, alongside warnings for missing providers, no network permission boundaries and a missing `manifest.json`.

Init created `~/CLAUDE.md`, `~/skills.md`, `~/.swytchcode/tooling.json`, `~/.swytchcode/tooling.json.lock` and `~/.swytchcode/integrations/`. The same `~/.swytchcode` folder already held my login and credentials (`auth.json`, `credentials.db`, `config.json`), so global and project files ended up mixed together.

**What I tried next:** Pasted the output into Claude, which spotted the wrong folder and checked file creation times to identify exactly what init had created.

**Resolved?** Yes. I removed only the five items init created in my home folder, then re-ran init from `SwytPPI`. It printed `initialized project at C:\Users\Mohit\Development\SwytPPI` with no registration warning, and my login files were untouched.

**Feedback for Swytchcode:**

1. Warn or ask for confirmation when `init` runs in the home directory.
2. Undoing this is risky, because deleting `~/.swytchcode` would also remove my login and credentials. An undo command or separate folders for global and project files would help.
3. "Configure it manually if needed" should give the actual command, and "already exists" shouldn't read as a failure.

---

## Friction #8: CLI quickstart example doesn't match the GitHub contract

**Step attempting:** Finding the method and inputs for creating a GitHub issue.

**Command / action:** Compared docs.swytchcode.com/quickstarts/getting-started/cli-only/ with `swy list methods`, `swy info github.issue.create` and the Wrekenfile.

**Expected:** The quickstart's `github.issues.create` example to work as written.

**Actual:** The installed ID is `github.issue.create` (singular). `github.issues.create` has 0 matches in `methods.json`. The quickstart passes `--input repo=my-org/my-repo --input title="Login page bug"`, but the contract requires separate `owner` and `repo` path inputs, plus a `body` object containing `title`.

**What I tried next:** Used `swy info` and the Wrekenfile for the real contract. I have not run the quickstart's command, so I haven't seen the error it gives.

**Resolved?** Yes, by using the contract instead of the quickstart example.

**Feedback for Swytchcode:** Update the quickstart to the current ID and inputs, or tell readers to get both from `swy info` first.

---

## Friction #9: GitHub authorization page appeared stuck

**Step attempting:** Connecting my GitHub account to Swytchcode.

**Command / action:** `swy auth connect github`, then selecting `2` at `Select a library to connect: 1) <all> 2) <github>`.

**Expected:** A browser page leading straight to a GitHub approval screen.

**Actual:** The terminal waited for about 10 minutes, and `swy auth status` still said `No connected accounts`. The browser page at auth.swytchcode.com showed "Select auth providers", a "Connection source" dropdown set to "Default Swytchcode", and "Please authorize the connection below.", with nothing below it while the tab kept loading. The other dropdown option, "Create a new connection", asks for a label for "your own OAuth apps". The logo was a broken image.

**What I tried next:**

- Asked Claude (prompts in the AI usage log). It suggested the dropdown, an Incognito window, another browser, and the console.
- Opened the dropdown and saw "Create a new connection", which Claude advised against.
- Ran `swy auth connect github --library github --json` and opened the link. The page only partially loaded.
- Tried the browser login again with `swy auth connect github`. This time it showed a connect option, and I went through the normal GitHub sign-in, including email, until it connected.

**Resolved?** Yes. The terminal later printed `Connected github (oauth2).` I don't know what caused the delay or why the second browser attempt worked. I didn't record which permissions GitHub requested.

**Feedback for Swytchcode:**

1. Show a clear state and action on this page, such as "Waiting for GitHub" with a button or a timeout message.
2. Explain "Connection source" and recommend an option for first-time users.
3. Skip the library prompt, or preselect the option, when only one library is installed.
4. Have the CLI print the link and a timeout message rather than waiting silently.
5. Fix the broken logo.

---

## Friction #10: Method ID doesn't say what it does

**Step attempting:** Finding the operation that lists a repo's open issues for `triage.ps1`.

**Command / action:** Searched the Wrekenfile for the summary "List repository issues", then ran `swy exec github.issue.get1 --input owner=Mohit427 --input repo=swytchcode-ppi --json`.

**Expected:** An ID like `github.issue.list`.

**Actual:** The ID is `github.issue.get1`. The output also printed `🔐 Running live - GitHub (production)`, even though this call only reads data.

**What I tried next:** Claude matched the summary to the ID in the Wrekenfile. The call worked and returned the issues in a `data` list.

**Resolved?** Yes, by searching on the summary instead of the ID.

**Feedback for Swytchcode:** Use descriptive IDs such as `github.issue.list`, because numeric suffixes make an ID hard to guess or review. Show in the live message whether a call reads or changes data.

**What worked well:** A call to a nonexistent repo returned a clear structured error with `"error_category":"not_found"`, `"retryable":false` and a `suggested_action`, which is useful for scripts and agents.

---

## Friction #11: Closed issue still appeared in the next list

**Step attempting:** Closing issue #1 with `triage.ps1`.

**Command / action:** `powershell -ExecutionPolicy Bypass -File .\triage.ps1`, then choosing `x` on #1. The script closed it through `github.issue.update` and immediately listed issues again through `github.issue.get1`.

**Expected:** #1 to disappear from the list.

**Actual:** The script printed `Closed: https://github.com/Mohit427/swytchcode-ppi/issues/1`, but the next list still showed `#1    Swytchcode test issue`.

**What I tried next:** Claude checked GitHub with `gh issue view 1`. It showed `CLOSED`, closed at 10:51:53 local time with both comments, and a listing about 30 seconds later showed only #2.

**Resolved?** Yes for my tool: `triage.ps1` now hides issues it closed during the same run. I don't know whether the delay came from GitHub or Swytchcode. The request used `state=open`, so the delay looks like a short-lived stale result rather than a wrong filter.

**Lesson:** A successful write doesn't guarantee that an immediate read shows the change. Tools and agents should check the write's own response or allow for a delay.

---

## Friction #12: No documented way to add my own API

**Step attempting:** Calling my own project's API (`POST /api/investigate` on scam-investigator) through Swytchcode.

**Command / action:** Searched docs.swytchcode.com/llms.txt, docs.swytchcode.com/cli/integrations/, docs.swytchcode.com/reference/commands/ and docs.swytchcode.com/configuration/manifest-json/. Then Claude hand-wrote `.swytchcode/integrations/ScamInvestigator/api/1.0.0/wrekenfile.yaml`, `methods.json` and a `manifest.json` entry, using the GitHub bundle as the pattern.

**Expected:** A documented command to add a custom API, or to import its OpenAPI spec.

**Actual:** I found no docs for creating a provider or Wrekenfile. The hand-written bundle did work with `swy add provider`, `swy list`, `swy add method`, `swy info` and `swy doctor`, but three problems appeared.

**1. An API with no login**

```
{"error":"unsupported manifest auth type \"none\" for ScamInvestigator.api@1.0.0 - upgrade the CLI to the latest version or re-fetch the provider","category":"auth",...}
```

The message suggests upgrading, which doesn't help. Fix: leave `auth` out of the manifest entry.

**2. A slow API**

The first real call failed after 31 seconds with:

```
{"error":"Failed to complete execution.","category":"internal","suggested_action":"run: swytchcode doctor to diagnose the issue",...}
```

`swy doctor` is not what would reveal this. The time matches the 30-second `http_timeout_ms` in the GitHub manifest, so I suspected a timeout. Fix: raise the limits in `execution_policy`. The next run lasted 52 seconds and failed differently (below), although I can't say for certain that the first failure was a timeout.

**3. A streaming API**

```
{"error":"response is not valid JSON: data: {\"type\": \"step\", ...
```

The API had already returned its results. Fix: use `swy exec ... --raw`, which returns the stream as text in a `body` field, with `status_code` alongside it.

**What I tried next:** Claude tested each fix in a throwaway folder. This took three real investigations. The third returned `likely_scam` at 0.6 confidence.

**Resolved?** Yes, with undocumented workarounds. I don't know whether `swy get` or `swy sync` keep a hand-written provider. Calling it through the MCP server is untested.

**Also seen:** `swy init --non-interactive --mode production --editor none`, run inside a script in an empty folder, produced no result for over 2 minutes and created no files. I didn't investigate it and wrote the project files directly instead.

**Feedback for Swytchcode:**

1. Document how to create a provider, or add a command that generates one from an OpenAPI spec. My API already publishes `/openapi.json`.
2. Accept an explicit `"type": "none"` for public APIs, and fix the "upgrade the CLI" message.
3. Report timeouts as timeouts, not as a generic internal error.
4. Support `text/event-stream` responses in normal and `--json` mode, or suggest `--raw` in the error.

---


## AI usage log

| Tool   | What I asked                                                 | Worked?                        |
| ------ | ------------------------------------------------------------ | ------------------------------ |
| Claude | Assignment approach; explain `swy mcp serve --claude` output | Yes for the explanation. The server did not load from `SwytPPI` (Friction #2) |
| Claude Code (Opus 5.5) | "Connect GitHub and show me the tools available from the Swytchcode MCP server." | Partly. It listed the 7 tools and found the scope problem. It did not connect GitHub, because that needs `swy init` and my browser approval. It also suggested a `swy add provider` step the quickstart doesn't use |
| Claude Code (Opus 5.5) | "What is sandbox, what are we trying to do here, what is swytchcode, what are we trying to accomplish here, read this as well @friction-diary.md and gimme a proper action plan" | Partly. The Swytchcode explanation and plan were useful. It corrected its earlier claim that sandbox is "safer", which the docs don't support. It had to guess the goal because I pointed it at the wrong file |
| Claude Code (Opus 5.5) | "[expletive] sorry read @Swytchcode_PPI.pdf not friction diary" | Yes. It read the brief and reduced the plan's scope, including dropping the agent idea. PDF rendering failed, so it extracted the text with `pdftotext` |
| Claude Code (Opus 5.5) | "No Wait, Imma do it all today itself, it asks for only 2 to 3 hours of efforts right? I'll give it that today, devise an hourwise plan, Tell me what we are doing at each hour elaborately, and update the diary with changes" | Yes. It produced a 3-hour plan and updated this diary. The hourly table left out `cd` to the project folder, which contributed to Friction #7 |
| Claude Code (Opus 5.5) | Pasted my terminal output from `swy whoami`, `swy doctor` and `swy init` | Yes. It spotted that init ran in my home folder and identified which files were safe to remove |
| Claude Code (Opus 5.5) | Pasted my terminal output from the second `swy init`, `swy doctor`, `Get-ChildItem -Force` and `claude mcp list` | Yes. It confirmed the project and MCP connection were correct and checked that the cleanup had worked |
| Claude Code (Opus 5.5) | Pasted my `.swytchcode` file listing after `swy get github` | Yes. It found the Wrekenfile, mapped its structure, and found the correct method ID, the required inputs and the empty sandbox endpoint |
| Claude Code (Opus 5.5) | "Auth has been loading for 10 damn minutes", then "No progress" with a screenshot, then a screenshot of the dropdown | Partly. It correctly advised against "Create a new connection" and gave fallback steps. Its theory about a blocked page was unconfirmed, and the actual cause is still unknown |
| Claude Code (Opus 5.5) | Pasted my dry-run output| Yes. It confirmed the token was redacted, explained the sandbox endpoint problem, and suggested switching to `production`. That worked: the issue was created |
| Claude Code (Opus 5.5) | "save the script as report-bug.ps1 for me"  | Yes. The missing-title check printed the usage line, and a real run created issue #2 and printed its link |
| Claude Code (Opus 5.5) | Shared my account of how GitHub connected and my understanding of `github.issue.create` | Yes. It corrected my understanding of the response formats and drafted the README for me to edit |
| Claude Code (Opus 5.5) | "Can we create one more tool using SwytchCode, like a triage of tools, using the same Github Issue Workplace" | Yes. It proposed and wrote `triage.ps1` and tested listing and the error path. I tested commenting and closing, which worked. Claude then spotted a closed issue still listed in my output, confirmed the close on GitHub, and changed the script (Friction #11) |
| Claude Code (Opus 5.5) | "Explain to me what the triage.ps1 does, and explain the syntax of the powershell script as well," | Yes. It explained the script section by section |
| Claude Code (Opus 5.5) | "Okay, now can I connect it to any of my existing projects, and then showcase it, | Partly. It first suggested tracking the project's GitHub issues, which wasn't what I wanted |
| Claude Code (Opus 5.5) | "use scam-investigator, but why are you trying to include Github to it, Can I use this project alone, like use its API endpoints to somehow connect swytchcode?" | Yes. It tested a hand-written provider against my live API and found three workarounds (Friction #12). This used three real investigations |
| Claude Code (Opus 5.5) | "yes, go ahead, We are not extending a WrekenFile we are creating a new one right? So Can you explain what a WrekenFile is and the process of creating one for a custom proect and how it differs from an existing one such as Github" | Yes. It added the provider to this project, wrote `check-scam.ps1` and explained Wrekenfiles. It also found that double quotes in a message were lost when running through a nested `powershell -File` |
