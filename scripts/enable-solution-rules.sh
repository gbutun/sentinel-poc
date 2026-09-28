#!/usr/bin/env bash
# Create or update Microsoft Sentinel analytics rules from every analytics rule
# template that belongs to an ALREADY INSTALLED Content hub solution.
# Installs nothing from the Content hub.
#
# Usage: ./enable-solution-rules.sh <subscription-id> <resource-group> <workspace-name> [--dry-run] [--reset]
# Needs: az (logged in to the right tenant), jq, Microsoft Sentinel Contributor on the workspace.
# --dry-run writes nothing to Azure; it saves every request body to ./rule-bodies/<rule-id>.json.
# --reset   puts every rule linked to an installed solution template back to the template's
#           default values (query, schedule, alert and incident settings). Creates nothing.
set -euo pipefail

SUB="${1:?subscription id}"; RG="${2:?resource group}"; WS="${3:?workspace name}"
DRY_RUN=false; RESET=false
for opt in "${@:4}"; do
  case "$opt" in
    --dry-run) DRY_RUN=true ;;
    --reset)   RESET=true ;;
    *) echo "Unknown option: $opt" >&2; exit 1 ;;
  esac
done

# ---------------- settings ----------------
QUERY_FREQUENCY="PT5M"   # Run query every 5 minutes
QUERY_PERIOD="PT47H"     # Look back 47 h (a lookback >= 2 days requires a frequency >= 1 h)
GROUP_LOOKBACK="P1D"     # Group alerts that arrive within this window (max P7D)
GROUP_MATCHING="AnyAlert" # AnyAlert = all alerts of a rule go into one incident
BODY_DIR="./rule-bodies" # Where --dry-run saves the request bodies
# ------------------------------------------
# Templates whose own lookback is longer than QUERY_PERIOD (e.g. 7- or 14-day
# time-series rules) keep their own frequency and lookback: Sentinel does not
# accept them with a 5-minute run, and their queries need the full window.

