"""Sixth isolated experiment: the complete revised matchup matrix and bow damage 9."""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from prologue_balance_20260913 import model_checks, validate, write_csv
from prologue_balance_20260913_boss_recovery import BossRecoveryBattle, gated_checks

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURE = Path(__file__).with_suffix('.json')
PREVIOUS = HERE / 'prologue_balance_20260913_boss_recovery.json'


def revision_checks(old, data):
    for ident, prior in old['items'].items():
        expected = copy.deepcopy(prior)
        if ident == 'trial.bow':
            expected['damage'] = 9
        assert data['items'][ident] == expected, ident
    assert set(data['items']) == set(old['items'])
    for field in ('player', 'builds', 'enemies', 'default_bottles_per_type'):
        assert data[field] == old[field], field
    expected = [[1.05, 1.2, 1, 1.1], [1.2, 1.05, 1, 1], [.8, .8, 1.2, 1], [1, 1, 1, 1.2]]
    assert [[float(data['damage_multipliers'][a][t]) for t in ('pierce', 'slash', 'blunt', 'spell')]
            for a in ('none', 'light', 'heavy', 'spiritual')] == expected
    assert data['items']['trial.sword']['damage'] == 7
    return ['only bow damage 11 -> 9 and the supplied 16-cell matrix change; sword7 and all CDs/resources retained']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'artifacts' / 'balance-2026-09-13-matrix-bow9')
    args = parser.parse_args()
    data = json.loads(FIXTURE.read_text(encoding='utf-8'))
    old = json.loads(PREVIOUS.read_text(encoding='utf-8'))
    original_path = HERE / 'prologue_balance_20260913.json'
    original = json.loads(original_path.read_text(encoding='utf-8-sig'))
    checks = model_checks(original) + revision_checks(old, data) + gated_checks(data)
    layouts = validate(data)
    args.out.mkdir(parents=True, exist_ok=True)
    rows, paired, sensitivity = [], [], []
    for build in data['builds']:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = BossRecoveryBattle(data, build, enemy, start, policy).run()
                    rows.append(r)
                    before = BossRecoveryBattle(old, build, enemy, start, policy).run()
                    pair = dict(build=build, enemy=enemy, start=start, policy=policy)
                    for field in ('outcome', 'seconds', 'hp', 'stamina', 'enemy_hp', 'enemy_stamina'):
                        pair['before_' + field], pair['after_' + field] = before[field], r[field]
                    paired.append(pair)
                    variants = [('enemy_first', dict(enemy_first=True))]
                    if enemy in ('boar', 'boss_spider'):
                        variants += [('one_bottle', dict(bottles=1)), ('no_medicine', dict(bottles=0))]
                    for label, options in variants:
                        s = BossRecoveryBattle(data, build, enemy, start, policy, **options).run()
                        s['variant'] = label
                        sensitivity.append(s)
    # Paired attribution probes; these do not change the approved fixture.
    for label in ('matrix_only', 'bow_only'):
        d = copy.deepcopy(old)
        if label == 'matrix_only':
            d['damage_multipliers'] = copy.deepcopy(data['damage_multipliers'])
        else:
            d['items']['trial.bow']['damage'] = 9
        for build in ('sword_guard', 'bow_guard', 'hammer_guard', 'dual_sword_bow_balanced',
                      'dual_sword_hammer_balanced', 'dual_bow_hammer_balanced'):
            for enemy in data['enemies']:
                for start in ('full', 'rested'):
                    s = BossRecoveryBattle(d, build, enemy, start, 'manual').run()
                    s['variant'] = label
                    sensitivity.append(s)
    exhausted = [r for r in rows if r['outcome'] == 'victory'
                 and r['enemy_permanent_resource_stop_at_s'] != ''
                 and r['seconds'] > r['enemy_permanent_resource_stop_at_s']]
    for r in rows:
        if r['enemy'] in ('boar', 'boss_spider'):
            assert r['enemy_permanent_resource_stop_at_s'] == ''
    write_csv(args.out / 'baseline.csv', rows)
    write_csv(args.out / 'paired_before_after.csv', paired)
    write_csv(args.out / 'sensitivity.csv', sensitivity)
    write_csv(args.out / 'exhausted_victories.csv', exhausted)
    write_csv(args.out / 'rested_manual_matchups.csv',
              [r for r in rows if r['start'] == 'rested' and r['policy'] == 'manual'])
    for build, enemy, policy in [
        ('sword_guard', 'wolf', 'manual'), ('bow_guard', 'bird', 'manual'),
        ('bow_guard', 'gray_spider', 'manual'), ('hammer_guard', 'turtle', 'manual'),
        ('dual_bow_hammer_stamina', 'boss_spider', 'manual'),
        ('dual_sword_hammer_balanced', 'boss_spider', 'manual')]:
        b = BossRecoveryBattle(data, build, enemy, 'rested', policy, trace=True)
        r = b.run()
        (args.out / f'trace_{build}_{enemy}_{policy}.json').write_text(
            json.dumps(dict(result=r, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in rows}
    changes = Counter(s['variant'] for s in sensitivity
                      if s['outcome'] != lookup[(s['build'], s['enemy'], s['start'], s['policy'])]['outcome'])
    summary = dict(checks=checks, layouts=layouts, baseline_count=len(rows),
                   baseline_outcomes=dict(Counter(r['outcome'] for r in rows)),
                   paired_count=len(paired),
                   paired_transitions=dict(Counter(r['before_outcome'] + ' -> ' + r['after_outcome'] for r in paired)),
                   sensitivity_count=len(sensitivity), exhausted_victory_count=len(exhausted),
                   exhausted_by_enemy=dict(Counter(r['enemy'] for r in exhausted)),
                   outcome_changes_by_variant=dict(changes), hashes={
                       p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                       [FIXTURE, PREVIOUS, original_path, Path(__file__),
                        HERE / 'prologue_balance_20260913.py', HERE / 'prologue_balance_20260913_pacing.py',
                        HERE / 'prologue_balance_20260913_boss_recovery.py']})
    (args.out / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k not in ('layouts', 'hashes')}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
