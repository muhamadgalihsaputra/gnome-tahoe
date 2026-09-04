#!/usr/bin/env bash
set -Eeuo pipefail

HOME_DIR="@HOME@"
LOG="$HOME_DIR/oci-log.txt"
ATTEMPTS_FILE="$HOME_DIR/oci-attempt-count.txt"
SUCCESS_MARKER="$HOME_DIR/.oci-vm-created"
LOCK_FILE="$HOME_DIR/.oci-create-instance.lock"
CREATE_SCRIPT="$HOME_DIR/oci-create-instance.sh"
CRON_OUTPUT_DIR="$HOME_DIR/.hermes/cron/output/406b4cc6abde"
LOG_MAX_BYTES="${OCI_LOG_MAX_BYTES:-5242880}"
LOG_BACKUPS="${OCI_LOG_BACKUPS:-7}"
CRON_OUTPUT_KEEP_DAYS="${OCI_CRON_OUTPUT_KEEP_DAYS:-14}"
COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaa37l67qkhblzf2glbzuatnxyvieb4xgkmctamplrt7g7cbzwoow5q"
EMAIL_TO="muhamadgalihsaputra@proton.me"
HIMALAYA_BIN="/usr/bin/himalaya"
HIMALAYA_ACCOUNT="keiya"
HIMALAYA_CONFIG="$HOME_DIR/.config/himalaya/keiya.toml"
OCI_BIN="@HOME@/.local/bin/oci"
export HOME="$HOME_DIR"
export PATH="$HOME_DIR/.local/bin:$HOME_DIR/.hermes/hermes-agent/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export OCI_CLI_CONFIG_FILE="$HOME_DIR/.oci/config"

mkdir -p "$HOME_DIR"
touch "$LOG"

rotate_file_if_needed() {
  local file="$1"
  local max_bytes="$2"
  local backups="$3"
  [ -f "$file" ] || return 0
  local size
  size="$(wc -c < "$file" 2>/dev/null || printf '0')"
  [ "${size:-0}" -lt "$max_bytes" ] && return 0

  local i prev
  i="$backups"
  while [ "$i" -gt 1 ]; do
    prev=$((i - 1))
    [ -f "$file.$prev" ] && mv -f "$file.$prev" "$file.$i"
    i="$prev"
  done
  mv -f "$file" "$file.1"
  : > "$file"
}

cleanup_old_cron_outputs() {
  [ -d "$CRON_OUTPUT_DIR" ] || return 0
  find "$CRON_OUTPUT_DIR" -type f -name '*.md' -mtime +"$CRON_OUTPUT_KEEP_DAYS" -delete 2>/dev/null || true
}

maintenance_cleanup() {
  rotate_file_if_needed "$LOG" "$LOG_MAX_BYTES" "$LOG_BACKUPS"
  cleanup_old_cron_outputs
}

log() {
  maintenance_cleanup
  printf '[%s] %s\n' "$(date -Is)" "$*" >> "$LOG"
}

html_escape() {
  python3 -c 'import html,sys; print(html.escape(sys.stdin.read()))'
}

send_email() {
  local subject="$1"
  local body="$2"
  local tmp
  tmp="$(mktemp)"
  {
    printf 'From: Keiya Putri Zeyni <keiyazeyniputri@gmail.com>\n'
    printf 'To: %s\n' "$EMAIL_TO"
    printf 'Subject: %s\n' "$subject"
    printf 'MIME-Version: 1.0\n'
    printf 'Content-Type: text/plain; charset=UTF-8\n'
    printf 'Content-Transfer-Encoding: 8bit\n'
    printf '\n'
    printf '%s\n' "$body"
  } > "$tmp"

  # Send from Keiya's own mailbox via the dedicated Keiya Himalaya SMTP/IMAP config, not Galyarder/Galih OAuth.
  if "$HIMALAYA_BIN" message send --account "$HIMALAYA_ACCOUNT" --config "$HIMALAYA_CONFIG" < "$tmp" >/tmp/oci-mail.out 2>/tmp/oci-mail.err; then
    rm -f "$tmp"
    log "Email sent from Keiya via Himalaya: $subject"
  else
    log "EMAIL FAILED via Himalaya: $subject :: $(cat /tmp/oci-mail.err 2>/dev/null | tr '\n' ' ' | head -c 500)"
    rm -f "$tmp"
    return 1
  fi
}

pause_hermes_retry_job() {
  local job_id="${OCI_HERMES_RETRY_JOB_ID:-}"
  if [ -n "$job_id" ] && command -v hermes >/dev/null 2>&1; then
    hermes cron pause "$job_id" >> "$LOG" 2>&1 || true
    log "Requested Hermes retry job pause: $job_id"
  else
    log "Hermes retry job id unavailable; could not pause retry job automatically."
  fi
}

ensure_hermes_retry_job() {
  local job_id="${OCI_HERMES_RETRY_JOB_ID:-}"
  if [ -n "$job_id" ] && command -v hermes >/dev/null 2>&1; then
    hermes cron resume "$job_id" >> "$LOG" 2>&1 || true
    log "Requested Hermes retry job resume: $job_id"
  else
    log "Hermes retry job id unavailable; retry should already be scheduled in Hermes dashboard."
  fi
}

