"""Pacing revision experiment. Reuses the previous isolated combat model unchanged."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from math import ceil
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from prologue_balance_20260913 import Battle, F, model_checks, validate, write_csv

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURE = HERE / 'prologue_balance_20260913_pacing.json'
BASE_FIXTURE = HERE / 'prologue_balance_20260913.json'


def meditation(hp, stamina, hp_cap, stamina_cap, relic, amount_multiplier=2):
    """Map-only recovery estimate; full first rotation, no medicines or preloaded armor."""
    values = {'hp': F(hp), 'stamina': F(stamina)}
    ceilings = {'hp': F(hp_cap) * F(relic['cap_ratio']),
                'stamina': F(stamina_cap) * F(relic['cap_ratio'])}
    gains = {resource: F(relic[resource + '_gain']) * amount_multiplier
             for resource in values}
    ticks = max(ceil(max(F(0), ceilings[k] - values[k]) / gains[k]) for k in values)
    restored = {k: values[k] + min(max(F(0), ceilings[k] - values[k]), ticks * gains[k])
                for k in values}
    return {'ticks': ticks, 'seconds': ticks * relic['cd_ms'] / 1000,
            'hp': float(restored['hp']), 'stamina': float(restored['stamina'])}


class ObservedBattle(Battle):
    def __init__(self, *args, **kwargs):
        self.attack_times = [[], []]
        super().__init__(*args, **kwargs)

    def emit(self, event, side=None, item=None, **values):
        if event == 'activate' and self.data['items'][item]['kind'] == 'attack':
            self.attack_times[side].append(self.now)
        super().emit(event, side, item, **values)

    def run(self):
        result = super().run()
        for side, prefix in enumerate(('player_', 'enemy_')):
            times = self.attack_times[side]
            distinct = sorted(set(times))
            result[prefix + 'attack_bursts'] = len(distinct)
            result[prefix + 'max_simultaneous_attacks'] = max(Counter(times).values(), default=0)
            result[prefix + 'mean_burst_gap_s'] = (
                (distinct[-1] - distinct[0]) / (1000 * (len(distinct) - 1))
                if len(distinct) > 1 else '')
        if 'trial.relic' in self.data['builds'][self.build]['items']:
            p = self.sides[0]
            hp = F(1) if self.outcome == 'defeat' else p.hp
            for mult in (1, 2):
                rest = meditation(hp, p.stamina, p.hp_cap, p.stamina_cap,
                                  self.data['items']['trial.relic'], mult)
                result[f'map_rest_{mult}x_seconds'] = rest['seconds']
        return result


def revision_checks(old, new):
    explicit = {'trial.cloth': 4000, 'trial.helmet': 5000, 'trial.sword': 3000,
                'trial.bow': 5000, 'trial.hammer': 4000, 'trial.rat.tooth': 3500,
                'trial.rat.claw': 3000, 'trial.rat.tail': 4500}
    assert (2100 // 500 + 1) * 500 == 2500
    assert (3600 // 500 + 1) * 500 == 4000
    assert (3500 // 500 + 1) * 500 == 4000
    assert (4000 // 500 + 1) * 500 == 4500
    for ident, prior in old['items'].items():
        current = new['items'][ident]
        assert current['cd_ms'] == explicit.get(ident, (prior['cd_ms'] // 500 + 1) * 500), ident
        allowed = {'cd_ms', 'shape', 'area'} if ident == 'trial.cloth' else {'cd_ms'}
        assert {k: v for k, v in prior.items() if k not in allowed} == {
            k: v for k, v in current.items() if k not in allowed}, ident
    assert new['enemies'] == old['enemies']
    assert new['player'] == old['player']
    assert new['damage_multipliers'] == old['damage_multipliers']
    assert new['items']['trial.cloth']['shape'] == [1, 2]
    assert new['items']['trial.cloth']['area'] == 2
    for build in new['builds'].values():
        if build.get('new_full_profile'):
            assert sum(new['items'][i]['area'] for i in build['items']) == 9
    relic = new['items']['trial.relic']
    rest = meditation(1, 0, 50, 50, relic)
    assert rest['ticks'] == 17 and rest['seconds'] == 76.5
    assert rest['hp'] == float(F(100, 3)) and rest['stamina'] == float(F(100, 3))
    assert meditation(50, 50, 50, 50, relic)['seconds'] == 0
    mixed = meditation(50, 0, 50, 50, relic)
    assert mixed['hp'] == 50 and mixed['ticks'] == 9 and mixed['seconds'] == 40.5
    battle = ObservedBattle(new, 'dual_sword_bow_balanced', 'wolf', trace=True, limit_ms=4500)
    battle.sides[0].hp = F(10)
    battle.sides[0].stamina = F(10)
    battle.run()
    restores = [e for e in battle.log if e['event'] == 'restore' and e['item'] == 'relic']
    assert [(r['resource'], r['gain']) for r in restores] == [('hp', 1.0), ('stamina', 2.0)]
    return ['strict next 500 ms once, explicit overrides preserved',
            'all other item fields and enemy resources unchanged',
            'cloth is 1x2; 20 additional profiles fill exactly nine cells',
            'map-only doubled amounts, unchanged independent caps and cooldown',
            'battle relic still restores one HP and two stamina per activation']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'artifacts' / 'balance-2026-09-13-pacing')
    args = parser.parse_args()
    old = json.loads(BASE_FIXTURE.read_text(encoding='utf-8-sig'))
    data = json.loads(FIXTURE.read_text(encoding='utf-8-sig'))
    checks = model_checks(old) + revision_checks(old, data)
    layouts = validate(data)
    args.out.mkdir(parents=True, exist_ok=True)
    rows, paired, sensitivity = [], [], []
    for build in data['builds']:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = ObservedBattle(data, build, enemy, start, policy).run()
                    rows.append(r)
                    # Coarser authored CDs increase coincident attacks: test both sides
                    # first for all eight enemies, rather than assuming ordering is harmless.
                    s = ObservedBattle(data, build, enemy, start, policy, enemy_first=True).run()
                    s['variant'] = 'enemy_first'
                    sensitivity.append(s)
                    if build in old['builds']:
                        before = ObservedBattle(old, build, enemy, start, policy).run()
                        paired.append(dict(build=build, enemy=enemy, start=start, policy=policy,
                                           before_outcome=before['outcome'], after_outcome=r['outcome'],
                                           before_seconds=before['seconds'], after_seconds=r['seconds'],
                                           before_hp=before['hp'], after_hp=r['hp'],
                                           before_stamina=before['stamina'], after_stamina=r['stamina']))
                    if enemy in ('boar', 'boss_spider'):
                        for label, options in [
                            ('one_bottle', dict(bottles=1)),
                            ('later_medicine', dict(first_pill_extra_ms=3000)),
                            ('poison_last', dict(poison_first=False))]:
                            s = ObservedBattle(data, build, enemy, start, policy, **options).run()
                            s['variant'] = label
                            sensitivity.append(s)
    write_csv(args.out / 'baseline.csv', rows)
    write_csv(args.out / 'paired_before_after.csv', paired)
    write_csv(args.out / 'sensitivity.csv', sensitivity)
    write_csv(args.out / 'cd_changes.csv', data['changes'])
    traces = [('dual_sword_bow_balanced', 'boar', 'rested', 'manual'),
              ('dual_sword_hammer_antidote', 'boss_spider', 'rested', 'manual'),
              ('triple_cloth_relic', 'boss_spider', 'rested', 'manual'),
              ('sword_guard', 'rat', 'rested', 'manual'),
              ('single_hammer_full', 'boss_spider', 'rested', 'auto')]
    for build, enemy, start, policy in traces:
        b = ObservedBattle(data, build, enemy, start, policy, trace=True)
        result = b.run()
        (args.out / f'trace_{build}_{enemy}_{start}_{policy}.json').write_text(
            json.dumps(dict(result=result, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in rows}
    differences = Counter()
    for s in sensitivity:
        r = lookup[(s['build'], s['enemy'], s['start'], s['policy'])]
        if s['outcome'] != r['outcome']:
            differences[s['variant']] += 1
    summary = dict(checks=checks, layouts=layouts, baseline_count=len(rows),
                   baseline_outcomes=dict(Counter(r['outcome'] for r in rows)),
                   paired_count=len(paired), sensitivity_count=len(sensitivity),
                   outcome_changes_by_variant=dict(differences),
                   hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                           [FIXTURE, BASE_FIXTURE, Path(__file__), HERE / 'prologue_balance_20260913.py']})
    (args.out / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k not in ('layouts', 'hashes')}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
