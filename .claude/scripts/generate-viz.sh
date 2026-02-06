#!/bin/bash
# generate-viz.sh — Generates a static HTML dashboard from beads state.
# Usage: ./generate-viz.sh [output-path]
# Defaults output to .claude-beads/viz.html

set -euo pipefail

BEADS_DIR=".claude-beads"
STATE_FILE="$BEADS_DIR/state.json"
OUTPUT="${1:-$BEADS_DIR/viz.html}"

if [ ! -f "$STATE_FILE" ]; then
  echo "No state file found at $STATE_FILE. Run /beads to start a workflow first." >&2
  exit 1
fi

# Derive bead root from state.json
BEAD_ROOT=$(jq -r '.bead_root // empty' "$STATE_FILE")
if [ -z "$BEAD_ROOT" ]; then
  echo "No bead_root in state.json. The workflow may not have started yet." >&2
  exit 1
fi

# Read title for the HTML <title> tag
TITLE=$(jq -r '.title' "$STATE_FILE")

# Collect data as compact JSON (single-line, safe for embedding)
STATE_JSON=$(jq -c '.' "$STATE_FILE")

# Collect root bead + child beads
BEADS_JSON="[]"
if [ -f "$BEAD_ROOT/bead.json" ]; then
  ROOT_BEAD=$(jq -c '.' "$BEAD_ROOT/bead.json")
  CHILD_BEADS="[]"
  if ls "$BEAD_ROOT/children/"*/bead.json 1>/dev/null 2>&1; then
    CHILD_BEADS=$(jq -s -c '.' "$BEAD_ROOT"/children/*/bead.json)
  fi
  BEADS_JSON=$(printf '%s\n%s' "$ROOT_BEAD" "$CHILD_BEADS" | jq -s -c '.[0] as $root | .[1] as $children | [$root] + $children')
fi

# Collect artifacts from bead root
ARTIFACTS_JSON="[]"
if ls "$BEAD_ROOT/artifacts/"*.md 1>/dev/null 2>&1; then
  ARTIFACTS_JSON=$(for f in "$BEAD_ROOT"/artifacts/*.md; do
    name=$(basename "$f")
    size=$(wc -c < "$f" | tr -d ' ')
    printf '{"name":"%s","size":%s}\n' "$name" "$size"
  done | jq -s -c '.')
fi

# Collect summaries from bead root
SUMMARIES_JSON="[]"
if ls "$BEAD_ROOT/summaries/"*.md 1>/dev/null 2>&1; then
  SUMMARIES_JSON=$(for f in "$BEAD_ROOT"/summaries/*.md; do
    name=$(basename "$f")
    printf '{"name":"%s"}\n' "$name"
  done | jq -s -c '.')
fi

# Write HTML by concatenating fragments around the JSON data
{
cat << 'HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
HEAD

printf '<title>Beads — %s</title>\n' "$TITLE"

cat << 'STYLE'
<style>
  :root {
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #e6edf3; --text-dim: #8b949e; --text-bright: #f0f6fc;
    --green: #3fb950; --yellow: #d29922; --red: #f85149;
    --blue: #58a6ff; --purple: #bc8cff; --cyan: #39d2c0;
    --orange: #f0883e;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background: var(--bg); color: var(--text); padding: 2rem; line-height: 1.5; }
  h1 { color: var(--text-bright); font-size: 1.5rem; margin-bottom: 0.25rem; }
  .meta { color: var(--text-dim); font-size: 0.85rem; margin-bottom: 2rem; }
  .meta span { margin-right: 1.5rem; }
  .meta code { background: var(--surface); padding: 0.15rem 0.4rem; border-radius: 4px;
    font-size: 0.8rem; border: 1px solid var(--border); }

  .timeline { display: flex; gap: 0; margin-bottom: 2.5rem; position: relative; }
  .phase-step { flex: 1; text-align: center; position: relative; padding-top: 2.5rem; }
  .phase-step .dot { width: 18px; height: 18px; border-radius: 50%; border: 2px solid var(--border);
    background: var(--surface); position: absolute; top: 0; left: 50%; transform: translateX(-50%);
    z-index: 2; }
  .phase-step .label { font-size: 0.75rem; color: var(--text-dim); text-transform: capitalize; }
  .phase-step.done .dot { background: var(--green); border-color: var(--green); }
  .phase-step.active .dot { background: var(--blue); border-color: var(--blue);
    box-shadow: 0 0 0 4px rgba(88,166,255,0.2); }
  .phase-step.active .label { color: var(--blue); font-weight: 600; }
  .phase-step.done .label { color: var(--green); }
  .timeline-line { position: absolute; top: 8px; left: 7%; right: 7%; height: 2px;
    background: var(--border); z-index: 1; }
  .timeline-line .fill { height: 100%; background: var(--green); transition: width 0.3s; }

  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-bottom: 1.5rem; }
  @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }

  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
    padding: 1.25rem; }
  .card h2 { font-size: 0.9rem; color: var(--text-dim); text-transform: uppercase;
    letter-spacing: 0.05em; margin-bottom: 1rem; }
  .card.full { grid-column: 1 / -1; }

  .checkpoint { display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem 0;
    border-bottom: 1px solid var(--border); }
  .checkpoint:last-child { border-bottom: none; }
  .checkpoint .indicator { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .checkpoint .name { flex: 1; font-size: 0.9rem; }

  .artifact { display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem 0;
    border-bottom: 1px solid var(--border); }
  .artifact:last-child { border-bottom: none; }
  .artifact .icon { font-size: 1rem; }
  .artifact .name { flex: 1; font-size: 0.9rem; font-family: monospace; }
  .artifact .size { font-size: 0.8rem; color: var(--text-dim); }

  .bead { background: var(--bg); border: 1px solid var(--border); border-radius: 6px;
    padding: 0.85rem 1rem; margin-bottom: 0.75rem; }
  .bead:last-child { margin-bottom: 0; }
  .bead.root { border-left: 3px solid var(--purple); }
  .bead.child { border-left: 3px solid var(--cyan); margin-left: 1.5rem; }
  .bead .bead-header { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.35rem; }
  .bead .bead-id { font-family: monospace; font-size: 0.8rem; color: var(--text-dim); }
  .bead .bead-title { font-size: 0.9rem; font-weight: 500; }
  .bead .bead-meta { font-size: 0.8rem; color: var(--text-dim); }
  .bead .bead-meta span { margin-right: 1rem; }

  .badge { display: inline-block; padding: 0.1rem 0.5rem; border-radius: 10px;
    font-size: 0.75rem; font-weight: 600; text-transform: capitalize; }
  .badge.approved, .badge.completed, .badge.complete { background: rgba(63,185,80,0.15); color: var(--green); }
  .badge.in-progress { background: rgba(88,166,255,0.15); color: var(--blue); }
  .badge.pending, .badge.null { background: rgba(139,148,158,0.15); color: var(--text-dim); }
  .badge.rejected, .badge.blocked, .badge.escalated { background: rgba(248,81,73,0.15); color: var(--red); }

  .iter-row { display: flex; align-items: center; justify-content: space-between;
    padding: 0.5rem 0; border-bottom: 1px solid var(--border); }
  .iter-row:last-child { border-bottom: none; }
  .iter-label { font-size: 0.9rem; }
  .iter-count { font-family: monospace; font-size: 0.9rem; }
  .iter-bar { width: 60px; height: 6px; background: var(--border); border-radius: 3px;
    margin-left: 0.75rem; overflow: hidden; display: inline-block; vertical-align: middle; }
  .iter-bar .fill { height: 100%; border-radius: 3px; }

  .empty { color: var(--text-dim); font-size: 0.85rem; font-style: italic; }
  .footer { margin-top: 2rem; text-align: center; font-size: 0.8rem; color: var(--text-dim); }
</style>
</head>
<body>

<h1 id="title"></h1>
<div class="meta">
  <span>ID: <code id="task-id"></code></span>
  <span>Status: <span id="status-badge" class="badge"></span></span>
  <span>Branch: <code id="branch"></code></span>
  <span id="pr-wrap" style="display:none">PR: <code id="pr"></code></span>
</div>

<div class="timeline" id="timeline">
  <div class="timeline-line"><div class="fill" id="timeline-fill"></div></div>
</div>

<div class="grid">
  <div class="card">
    <h2>Checkpoints</h2>
    <div id="checkpoints"></div>
  </div>
  <div class="card">
    <h2>Iterations</h2>
    <div id="iterations"></div>
  </div>
  <div class="card">
    <h2>Artifacts</h2>
    <div id="artifacts"></div>
  </div>
  <div class="card">
    <h2>Summaries</h2>
    <div id="summaries"></div>
  </div>
</div>

<div class="card full" style="margin-bottom:1.5rem">
  <h2>Beads</h2>
  <div id="beads"></div>
</div>

<div class="footer">
  Generated <span id="gen-time"></span> &mdash; claude-beads
</div>

<script>
STYLE

# Inject JSON data directly between script fragments
printf 'const STATE = %s;\n' "$STATE_JSON"
printf 'const BEADS = %s;\n' "$BEADS_JSON"
printf 'const ARTIFACTS = %s;\n' "$ARTIFACTS_JSON"
printf 'const SUMMARIES = %s;\n' "$SUMMARIES_JSON"

cat << 'SCRIPT'

const PHASES = ['requirements','architecture','planning','testing','implementation','validation','complete'];
const CHECKPOINTS = [
  { key: 'post-requirements', label: 'Post-Requirements' },
  { key: 'post-architecture', label: 'Post-Architecture' },
  { key: 'post-planning', label: 'Post-Planning' },
  { key: 'final-review', label: 'Final Review' }
];

document.getElementById('title').textContent = STATE.title || 'Untitled Task';
document.getElementById('task-id').textContent = STATE.task_id;
const statusBadge = document.getElementById('status-badge');
statusBadge.textContent = STATE.status;
statusBadge.className = 'badge ' + STATE.status;
document.getElementById('branch').textContent = STATE.branch || 'none';
if (STATE.pr) {
  document.getElementById('pr-wrap').style.display = 'inline';
  document.getElementById('pr').textContent = STATE.pr;
}

const timeline = document.getElementById('timeline');
const currentIdx = PHASES.indexOf(STATE.phase);
PHASES.forEach(function(p, i) {
  var step = document.createElement('div');
  step.className = 'phase-step' + (i < currentIdx ? ' done' : '') + (i === currentIdx ? ' active' : '');
  step.innerHTML = '<div class="dot"></div><div class="label">' + p + '</div>';
  timeline.appendChild(step);
});
document.getElementById('timeline-fill').style.width =
  (currentIdx >= 0 ? Math.round((currentIdx / (PHASES.length - 1)) * 100) : 0) + '%';

var cpEl = document.getElementById('checkpoints');
CHECKPOINTS.forEach(function(cp) {
  var val = (STATE.checkpoints && STATE.checkpoints[cp.key]) || 'pending';
  if (val === 'null' || val === null) val = 'pending';
  var color = val === 'approved' ? 'var(--green)' : val === 'rejected' ? 'var(--red)' : 'var(--text-dim)';
  cpEl.innerHTML += '<div class="checkpoint">' +
    '<div class="indicator" style="background:' + color + '"></div>' +
    '<div class="name">' + cp.label + '</div>' +
    '<span class="badge ' + val + '">' + val + '</span></div>';
});

var iterEl = document.getElementById('iterations');
var iters = [
  { label: 'Analyst \u2194 Architect', val: (STATE.iterations && STATE.iterations.analyst_architect) || 0, max: 2 },
  { label: 'Developer \u2194 Validator', val: (STATE.iterations && STATE.iterations.developer_validator) || 0, max: 3 }
];
iters.forEach(function(it) {
  var fillPct = Math.round((it.val / it.max) * 100);
  var fillColor = it.val >= it.max ? 'var(--red)' : it.val > 0 ? 'var(--yellow)' : 'var(--green)';
  iterEl.innerHTML += '<div class="iter-row"><span class="iter-label">' + it.label + '</span>' +
    '<span><span class="iter-count">' + it.val + '/' + it.max + '</span>' +
    '<span class="iter-bar"><span class="fill" style="width:' + fillPct + '%;background:' + fillColor + '"></span></span>' +
    '</span></div>';
});

var artEl = document.getElementById('artifacts');
if (ARTIFACTS.length === 0) {
  artEl.innerHTML = '<div class="empty">No artifacts yet</div>';
} else {
  ARTIFACTS.forEach(function(a) {
    var kb = (a.size / 1024).toFixed(1);
    artEl.innerHTML += '<div class="artifact"><span class="icon">\uD83D\uDCC4</span>' +
      '<span class="name">' + a.name + '</span><span class="size">' + kb + ' KB</span></div>';
  });
}

var sumEl = document.getElementById('summaries');
if (SUMMARIES.length === 0) {
  sumEl.innerHTML = '<div class="empty">No summaries yet</div>';
} else {
  SUMMARIES.forEach(function(s) {
    sumEl.innerHTML += '<div class="artifact"><span class="icon">\uD83D\uDCDD</span>' +
      '<span class="name">' + s.name + '</span></div>';
  });
}

var beadsEl = document.getElementById('beads');
if (BEADS.length === 0) {
  beadsEl.innerHTML = '<div class="empty">No beads yet</div>';
} else {
  var root = BEADS.find(function(b) { return b.parent_id === null; });
  var children = BEADS.filter(function(b) { return b.parent_id !== null; })
    .sort(function(a, b) { return a.id > b.id ? 1 : -1; });

  function renderBead(b, isRoot) {
    var cls = isRoot ? 'root' : 'child';
    var deps = (b.depends_on && b.depends_on.length > 0) ? 'depends on: ' + b.depends_on.join(', ') : '';
    var complexity = b.complexity ? '<span>complexity: ' + b.complexity + '</span>' : '';
    var phase = b.phase ? '<span>phase: ' + b.phase + '</span>' : '';
    return '<div class="bead ' + cls + '">' +
      '<div class="bead-header"><span class="bead-id">' + b.id + '</span>' +
      '<span class="badge ' + b.status + '">' + b.status + '</span></div>' +
      '<div class="bead-title">' + b.title + '</div>' +
      '<div class="bead-meta">' + phase + complexity +
      (deps ? '<span>' + deps + '</span>' : '') + '</div></div>';
  }

  if (root) beadsEl.innerHTML += renderBead(root, true);
  children.forEach(function(c) { beadsEl.innerHTML += renderBead(c, false); });
}

document.getElementById('gen-time').textContent = new Date().toLocaleString();
</script>
</body>
</html>
SCRIPT

} > "$OUTPUT"

echo "Dashboard generated at $OUTPUT"
