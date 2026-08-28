#!/usr/bin/env python3
from pathlib import Path
from collections import Counter, defaultdict
import csv, re, sys

RX = re.compile(r'^\[BEE_FIRE_TRACE\]\s+(.*)$')

def parse(line):
    out = {}
    for tok in line.split():
        if '=' in tok:
            k, v = tok.split('=', 1)
            out[k] = v
    return out

def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: summarize-bee-fire-trace.py <log>')
    log = Path(sys.argv[1])
    events = []
    for raw in log.read_text(errors='replace').splitlines():
        m = RX.match(raw)
        if m:
            events.append(parse(m.group(1)))
    if not events:
        print('No [BEE_FIRE_TRACE] events found.')
        return

    decisions = [e for e in events if e.get('event') == 'decision']
    blocks = [e for e in events if e.get('event') == 'blocked']
    gates = sum(e.get('gate') == '1' for e in decisions)
    fired = sum(e.get('fired') == '1' for e in decisions)
    reasons = Counter(e.get('reason', 'unknown') for e in blocks)
    waves = defaultdict(Counter)
    random_words = []
    for e in decisions:
        w = e.get('wave', '?')
        waves[w]['decisions'] += 1
        waves[w]['gate'] += e.get('gate') == '1'
        waves[w]['fired'] += e.get('fired') == '1'
        try:
            random_words.append(int(e['random_word']))
        except Exception:
            pass
    for e in blocks:
        waves[e.get('wave', '?')][f"blocked:{e.get('reason', 'unknown')}"] += 1

    outdir = Path('build/bee-parity')
    outdir.mkdir(parents=True, exist_ok=True)
    txt = outdir / f'{log.stem}-bee-fire-summary.txt'
    csvp = outdir / f'{log.stem}-bee-fire-events.csv'
    lines = [
        'The Zone Remastered — Bee Parity Pass 3A Firing Summary',
        f'log: {log}', '',
        f'RNG fire decisions observed: {len(decisions)}',
        f'Random words inside Bee gate: {gates}',
        f'Hostile shots actually made:  {fired}',
        f'Pre-RNG blocked passes:        {len(blocks)}',
        '', 'Blocked reasons:'
    ]
    if reasons:
        lines += [f'  {k}: {v}' for k, v in sorted(reasons.items())]
    else:
        lines.append('  none')
    if random_words:
        lines += ['', f'Observed signed Random range: {min(random_words)} .. {max(random_words)}']
    lines += ['', 'By wave:']
    def wk(x):
        try: return (0, int(x))
        except Exception: return (1, x)
    for w in sorted(waves, key=wk):
        lines.append('  wave ' + w + ': ' + ', '.join(f'{k}={v}' for k, v in sorted(waves[w].items())))
    lines += ['',
        'Important forensic constraint:',
        '  This accepted gameplay branch keeps world objects directly in a wrapped 640x480 space.',
        '  It does NOT carry the original world-object +128 camera/spatial eligibility flag.',
        '  Therefore Pass 3A measures firing behavior but deliberately does not invent an',
        '  on-screen/off-screen firing gate.'
    ]
    text = '\n'.join(lines) + '\n'
    txt.write_text(text)
    print(text, end='')
    keys = sorted({k for e in events for k in e})
    with csvp.open('w', newline='') as f:
        wr = csv.DictWriter(f, fieldnames=keys)
        wr.writeheader(); wr.writerows(events)
    print(f'Saved summary: {txt}')
    print(f'Saved events:  {csvp}')

if __name__ == '__main__':
    main()
