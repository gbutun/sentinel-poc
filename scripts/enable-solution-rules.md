# enable-solution-rules.sh

Creates or updates Microsoft Sentinel analytics rules from every analytics rule
template that belongs to a Content hub solution **already installed** in the
workspace. It installs nothing from the Content hub. It uses `az rest`, not Terraform.

## Requirements

- `bash`, not `sh`, because the script uses bash-only features
- `az` CLI, logged in to the right tenant (`az login --tenant <tenant-id>`)
- `jq`
- **Microsoft Sentinel Contributor** role on the workspace

## Run it

```bash
# Preview only: writes nothing to Azure, saves each request body to ./rule-bodies/<rule-id>.json
bash scripts/enable-solution-rules.sh <subscription-id> <resource-group> <workspace-name> --dry-run

# Apply
bash scripts/enable-solution-rules.sh <subscription-id> <resource-group> <workspace-name>
```

Each rule prints one line: `OK`, `FAILED` (with the reason), `SKIP` or `DRY-RUN`.
Other markers:

- `(KEEP-SCHEDULE …)`: the rule keeps its template's schedule (see below).
- `(own schedule …)`: Sentinel rejected the 5-minute schedule, and the retry with the template's own schedule succeeded.
- `WARN … rules come from the same template`: two or more rules were created from one template. All of them are tuned and none are deleted; remove the extra rules yourself if you don't want them.

The last line gives the totals: `created`, `updated`, `skipped` and `failed`.

## What it does

- **Which templates:** only analytics rule templates from installed Content hub solutions.
- **New rules:** for each template that has no rule yet, it creates one with the template's query.
- **Existing rules:** it keeps each rule's current query, including any manual fixes,
  and changes only the settings below.
- **Settings applied to every rule:**
  - Enabled
  - One alert per event (`AlertPerResult`)
  - All of a rule's alerts grouped into one incident over a 1-day window
  - Scheduled rules: run every 5 minutes, look back 47 hours, alert on any result,
    **where the rule accepts it** (see the next point)
  - NRT rules: only the grouping and alert settings, because they always run every minute
- **Rules that need a longer lookback:** if a template's own lookback is longer than 47 hours
  (for example the 7- and 14-day time-series templates), the rule keeps the template's frequency and
  lookback. Sentinel doesn't accept a 5-minute run with those lookbacks, and the queries need the full
  window. These rules still get one alert per event and incident grouping. If Sentinel rejects the
  5-minute schedule for any other rule, the script retries once with the template's own schedule.
- **Duplicates:** if two installed solutions contain the same template, only the highest version is used.
- **Other template types** (machine learning, Fusion, threat intelligence) are listed as `SKIP`.
- **Failures:** if a rule is rejected, for example because a table it needs doesn't
  exist in the workspace, the script prints the reason and continues.

## Reset to defaults

To undo the tuning and put the rules back to their template's default values:

```bash
bash scripts/enable-solution-rules.sh <subscription-id> <resource-group> <workspace-name> --reset --dry-run  # preview
bash scripts/enable-solution-rules.sh <subscription-id> <resource-group> <workspace-name> --reset            # apply
```

- **Which rules:** only rules linked to an installed solution template. Custom rules, Fusion and ML rules
  are not touched. Nothing is created or deleted; templates without a rule are listed as `SKIP no rule`.
- **What is restored from the template:** query (manual query changes are lost), frequency and lookback,
  trigger, severity, tactics and techniques, entity mappings, custom details, alert details, suppression
  and incident settings.
- **Where the template has no value, the portal defaults apply:** one alert per run (`SingleAlert`),
  an incident per alert with grouping turned off, and suppression turned off.
- The rules stay enabled.

## Settings

Change these at the top of the script:

| Variable | Default | Meaning |
|---|---|---|
| `QUERY_FREQUENCY` | `PT5M` | How often Scheduled rules run |
| `QUERY_PERIOD` | `PT47H` | How far back each run looks |
| `GROUP_LOOKBACK` | `P1D` | Window for grouping alerts into one incident (max `P7D`) |
| `GROUP_MATCHING` | `AnyAlert` | `AnyAlert` puts all of a rule's alerts in one incident |

**Why 47 hours and not 5 days:** Sentinel rejects a rule whose lookback is 2 days
or more unless it runs at most once an hour. A 5-minute run therefore allows a
lookback of at most 47 hours. For a 5-day lookback, set `QUERY_PERIOD="P5D"` and
`QUERY_FREQUENCY="PT1H"`.

## Before you use it

- **Expect a lot of alerts.** With a 47-hour lookback and a run every 5 minutes,
  every event is found again on each run, about 560 times, and each time it raises
  a new alert. Each rule can raise at most 150 alerts per run, and one incident
  holds at most 150 alerts; after that a new incident starts.
- **The Defender portal may regroup alerts.** If the workspace is connected to the
  Defender portal, the rule's grouping settings only apply when an incident is
  created, and the portal can then merge incidents on its own. To stop that for a
  rule, exclude it from correlation, for example by adding `#DONT_CORR#` at the
  start of its description.
- **Some rules will be less accurate.** Anomaly and time-series templates are
  designed for longer lookbacks, often 14 days, and at 47 hours they work less well.