get_running_instances_json() {
  "$OCI_BIN" compute instance list \
    --compartment-id "$COMPARTMENT_ID" \
    --lifecycle-state RUNNING \
    --all \
    --output json
}

summarize_instances() {
  python3 - <<'PY'
import json, sys
try:
    raw=sys.stdin.read()
    data=json.loads(raw or '{}')
    items=data.get('data', []) if isinstance(data, dict) else []
except Exception as e:
    print(f'Could not parse instance JSON: {e}')
    sys.exit(0)
if not items:
    print('No RUNNING instance found.')
    sys.exit(0)
for idx, inst in enumerate(items, 1):
    shape=inst.get('shape') or 'unknown'
    sc=inst.get('shape-config') or {}
    ocpus=sc.get('ocpus') or sc.get('ocpu-count') or 'unknown'
    mem=sc.get('memory-in-gbs') or sc.get('memoryInGBs') or 'unknown'
    print(f"Instance #{idx}")
    print(f"Name: {inst.get('display-name','unknown')}")
    print(f"ID: {inst.get('id','unknown')}")
    print(f"State: {inst.get('lifecycle-state','unknown')}")
    print(f"Shape: {shape} ({ocpus} OCPU, {mem} GB RAM)")
    print(f"AD: {inst.get('availability-domain','unknown')}")
    print(f"Created: {inst.get('time-created','unknown')}")
PY
}

count_running_instances() {
  python3 - <<'PY'
import json, sys
try:
    data=json.loads(sys.stdin.read() or '{}')
    print(len(data.get('data', []) if isinstance(data, dict) else []))
except Exception:
    print(0)
PY
}

extract_instance_id_from_launch_output() {
  python3 - <<'PY'
import json, re, sys
text=sys.stdin.read()
# Try whole JSON first.
try:
    obj=json.loads(text)
    data=obj.get('data', obj) if isinstance(obj, dict) else {}
    iid=data.get('id') if isinstance(data, dict) else None
    if iid:
        print(iid); raise SystemExit
except Exception:
    pass
m=re.search(r'ocid1\.instance\.oc1\.[A-Za-z0-9_.-]+', text)
if m:
    print(m.group(0))
PY
}

get_instance_details_json() {
  local instance_id="$1"
  "$OCI_BIN" compute instance get --instance-id "$instance_id" --output json
}

get_public_ip_for_instance() {
  local instance_id="$1"
  python3 - "$instance_id" "$COMPARTMENT_ID" <<'PY'
import json, subprocess, sys, os
instance_id=sys.argv[1]
compartment_id=sys.argv[2]
oci=os.environ.get('OCI_BIN','@HOME@/.local/bin/oci')

def run(args):
    return json.loads(subprocess.check_output(args, text=True))
try:
    vnic_attachments = run([oci,'compute','vnic-attachment','list','--compartment-id',compartment_id,'--instance-id',instance_id,'--all','--output','json']).get('data', [])
    for att in vnic_attachments:
        vid=att.get('vnic-id')
        if not vid: continue
        vnic = run([oci,'network','vnic','get','--vnic-id',vid,'--output','json']).get('data', {})
        ip=vnic.get('public-ip') or vnic.get('publicIp')
        if ip:
            print(ip)
            break
except Exception as e:
    print(f'unknown ({e})')
PY
}

compose_success_email() {
  local instance_id="$1"
  local attempts="$2"
  local created_at="$3"
  local details public_ip summary
  details="$(get_instance_details_json "$instance_id" 2>>"$LOG" || true)"
  public_ip="$(get_public_ip_for_instance "$instance_id" 2>>"$LOG" || true)"
  summary="$(printf '%s' "$details" | python3 - "$public_ip" "$attempts" "$created_at" <<'PY'
import json, sys
public_ip=sys.argv[1] if len(sys.argv)>1 else 'unknown'
attempts=sys.argv[2] if len(sys.argv)>2 else 'unknown'
created_at=sys.argv[3] if len(sys.argv)>3 else 'unknown'
try:
    obj=json.loads(sys.stdin.read() or '{}')
    inst=obj.get('data', obj) if isinstance(obj, dict) else {}
except Exception:
    inst={}
sc=inst.get('shape-config') or {}
ocpus=sc.get('ocpus') or sc.get('ocpu-count') or 'unknown'
mem=sc.get('memory-in-gbs') or sc.get('memoryInGBs') or 'unknown'
print(f"Oracle Cloud A1.Flex VM berhasil dibuat.\n\nInstance name: {inst.get('display-name','unknown')}\nInstance ID: {inst.get('id','unknown')}\nPublic IP: {public_ip or 'unknown'}\nShape: {inst.get('shape','unknown')}\nShape details: {ocpus} OCPU, {mem} GB RAM\nLifecycle state: {inst.get('lifecycle-state','unknown')}\nAvailability domain: {inst.get('availability-domain','unknown')}\nOCI time-created: {inst.get('time-created','unknown')}\nDetected success timestamp: {created_at}\nAttempts taken: {attempts}\n\nLog file: @HOME@/oci-log.txt")
PY
)"
  printf '%s' "$summary"
}

