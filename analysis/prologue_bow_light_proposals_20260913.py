"""Unapproved bow/light-armor proposals, compared against the sixth-round fixture."""
from collections import Counter
import copy
import csv
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from prologue_balance_20260913 import write_csv
from prologue_balance_20260913_boss_recovery import BossRecoveryBattle

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURE = HERE / 'prologue_balance_20260913_matrix_bow9.json'
OUT = ROOT / 'artifacts' / 'balance-2026-09-13-bow-light-proposals'
BUILDS = ('sword_guard', 'bow_guard', 'hammer_guard',
          'dual_sword_bow_balanced', 'dual_sword_hammer_balanced', 'dual_bow_hammer_balanced',
          'dual_bow_hammer_stamina', 'single_hammer_full', 'single_bow_full')
VARIANTS = {
    'pierce_light_1.25': ('coefficient', '1.25'),
    'pierce_light_1.30': ('coefficient', '1.30'),
    'pierce_light_1.35': ('coefficient', '1.35'),
    'bow_cd_4s': ('cd_ms', 4000),
    'bow_damage_10': ('damage', 10),
    'bow_cost_4': ('stamina_cost', 4),
}


def main():
    data = json.loads(FIXTURE.read_text(encoding='utf-8'))
    initial_hash = hashlib.sha256(FIXTURE.read_bytes()).hexdigest()
    baseline_path = ROOT / 'artifacts' / 'balance-2026-09-13-matrix-bow9' / 'baseline.csv'
    with baseline_path.open(encoding='utf-8-sig', newline='') as f:
        lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in csv.DictReader(f)}
    rows, summary = [], {}
    for label, (field, value) in VARIANTS.items():
        d = copy.deepcopy(data)
        if field == 'coefficient':
            # A global matrix change: enemy piercing attacks also hit player cloth harder.
            d['damage_multipliers']['light']['pierce'] = value
            assert d['items'] == data['items']
        else:
            d['items']['trial.bow'][field] = value
            assert d['damage_multipliers'] == data['damage_multipliers']
        for k in ('enemies', 'builds', 'player'):
            assert d[k] == data[k]
        transitions = Counter()
        for build in BUILDS:
            for enemy in d['enemies']:
                for start in ('full', 'rested'):
                    for policy in ('auto', 'manual'):
                        r = BossRecoveryBattle(d, build, enemy, start, policy).run()
                        before = lookup[(build, enemy, start, policy)]
                        r['variant'] = label
                        for metric in ('outcome', 'seconds', 'hp', 'stamina', 'player_stamina_spent'):
                            r['baseline_' + metric] = before.get(metric, '0')
                        rows.append(r)
                        transitions[before['outcome'] + ' -> ' + r['outcome']] += 1
        summary[label] = dict(count=len(BUILDS) * 8 * 2 * 2, transitions=dict(transitions))
    # Check exact-time priority sensitivity for the smallest targeted adjustment.
    d = copy.deepcopy(data)
    d['damage_multipliers']['light']['pierce'] = '1.25'
    selected = {(r['build'], r['enemy'], r['start'], r['policy']): r
                for r in rows if r['variant'] == 'pierce_light_1.25'}
    sensitivity = []
    for key, before in selected.items():
        r = BossRecoveryBattle(d, *key, enemy_first=True).run()
        r['normal_priority_outcome'] = before['outcome']
        sensitivity.append(r)
    OUT.mkdir(parents=True, exist_ok=True)
    write_csv(OUT / 'proposals.csv', rows)
    write_csv(OUT / 'pierce125_enemy_first.csv', sensitivity)
    assert hashlib.sha256(FIXTURE.read_bytes()).hexdigest() == initial_hash
    verification = dict(status='all proposals unapproved; sixth-round data unchanged',
                        variants=VARIANTS, scenario_count=len(rows), summaries=summary,
                        enemy_first_count=len(sensitivity),
                        enemy_first_outcome_changes=sum(r['outcome'] != r['normal_priority_outcome'] for r in sensitivity),
                        hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                                (FIXTURE, baseline_path, Path(__file__),
                                 HERE / 'prologue_balance_20260913_boss_recovery.py',
                                 HERE / 'prologue_balance_20260913_pacing.py',
                                 HERE / 'prologue_balance_20260913.py')})
    (OUT / 'verification.json').write_text(json.dumps(verification, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in verification.items() if k != 'hashes'}, ensure_ascii=False, indent=2))
    for r in rows:
        if r['build'] == 'bow_guard' and r['start'] == 'rested' and r['policy'] == 'manual':
            print(r['variant'], r['enemy'], r['outcome'], r['seconds'], r['hp'], r['stamina'],
                  r.get('player_stamina_spent', 0))


if __name__ == '__main__':
    main()