API="api-version=2024-09-01"
BASE="https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.OperationalInsights/workspaces/$WS/providers/Microsoft.SecurityInsights"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Settings applied to every rule (new and existing). Existing rules keep their own query.
SETTINGS_JQ='
  .enabled = true
  | .eventGroupingSettings = {aggregationKind: "AlertPerResult"}
  | .incidentConfiguration = {
      createIncident: true,
      groupingConfiguration: {
        enabled: true, reopenClosedIncident: false,
        lookbackDuration: $glb, matchingMethod: $gm,
        groupByEntities: [], groupByAlertDetails: [], groupByCustomDetails: []
      }
    }
  | .suppressionEnabled = false
  | .suppressionDuration = (.suppressionDuration // "PT5H")
  | if $kind == "Scheduled" then
      .queryFrequency = $freq | .queryPeriod = $period
      | .triggerOperator = "GreaterThan" | .triggerThreshold = 0
    else
      del(.queryFrequency, .queryPeriod, .triggerOperator, .triggerThreshold)
    end'

# Template properties that are valid on an analytics rule.
NEW_JQ='
  {displayName, description, severity, query, queryFrequency, queryPeriod,
   triggerOperator, triggerThreshold, tactics, techniques, subTechniques,
   entityMappings, customDetails, alertDetailsOverride, sentinelEntitiesMappings}
  | with_entries(select(.value != null))
  | .alertRuleTemplateName = $tid | .templateVersion = $ver'

# --reset: template settings, plus the portal defaults where the template has none.
RESET_JQ='
  (.props | '"$NEW_JQ"')
  + (.props | {incidentConfiguration, eventGroupingSettings, suppressionEnabled, suppressionDuration}
     | with_entries(select(.value != null)))
  | .enabled = true
  | .eventGroupingSettings //= {aggregationKind: "SingleAlert"}
  | .incidentConfiguration //= {}
  | .incidentConfiguration.createIncident //= true
  | .incidentConfiguration.groupingConfiguration //= {
      enabled: false, reopenClosedIncident: false, lookbackDuration: "PT5H", matchingMethod: "AllEntities",
      groupByEntities: [], groupByAlertDetails: [], groupByCustomDetails: []}
  | .incidentConfiguration.groupingConfiguration |= (
      # templates may use the portal format ("5h") and omit the matching method
      .lookbackDuration = ((.lookbackDuration // "PT5H") | ascii_upcase
        | if test("^P") then . elif test("D$") then "P" + . else "PT" + . end)
      | .matchingMethod //= (if ((.groupByEntities // []) | length) > 0 then "Selected" else "AllEntities" end)
      | .reopenClosedIncident //= false
      | .groupByEntities //= [] | .groupByAlertDetails //= [] | .groupByCustomDetails //= [])
  | .suppressionEnabled //= false
  | .suppressionDuration //= "PT5H"'

mins() {  # ISO 8601 duration (PT5M, PT1H, P1D, P14D) -> minutes
  jq -rn --arg d "$1" '$d | capture("^P((?<d>[0-9]+)D)?(T((?<h>[0-9]+)H)?((?<m>[0-9]+)M)?)?$")
    | ((.d // "0" | tonumber) * 1440 + (.h // "0" | tonumber) * 60 + (.m // "0" | tonumber))'
}

get_all() {  # GET a list URL, follow nextLink, print one JSON array
  local url="$1" i=0
  rm -f "$TMP"/page_*.json
  while [[ -n "$url" ]]; do
    az rest --method get --url "$url" -o json > "$TMP/page_$i.json"
    url=$(jq -r '.nextLink // empty' "$TMP/page_$i.json")
    i=$((i + 1))
  done
  jq -s '[.[].value[]]' "$TMP"/page_*.json
}

build_body() {  # $1 existing rule id or "" for a new rule, $2 kind, $3 frequency, $4 lookback -> $TMP/body.json
  local a=(--arg kind "$2" --arg freq "$3" --arg period "$4" --arg glb "$GROUP_LOOKBACK"
           --arg gm "$GROUP_MATCHING" --arg tid "$tid" --arg ver "$ver")
  if [[ -n "$1" ]]; then
    jq "${a[@]}" --arg rid "$1" '
      .[] | select(.name == $rid)
      | {kind, etag, properties: (.properties | del(.lastModifiedUtc) | '"$SETTINGS_JQ"')}
      | with_entries(select(.value != null))' "$TMP/rules.json"
  else
    jq "${a[@]}" '.props | '"$NEW_JQ"' | '"$SETTINGS_JQ"' | {kind: $kind, properties: .}' <<<"$t"
  fi > "$TMP/body.json"
}

put_body() {  # $1 rule id; prints the error on failure
  az rest --method put --url "$BASE/alertRules/$1?$API" --body @"$TMP/body.json" -o none 2>&1 </dev/null
}

created=0; updated=0; reset=0; skipped=0; failed=0

ok() {  # $1 CREATE|UPDATE, $2 message
  echo "OK       $1  $2"
  if [[ "$1" == CREATE ]]; then created=$((created + 1)); else updated=$((updated + 1)); fi
}

fail() {  # $1 CREATE|UPDATE, $2 error text
  echo "FAILED   $1  $name"
  echo "$2" | grep -v '^$' | head -n 3 | sed 's/^/           /'
  failed=$((failed + 1))
}

upsert() {  # $1 rule id, $2 CREATE|UPDATE, $3 rule kind
  local rid="$1" action="$2" rkind="$3" freq="$QUERY_FREQUENCY" period="$QUERY_PERIOD" note="" err
  local existing_id=""; [[ "$action" == UPDATE ]] && existing_id="$rid"

  if [[ "$rkind" == Scheduled && -n "$tperiod" ]] && (( $(mins "$tperiod") > $(mins "$QUERY_PERIOD") )); then
    freq="$tfreq"; period="$tperiod"; note="  (KEEP-SCHEDULE $freq/$period)"
  fi
  build_body "$existing_id" "$rkind" "$freq" "$period"

  if $DRY_RUN; then
    cp "$TMP/body.json" "$BODY_DIR/$rid.json"
    echo "DRY-RUN  $action  $name$note"; return
  fi

  if err=$(put_body "$rid"); then
    ok "$action" "$name$note"
  elif [[ "$rkind" == Scheduled && -n "$tperiod" && "$freq/$period" != "$tfreq/$tperiod" ]] \
       && grep -qiE 'frequency|period|lookback' <<<"$err"; then
    # The 5-minute schedule was rejected: retry once with the template's own schedule
    build_body "$existing_id" "$rkind" "$tfreq" "$tperiod"
    if err=$(put_body "$rid"); then
      ok "$action" "$name  (own schedule $tfreq/$tperiod)"
    else
      fail "$action" "$err"
    fi
  else
    fail "$action" "$err"
  fi
}

reset_rule() {  # $1 rule id: PUT the template's default values, keep the rule's etag
  local rid="$1" err
  jq --arg tid "$tid" --arg ver "$ver" --arg kind "$kind" --arg rid "$rid" --argjson t "$t" '
    .[] | select(.name == $rid)
    | {kind: $kind, etag, properties: ($t | '"$RESET_JQ"')}
    | with_entries(select(.value != null))' "$TMP/rules.json" > "$TMP/body.json"

  if $DRY_RUN; then
    cp "$TMP/body.json" "$BODY_DIR/$rid.json"
    echo "DRY-RUN  RESET  $name"; return
  fi
  if err=$(put_body "$rid"); then
    echo "OK       RESET  $name"; reset=$((reset + 1))
  else
    fail RESET "$err"
  fi
}

az account set --subscription "$SUB"
if $RESET; then
  echo "Workspace: $WS  (reset to template defaults, dry-run $DRY_RUN)"
else
  echo "Workspace: $WS  (frequency $QUERY_FREQUENCY, lookback $QUERY_PERIOD, dry-run $DRY_RUN)"
fi
if $DRY_RUN; then mkdir -p "$BODY_DIR"; rm -f "$BODY_DIR"/*.json; fi

get_all "$BASE/contentTemplates?$API&%24filter=properties/contentKind%20eq%20'AnalyticsRule'&%24expand=properties/mainTemplate" > "$TMP/templates.json"
get_all "$BASE/alertRules?$API" > "$TMP/rules.json"

# One line per template that comes from an installed solution.
# If two solutions ship the same template, keep the highest version.
jq -c '[.[] | select(.properties.packageKind == "Solution")
  | .properties as $p
  | ($p.mainTemplate.resources[] | select(.type | test("AlertRuleTemplates$"; "i"))) as $r
  | {tid: $p.contentId, ver: $p.version, sol: $p.source.name, kind: $r.kind, props: $r.properties}]
  | group_by(.tid) | map(sort_by(.ver | split(".") | map(tonumber? // 0)) | last) | .[]' \
  "$TMP/templates.json" > "$TMP/work.jsonl"

echo "Solution templates found: $(wc -l < "$TMP/work.jsonl")"

while IFS= read -r t <&3; do
  tid=$(jq -r .tid <<<"$t"); ver=$(jq -r .ver <<<"$t"); kind=$(jq -r .kind <<<"$t")
  sol=$(jq -r .sol <<<"$t"); name="$(jq -r .props.displayName <<<"$t") [$sol]"
  tfreq=$(jq -r '.props.queryFrequency // empty' <<<"$t"); tperiod=$(jq -r '.props.queryPeriod // empty' <<<"$t")

  if [[ "$kind" != "Scheduled" && "$kind" != "NRT" ]]; then
    echo "SKIP     $kind  $name"; skipped=$((skipped + 1)); continue
  fi

  mapfile -t existing < <(jq -r --arg tid "$tid" \
    '.[] | select(.properties.alertRuleTemplateName == $tid) | "\(.name) \(.kind)"' "$TMP/rules.json")

  if $RESET; then
    if (( ${#existing[@]} == 0 )); then
      echo "SKIP     no rule  $name"; skipped=$((skipped + 1)); continue
    fi
    for row in "${existing[@]}"; do reset_rule "${row%% *}"; done
    continue
  fi

  if (( ${#existing[@]} == 0 )); then
    upsert "$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)" CREATE "$kind"
    continue
  fi
  if (( ${#existing[@]} > 1 )); then
    echo "WARN     ${#existing[@]} rules come from the same template: $name ($(printf '%s ' "${existing[@]%% *}"))"
  fi
  for row in "${existing[@]}"; do
    upsert "${row%% *}" UPDATE "${row##* }"
  done
done 3< "$TMP/work.jsonl"

echo "Done. created=$created updated=$updated reset=$reset skipped=$skipped failed=$failed (dry-run=$DRY_RUN)"
