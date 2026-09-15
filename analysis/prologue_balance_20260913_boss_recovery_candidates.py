"""Unapproved isolated candidate: sword damage 7 -> 8, all other v5 values fixed."""
from collections import Counter
import copy
import csv
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from prologue_balance_20260913 import write_csv
from prologue_balance_20260913_boss_recovery import BossRecoveryBattle, FIXTURE, ROOT


def main():
    out = ROOT / 'artifacts' / 'balance-2026-09-13-boss-recovery'
    data = json.loads(FIXTURE.read_text(encoding='utf-8'))
    candidate = copy.deepcopy(data)
    assert candidate['items']['trial.sword']['damage'] == 7
    candidate['items']['trial.sword']['damage'] = 8
    with (out / 'baseline.csv').open(encoding='utf-8-sig', newline='') as f:
        lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in csv.DictReader(f)}
    rows, sensitivity, transitions = [], [], Counter()
    for build, profile in candidate['builds'].items():
        if 'trial.sword' not in profile['items']:
            continue
        for enemy in candidate['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = BossRecoveryBattle(candidate, build, enemy, start, policy).run()
                    before = lookup[(build, enemy, start, policy)]
                    r['candidate'] = 'unapproved_sword_damage_8'
                    for field in ('outcome', 'seconds', 'hp', 'stamina'):
                        r['baseline_' + field] = before[field]
                    rows.append(r)
                    transitions[before['outcome'] + ' -> ' + r['outcome']] += 1
                    s = BossRecoveryBattle(candidate, build, enemy, start, policy, enemy_first=True).run()
                    s['candidate_outcome'] = r['outcome']
                    sensitivity.append(s)
    write_csv(out / 'candidate_sword8.csv', rows)
    write_csv(out / 'candidate_sword8_enemy_first.csv', sensitivity)
    summary = dict(status='candidate only, not applied to approved fixture', delta={'trial.sword.damage': [7, 8]},
                   candidate_count=len(rows), enemy_first_count=len(sensitivity),
                   candidate_outcomes=dict(Counter(r['outcome'] for r in rows)),
                   transitions=dict(transitions),
                   enemy_first_outcome_changes=sum(r['outcome'] != r['candidate_outcome'] for r in sensitivity),
                   hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in (FIXTURE, Path(__file__), out / 'baseline.csv')})
    (out / 'candidate_verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    for r in rows:
        if r['build'] == 'sword_guard' and r['start'] == 'rested' and r['policy'] == 'manual':
            print(r['enemy'], r['outcome'], r['seconds'], r['hp'], r['stamina'])


if __name__ == '__main__':
    main()