retry_once() {
  if [ -f "$SUCCESS_MARKER" ]; then
    log "Success marker exists; Hermes retry job will be paused."
    pause_hermes_retry_job
    exit 0
  fi

  # Avoid overlapping OCI launches if one attempt hangs.
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    log "Previous retry still running; skipping this tick."
    exit 0
  fi

  local attempts output rc timestamp instance_id body
  attempts=0
  if [ -f "$ATTEMPTS_FILE" ]; then
    attempts="$(tr -dc '0-9' < "$ATTEMPTS_FILE" || true)"
    attempts="${attempts:-0}"
  fi
  attempts=$((attempts + 1))
  printf '%s\n' "$attempts" > "$ATTEMPTS_FILE"
  timestamp="$(date -Is)"
  log "Attempt #$attempts started."

  set +e
  output="$(OCI_ONCE=1 "$CREATE_SCRIPT" 2>&1)"
  rc=$?
  set -e
  maintenance_cleanup
  {
    printf '\n===== OCI attempt #%s @ %s rc=%s =====\n' "$attempts" "$timestamp" "$rc"
    printf '%s\n' "$output"
    printf '===== end attempt #%s =====\n' "$attempts"
  } >> "$LOG"

  if printf '%s\n' "$output" | grep -qi 'Instance created'; then
    instance_id="$(printf '%s\n' "$output" | extract_instance_id_from_launch_output || true)"
    if [ -z "$instance_id" ]; then
      # Fallback: pick most recently created running instance.
      instance_id="$($OCI_BIN compute instance list --compartment-id "$COMPARTMENT_ID" --lifecycle-state RUNNING --sort-by TIMECREATED --sort-order DESC --all --query 'data[0].id' --raw-output 2>>"$LOG" || true)"
    fi
    printf 'created_at=%s\nattempts=%s\ninstance_id=%s\n' "$timestamp" "$attempts" "$instance_id" > "$SUCCESS_MARKER"
    log "Instance created detected. instance_id=$instance_id attempts=$attempts"
    body="$(compose_success_email "$instance_id" "$attempts" "$timestamp")"
    send_email "✅ Oracle Cloud VM created: galyarder-server" "$body" || true
    pause_hermes_retry_job
    exit 0
  fi

  if printf '%s\n' "$output" | grep -Eqi 'Out of capacity|Out of host capacity|Too Many Requests|LimitExceeded|429'; then
    log "Capacity/rate-limit failure on attempt #$attempts; staying silent."
    exit 0
  fi

  log "Unexpected OCI create failure on attempt #$attempts; staying silent for retry."
  exit 0
}

status_check() {
  local cadence="$1"
  local timestamp json count summary subject body
  timestamp="$(date -Is)"
  log "${cadence} status check started."
  set +e
  json="$(get_running_instances_json 2>>"$LOG")"
  rc=$?
  set -e
  if [ "${rc:-0}" -ne 0 ]; then
    subject="⚠️ Oracle Cloud ${cadence} status check failed"
    body="Oracle Cloud ${cadence} status check failed at $timestamp.\n\nCould not query OCI running instances.\n\nCheck log: @HOME@/oci-log.txt"
    log "${cadence} status check OCI query failed rc=$rc"
    send_email "$subject" "$body" || true
    exit 0
  fi
  count="$(printf '%s' "$json" | count_running_instances)"
  summary="$(printf '%s' "$json" | summarize_instances)"
  if [ "$count" -gt 0 ]; then
    subject="✅ Oracle Cloud ${cadence} status: $count running instance(s)"
    body="Oracle Cloud ${cadence} status report at $timestamp.\n\nStatus: RUNNING instance found.\n\n$summary\n\nLog file: @HOME@/oci-log.txt"
    log "${cadence} status: $count running instance(s)."
  else
    rm -f "$SUCCESS_MARKER"
    printf '0\n' > "$ATTEMPTS_FILE"
    ensure_hermes_retry_job
    subject="🔁 Oracle Cloud ${cadence} status: no running VM, Hermes retry re-armed"
    body="Oracle Cloud ${cadence} status report at $timestamp.\n\nStatus: No RUNNING instance found.\nAction: Re-triggered/resumed the Hermes 5-minute retry scheduled job and reset the retry attempt counter.\n\nLog file: @HOME@/oci-log.txt"
    log "${cadence} status: no running instance; success marker cleared, attempt counter reset, Hermes retry re-armed."
  fi
  send_email "$subject" "$body" || true
}

case "${1:-retry}" in
  retry) retry_once ;;
  ensure-retry) ensure_hermes_retry_job ;;
  weekly-check) status_check "weekly" ;;
  monthly-check) status_check "monthly" ;;
  *) echo "Usage: $0 {retry|ensure-retry|weekly-check|monthly-check}" >&2; exit 2 ;;
esac
