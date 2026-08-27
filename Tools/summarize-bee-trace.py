#!/usr/bin/env python3
from pathlib import Path
from collections import Counter, defaultdict
import csv
import re
import sys

LINE_RE = re.compile(r"^\[BEE_TRACE\]\s+(.*)$")

def parse_kv(text):
    out = {}
    for token in text.split():
        if "=" in token:
            k, v = token.split("=", 1)
            out[k] = v
    return out

def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: summarize-bee-trace.py <zone-perf-log>")
    log = Path(sys.argv[1])
    if not log.exists():
        raise SystemExit(f"ERROR: log not found: {log}")

    events = []
    for raw in log.read_text(errors="replace").splitlines():
        m = LINE_RE.match(raw)
        if m:
            events.append(parse_kv(m.group(1)))

    if not events:
        print(f"No [BEE_TRACE] events found in {log}")
        return

    results = [e for e in events if e.get("event") == "request_result"]
    spawned = [e for e in results if e.get("result") == "spawned"]
    blocked = [e for e in results if e.get("result") == "blocked"]
    destroys = [e for e in events if e.get("event") == "bee_destroy"]
    triggers = [e for e in events if e.get("event") == "mother_hit_trigger"]

    reasons = Counter(e.get("reason", "unknown") for e in blocked)
    by_wave = defaultdict(Counter)
    for e in results:
        wave = e.get("wave", "?")
        key = "spawned" if e.get("result") == "spawned" else f"blocked:{e.get('reason','unknown')}"
        by_wave[wave][key] += 1

    refunds = donor_releases = 0
    for e in destroys:
        try:
            rb = int(e.get("requester_count_before", "-1"))
            ra = int(e.get("requester_count_after", "-1"))
            db = int(e.get("donor_out_before", "-1"))
            da = int(e.get("donor_out_after", "-1"))
        except ValueError:
            continue
        refunds += ra < rb
        donor_releases += da < db

    out_dir = Path("build/bee-parity")
    out_dir.mkdir(parents=True, exist_ok=True)
    summary_path = out_dir / f"{log.stem}-bee-summary.txt"
    csv_path = out_dir / f"{log.stem}-bee-events.csv"

    lines = [
        "The Zone Remastered — Bee Parity Pass 0 Summary",
        f"log: {log}", "",
        f"Mother nonlethal-hit triggers: {len(triggers)}",
        f"Bee request results:          {len(results)}",
        f"Bee spawns:                   {len(spawned)}",
        f"Blocked requests:             {len(blocked)}",
        f"Bee destructions traced:      {len(destroys)}",
        f"Requester quota refunds seen: {refunds}",
        f"Donor releases on destroy:    {donor_releases}",
        "", "Blocked reasons:",
    ]
    if reasons:
        for reason, count in sorted(reasons.items()):
            lines.append(f"  {reason}: {count}")
    else:
        lines.append("  none")

    lines += ["", "By wave:"]
    def wave_key(w):
        try:
            return (0, int(w))
        except ValueError:
            return (1, w)
    for wave in sorted(by_wave, key=wave_key):
        parts = ", ".join(f"{k}={v}" for k, v in sorted(by_wave[wave].items()))
        lines.append(f"  wave {wave}: {parts}")
    lines += ["", "Pass 0 changes no Bee gameplay rule."]

    text = "\n".join(lines) + "\n"
    summary_path.write_text(text)
    print(text, end="")
    print(f"Saved summary: {summary_path}")

    keys = sorted({k for e in events for k in e})
    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(events)
    print(f"Saved events:  {csv_path}")

if __name__ == "__main__":
    main()
