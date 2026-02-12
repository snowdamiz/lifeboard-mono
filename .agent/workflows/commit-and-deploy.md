---
description: How to commit, push changes, and monitor production deployment
---

# Commit, Push, and Monitor Deployment

// turbo-all

## Pre-Commit Checks

1. Run TypeScript type checking on the client:
```bash
cd client && npx vue-tsc --noEmit
```

2. Run Elixir compilation on the server:
```bash
cd server && mix compile --warnings-as-errors
```

3. If either fails, fix errors before committing.

## Stage and Commit

4. Check what files have changed:
```bash
git status --porcelain | Out-File -Encoding utf8 .agent/git_status.txt
```
Then review the output file to see all modified/new files.

5. Stage the relevant files (exclude temp files, debug outputs, test scripts):
```bash
git add <list of relevant files and directories>
```

**Commit message format** (conventional commits):
```
<type>: <short summary>

<body with bullet points explaining each change>
```

Types:
- `fix:` — bug fixes
- `feat:` — new features
- `refactor:` — code restructuring without behavior change
- `docs:` — documentation only
- `chore:` — maintenance tasks

Body should list each file changed and what was done, grouped by logical change.

6. Commit:
```bash
git commit -m "<commit message>"
```

## Push

7. Push to master:
```bash
git push
```

## Monitor Deployment

The GitHub Actions workflow (`deploy.yml`) deploys both **server** and **client** to Fly.io on push to master.

8. Check the latest deployment run status via the GitHub API:
```
https://api.github.com/repos/snowdamiz/lifeboard-mono/actions/runs?per_page=1
```

Look for:
- `status`: `"in_progress"` → still building
- `status`: `"completed"`, `conclusion`: `"success"` → deployed successfully
- `status`: `"completed"`, `conclusion`: `"failure"` → build failed

9. Check individual job status:
```
https://api.github.com/repos/snowdamiz/lifeboard-mono/actions/runs/<RUN_ID>/jobs
```

There are two jobs:
- **Deploy Server** — Elixir/Phoenix backend to Fly.io
- **Deploy Client** — Vue/Vite frontend to Fly.io

Each job has steps; the critical one is `"Run flyctl deploy --remote-only"`.

10. If a job fails, check the job logs at:
```
https://github.com/snowdamiz/lifeboard-mono/actions/runs/<RUN_ID>/job/<JOB_ID>
```

## Typical Timelines

| Job | Typical Duration |
|-----|-----------------|
| Deploy Server | 2-4 minutes (Elixir Docker build + release) |
| Deploy Client | 1-2 minutes (Vite build + Nginx Docker) |

## Troubleshooting Failed Deployments

- **Server compilation failure**: Check that `mix compile --warnings-as-errors` passes locally
- **Client build failure**: Check that `npx vue-tsc --noEmit` passes locally
- **Fly.io timeout**: Check Fly.io dashboard at https://fly.io/apps
- **Previous deploy still running**: Fly.io queues deploys; wait for the previous one to complete
