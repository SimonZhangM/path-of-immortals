"""Fourth isolated design experiment: +50% enemy stamina, rounded upward."""
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
from prologue_balance_20260913_recovery_hp import ResourceObservedBattle

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURE = Path(__file__).with_suffix('.json')
PREVIOUS = HERE / 'prologue_balance_20260913_recovery_hp.json'


def revision_checks(old, data):
    assert len(data['enemies']) == 8
    for ident, enemy in data['enemies'].items():
        prior = old['enemies'][ident]
        assert enemy['stamina'] == (prior['stamina'] * 3 + 1) // 2, ident
        assert {k: v for k, v in enemy.items() if k != 'stamina'} == {
            k: v for k, v in prior.items() if k != 'stamina'}, ident
    assert data['enemies']['boar']['stamina'] == 98
    for field in ('items', 'builds', 'player', 'damage_multipliers', 'default_bottles_per_type'):
        assert data[field] == old[field], field
    b = ResourceObservedBattle(data, 'dual_sword_bow_balanced', 'boar')
    assert b.sides[1].stamina == b.sides[1].stamina_cap == 98
    return ['all eight enemy stamina values increased 50% once, ceiling 65 -> 98',
            'HP, organs, costs, CDs, player, relic, medicines and builds unchanged',
            'enemy initial and maximum stamina both use the new value']


def resource_probe(data, enemy, out, label):
    # Isolate the enemy's resource schedule from either side dying early.
    probe = copy.deepcopy(data)
    probe['player'] = dict(hp=100000, stamina=0, spirit=0)
    probe['builds']['budget_probe'] = dict(items=[])
    b = ResourceObservedBattle(probe, 'budget_probe', enemy, trace=True, limit_ms=120000)
    result = b.run()
    paid = [r for r in b.log if r['event'] == 'activate' and r['side'] == 1 and r['cost'] > 0]
    assert paid and b.enemy_resource_stop is not None, enemy
    spent = sum(r['cost'] for r in paid)
    assert spent + result['enemy_stamina'] == data['enemies'][enemy]['stamina']
    assert not any(r['t'] > b.enemy_resource_stop for r in paid)
    attacks = [r for r in paid if data['items'][r['item']]['kind'] == 'attack']
    (out / f'probe_{label}_{enemy}.json').write_text(
        json.dumps(dict(result=result, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    return dict(stamina=data['enemies'][enemy]['stamina'],
                stop_seconds=b.enemy_resource_stop, last_attack_seconds=attacks[-1]['t'],
                stamina_remaining=result['enemy_stamina'], paid_activations=len(paid))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'artifacts' / 'balance-2026-09-13-enemy-stamina')
    args = parser.parse_args()
    data = json.loads(FIXTURE.read_text(encoding='utf-8-sig'))
    old = json.loads(PREVIOUS.read_text(encoding='utf-8-sig'))
    original_path = HERE / 'prologue_balance_20260913.json'
    original = json.loads(original_path.read_text(encoding='utf-8-sig'))
    checks = model_checks(original) + revision_checks(old, data)
    layouts = validate(data)
    args.out.mkdir(parents=True, exist_ok=True)
    rows, paired, sensitivity, budgets = [], [], [], []
    for build in data['builds']:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = ResourceObservedBattle(data, build, enemy, start, policy).run()
                    rows.append(r)
                    before = ResourceObservedBattle(old, build, enemy, start, policy).run()
                    pair = dict(build=build, enemy=enemy, start=start, policy=policy)
                    for field in ('outcome', 'seconds', 'hp', 'stamina', 'enemy_stamina',
                                  'map_rest_2x_seconds', 'enemy_cannot_fund_future_activations_at_s'):
                        pair['before_' + field] = before.get(field, '')
                        pair['after_' + field] = r.get(field, '')
                    paired.append(pair)
                    variants = [('enemy_first', dict(enemy_first=True))]
                    if enemy in ('boar', 'boss_spider'):
                        variants += [('one_bottle', dict(bottles=1)), ('no_medicine', dict(bottles=0))]
                    for label, options in variants:
                        s = ResourceObservedBattle(data, build, enemy, start, policy, **options).run()
                        s['variant'] = label
                        sensitivity.append(s)
    for enemy, definition in data['enemies'].items():
        row = dict(enemy=enemy, name=definition['name'], hp=definition['hp'])
        for label, fixture in [('before', old), ('after', data)]:
            row.update({label + '_' + k: v for k, v in resource_probe(fixture, enemy, args.out, label).items()})
        budgets.append(row)
    checks.append('16 isolated old/new enemy schedules conserve stamina and stop all paid activations')
    write_csv(args.out / 'baseline.csv', rows)
    write_csv(args.out / 'paired_before_after.csv', paired)
    write_csv(args.out / 'sensitivity.csv', sensitivity)
    write_csv(args.out / 'resource_budgets.csv', budgets)
    write_csv(args.out / 'stamina_changes.csv', data['current_revision_changes']['enemies'])
    for build, enemy, start, policy in [
        ('dual_bow_hammer_stamina', 'boss_spider', 'rested', 'manual'),
        ('dual_sword_bow_balanced', 'boss_spider', 'rested', 'manual'),
        ('single_bow_shield', 'boss_spider', 'rested', 'manual'),
        ('single_hammer_full', 'boss_spider', 'rested', 'manual'),
        ('triple_cloth_hp', 'turtle', 'rested', 'manual')]:
        b = ResourceObservedBattle(data, build, enemy, start, policy, trace=True)
        result = b.run()
        (args.out / f'trace_{build}_{enemy}_{start}_{policy}.json').write_text(
            json.dumps(dict(result=result, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in rows}
    changes = Counter(s['variant'] for s in sensitivity
                      if s['outcome'] != lookup[(s['build'], s['enemy'], s['start'], s['policy'])]['outcome'])
    summary = dict(checks=checks, layouts=layouts, baseline_count=len(rows),
                   baseline_outcomes=dict(Counter(r['outcome'] for r in rows)),
                   paired_count=len(paired),
                   paired_transitions=dict(Counter(r['before_outcome'] + ' -> ' + r['after_outcome'] for r in paired)),
                   sensitivity_count=len(sensitivity), resource_probe_count=16,
                   outcome_changes_by_variant=dict(changes), hashes={
                       p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                       [FIXTURE, PREVIOUS, original_path, Path(__file__),
                        HERE / 'prologue_balance_20260913.py', HERE / 'prologue_balance_20260913_pacing.py',
                        HERE / 'prologue_balance_20260913_recovery_hp.py']})
    (args.out / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k not in ('layouts', 'hashes')}, ensure_ascii=False, indent=2))
    print(json.dumps(budgets, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
