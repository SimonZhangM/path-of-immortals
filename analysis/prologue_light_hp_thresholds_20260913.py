"""Unapproved HP-only probes: one fewer bow shot while preserving sword timing."""
from collections import Counter
import copy
import csv
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from prologue_balance_20260913 import F, write_csv
from prologue_balance_20260913_boss_recovery import BossRecoveryBattle

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'analysis' / 'prologue_balance_20260913_matrix_bow9.json'
OUT = ROOT / 'artifacts' / 'balance-2026-09-13-light-hp-thresholds'


def before_last_hit(data, build, enemy):
    b = BossRecoveryBattle(data, build, enemy, 'rested', 'manual', trace=True)
    result = b.run()
    assert result['outcome'] == 'victory'
    hits = [r for r in b.log if r['event'] == 'activate' and r['side'] == 0
            and b.data['items'][r['item']]['kind'] == 'attack']
    stop_ms = int(F(str(hits[-2]['t'])) * 1000)
    p = BossRecoveryBattle(data, build, enemy, 'rested', 'manual', limit_ms=stop_ms)
    p.run()
    threshold = F(data['enemies'][enemy]['hp']) - p.sides[1].hp
    absorbed = p.sides[1].stats['armor_absorbed']
    return dict(original_hits=len(hits), preceding_hits=len(hits) - 1,
                preceding_hit_time_s=stop_ms / 1000, cumulative_hp_damage=str(threshold),
                cumulative_armor_absorbed=str(absorbed), final_hit_time_s=hits[-1]['t'])


def main():
    data = json.loads(FIXTURE.read_text(encoding='utf-8'))
    initial_hash = hashlib.sha256(FIXTURE.read_bytes()).hexdigest()
    baseline_path = ROOT / 'artifacts' / 'balance-2026-09-13-matrix-bow9' / 'baseline.csv'
    with baseline_path.open(encoding='utf-8-sig', newline='') as f:
        baseline = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in csv.DictReader(f)}
    thresholds = {}
    for enemy in ('bird', 'gray_spider'):
        thresholds[enemy] = {weapon: before_last_hit(data, weapon + '_guard', enemy)
                             for weapon in ('sword', 'bow')}
    assert F(thresholds['bird']['bow']['cumulative_hp_damage']) == 5 * 9 * F('1.20') - 8 == 46
    assert F(thresholds['bird']['sword']['cumulative_hp_damage']) == 7 * 7 * F('1.05') - 8 == F('43.45')
    assert F(thresholds['gray_spider']['bow']['cumulative_hp_damage']) == 6 * 9 * F('1.20') - 10 == F('54.8')
    assert F(thresholds['gray_spider']['sword']['cumulative_hp_damage']) == 9 * 7 * F('1.05') - 12 == F('54.15')
    hp_samples = {'bird': ['48', '47', '46', '45', '44', '43.5', '43.45', '43'],
                  'gray_spider': ['57', '56', '55', '54.9', '54.8', '54.5', '54.2', '54.15', '54', '53']}
    boundaries, paired, sensitivity = [], [], []
    for enemy, values in hp_samples.items():
        for hp in values:
            d = copy.deepcopy(data)
            d['enemies'][enemy]['hp'] = F(hp)
            for build in ('sword_guard', 'bow_guard', 'hammer_guard'):
                for start in ('full', 'rested'):
                    for policy in ('auto', 'manual'):
                        r = BossRecoveryBattle(d, build, enemy, start, policy).run()
                        r['candidate_enemy_hp'] = hp
                        boundaries.append(r)
    for enemy, hp in [('bird', '46'), ('gray_spider', '54'), ('gray_spider', '54.5'), ('gray_spider', '54.8')]:
        d = copy.deepcopy(data)
        d['enemies'][enemy]['hp'] = F(hp)
        for build in data['builds']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    before = baseline[(build, enemy, start, policy)]
                    r = BossRecoveryBattle(d, build, enemy, start, policy).run()
                    r['candidate_enemy_hp'] = hp
                    changed = []
                    for field in ('outcome', 'seconds', 'hp', 'stamina', 'player_activations_attack', 'player_stamina_spent'):
                        r['baseline_' + field] = before.get(field, '0')
                        equal = (r[field] == before[field] if field == 'outcome'
                                 else abs(float(r.get(field, 0)) - float(before.get(field) or 0)) < 1e-8)
                        if not equal:
                            changed.append(field)
                    r['changed_fields'] = ','.join(changed)
                    paired.append(r)
                    if build in ('sword_guard', 'bow_guard', 'hammer_guard'):
                        s = BossRecoveryBattle(d, build, enemy, start, policy, enemy_first=True).run()
                        s['candidate_enemy_hp'] = hp
                        s['normal_priority_outcome'] = r['outcome']
                        sensitivity.append(s)
    # Feasible HP intervals preserve the ordinary single-sword finishing hit.
    for enemy, bounds in thresholds.items():
        lower = F(bounds['sword']['cumulative_hp_damage'])
        upper = F(bounds['bow']['cumulative_hp_damage'])
        bounds['feasible_hp_exclusive_inclusive'] = [str(lower), str(upper)]
        bounds['feasible_integer_hp'] = list(range(lower.numerator // lower.denominator + 1,
                                                  upper.numerator // upper.denominator + 1))
    assert thresholds['bird']['feasible_integer_hp'] == [44, 45, 46]
    assert thresholds['gray_spider']['feasible_integer_hp'] == []
    assert hashlib.sha256(FIXTURE.read_bytes()).hexdigest() == initial_hash
    OUT.mkdir(parents=True, exist_ok=True)
    write_csv(OUT / 'boundary_probes.csv', boundaries)
    write_csv(OUT / 'all_builds_before_after.csv', paired)
    write_csv(OUT / 'single_weapon_enemy_first.csv', sensitivity)
    summary = dict(status='calculation only; approved HP still bird48 and gray_spider57',
                   thresholds=thresholds, boundary_count=len(boundaries), paired_count=len(paired),
                   enemy_first_count=len(sensitivity),
                   enemy_first_outcome_changes=sum(r['outcome'] != r['normal_priority_outcome'] for r in sensitivity),
                   changed_scenarios=dict(Counter(r['enemy'] + '_' + r['candidate_enemy_hp']
                                                  for r in paired if r['changed_fields'])),
                   hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                           (FIXTURE, baseline_path, Path(__file__),
                            ROOT / 'analysis/prologue_balance_20260913_boss_recovery.py',
                            ROOT / 'analysis/prologue_balance_20260913_pacing.py',
                            ROOT / 'analysis/prologue_balance_20260913.py')})
    (OUT / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k != 'hashes'}, ensure_ascii=False, indent=2))
    for r in paired:
        if r['build'] in ('sword_guard', 'bow_guard', 'hammer_guard', 'dual_sword_hammer_balanced') and r['start'] == 'rested' and r['policy'] == 'manual':
            print(r['enemy'], r['candidate_enemy_hp'], r['build'], r['outcome'], r['seconds'],
                  r['hp'], r['stamina'], r['player_activations_attack'], r['changed_fields'])


if __name__ == '__main__':
    main()
