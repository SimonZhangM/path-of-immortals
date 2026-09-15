"""Third design experiment: confirmed stronger relic and +50% enemy HP."""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from prologue_balance_20260913 import F, model_checks, validate, write_csv
from prologue_balance_20260913_pacing import ObservedBattle, meditation

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURE = Path(__file__).with_suffix('.json')
PREVIOUS = HERE / 'prologue_balance_20260913_pacing.json'


class ResourceObservedBattle(ObservedBattle):
    def __init__(self, *args, **kwargs):
        self.enemy_resource_stop = None
        super().__init__(*args, **kwargs)
        costs = [F(i.d.get('stamina_cost', 0)) for i in self.sides[1].items]
        self.enemy_min_cost = min((c for c in costs if c > 0), default=None)

    def emit(self, event, side=None, item=None, **values):
        if (event == 'activate' and side == 1 and self.enemy_min_cost is not None
                and self.sides[1].stamina < self.enemy_min_cost and self.enemy_resource_stop is None):
            # The activation currently resolving and already applied poison may
            # still deal damage; this marks inability to fund FUTURE activations.
            self.enemy_resource_stop = self.now / 1000
        super().emit(event, side, item, **values)

    def run(self):
        result = super().run()
        result['enemy_cannot_fund_future_activations_at_s'] = (
            self.enemy_resource_stop if self.enemy_resource_stop is not None else '')
        result['seconds_after_enemy_resource_stop'] = (
            result['seconds'] - self.enemy_resource_stop if self.enemy_resource_stop is not None else 0)
        return result


def revision_checks(old, data):
    assert (27 * 3 + 1) // 2 == 41
    for ident, enemy in data['enemies'].items():
        prior = old['enemies'][ident]
        assert enemy['hp'] == (prior['hp'] * 3 + 1) // 2, ident
        assert {k: v for k, v in enemy.items() if k != 'hp'} == {
            k: v for k, v in prior.items() if k != 'hp'}, ident
    for ident, item in data['items'].items():
        prior = old['items'][ident]
        if ident != 'trial.relic':
            assert item == prior, ident
        else:
            assert (item['cd_ms'], item['hp_gain'], item['stamina_gain'], item['cap_ratio']) == (
                4000, 4, 6, '2/3')
            assert {k: v for k, v in item.items() if k not in ('cd_ms', 'hp_gain', 'stamina_gain')} == {
                k: v for k, v in prior.items() if k not in ('cd_ms', 'hp_gain', 'stamina_gain')}
    assert data['enemies']['turtle']['hp'] == 51  # Never promote unapproved 50/70 probes.
    assert data['player'] == old['player'] and data['builds'] == old['builds']
    assert data['damage_multipliers'] == old['damage_multipliers']
    b = ResourceObservedBattle(data, 'dual_sword_bow_balanced', 'wolf', trace=True, limit_ms=4000)
    b.sides[0].hp, b.sides[0].stamina = F(20), F(10)
    b.run()
    restores = [r for r in b.log if r['event'] == 'restore' and r['item'] == 'relic']
    assert [(r['resource'], r['gain'], r['t']) for r in restores] == [('hp', 4.0, 4.0), ('stamina', 6.0, 4.0)]
    b = ResourceObservedBattle(data, 'dual_sword_bow_balanced', 'wolf')
    p = b.sides[0]
    p.hp, p.stamina = F(32), F(45)
    b.activate(next(i for i in p.items if i.id == 'trial.relic'))
    assert p.hp == F(100, 3) and p.stamina == 45
    rest = meditation(1, 0, 50, 50, data['items']['trial.relic'])
    assert (rest['ticks'], rest['seconds']) == (5, 20)
    assert rest['hp'] == float(F(100, 3)) and rest['stamina'] == float(F(100, 3))
    same_deficit = meditation(F(145, 12), F(52, 3), 50, 50, data['items']['trial.relic'])
    assert same_deficit['seconds'] == 12
    return ['+50% HP once with integer ceiling, including 40.5 -> 41; turtle 34 -> 51',
            'only relic 4s/4HP/6stamina and enemy HP changed; all other fields preserved',
            'battle relic is 4HP/6stamina, respects cap and never lowers high resources',
            'map doubling only: worst modeled post-defeat deficit takes 20s; prior 49.5s deficit takes 12s']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'artifacts' / 'balance-2026-09-13-recovery-hp')
    args = parser.parse_args()
    data = json.loads(FIXTURE.read_text(encoding='utf-8-sig'))
    old = json.loads(PREVIOUS.read_text(encoding='utf-8-sig'))
    original_path = HERE / 'prologue_balance_20260913.json'
    original = json.loads(original_path.read_text(encoding='utf-8-sig'))
    checks, layouts = model_checks(original) + revision_checks(old, data), validate(data)
    args.out.mkdir(parents=True, exist_ok=True)
    rows, paired, sensitivity = [], [], []
    for build in data['builds']:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = ResourceObservedBattle(data, build, enemy, start, policy).run()
                    rows.append(r)
                    before = ResourceObservedBattle(old, build, enemy, start, policy).run()
                    paired.append(dict(build=build, enemy=enemy, start=start, policy=policy,
                                       before_outcome=before['outcome'], after_outcome=r['outcome'],
                                       before_seconds=before['seconds'], after_seconds=r['seconds'],
                                       before_hp=before['hp'], after_hp=r['hp'],
                                       before_stamina=before['stamina'], after_stamina=r['stamina'],
                                       before_map_rest=before.get('map_rest_2x_seconds', ''),
                                       after_map_rest=r.get('map_rest_2x_seconds', '')))
                    s = ResourceObservedBattle(data, build, enemy, start, policy, enemy_first=True).run()
                    s['variant'] = 'enemy_first'
                    sensitivity.append(s)
                    if enemy in ('boar', 'boss_spider'):
                        for label, bottles in [('one_bottle', 1), ('no_medicine', 0)]:
                            s = ResourceObservedBattle(data, build, enemy, start, policy, bottles=bottles).run()
                            s['variant'] = label
                            sensitivity.append(s)
    # Small causal comparison; these are counterfactuals, not suggested settings.
    for variant in ('hp_only', 'relic_only'):
        probe = copy.deepcopy(old)
        if variant == 'hp_only':
            probe['enemies'] = copy.deepcopy(data['enemies'])
        else:
            probe['items']['trial.relic'] = copy.deepcopy(data['items']['trial.relic'])
        for build in ('dual_sword_bow_balanced', 'dual_bow_hammer_stamina', 'triple_cloth_relic', 'hammer_guard'):
            for enemy in ('boar', 'boss_spider'):
                for start in ('full', 'rested'):
                    s = ResourceObservedBattle(probe, build, enemy, start, 'manual').run()
                    s['variant'] = variant
                    sensitivity.append(s)
    write_csv(args.out / 'baseline.csv', rows)
    write_csv(args.out / 'paired_before_after.csv', paired)
    write_csv(args.out / 'sensitivity.csv', sensitivity)
    write_csv(args.out / 'hp_changes.csv', data['current_revision_changes']['enemies'])
    for build, enemy, start, policy in [
        ('dual_bow_hammer_stamina', 'boss_spider', 'rested', 'manual'),
        ('triple_cloth_relic', 'boss_spider', 'rested', 'manual'),
        ('hammer_guard', 'turtle', 'rested', 'manual'),
        ('single_hammer_full', 'boss_spider', 'rested', 'auto')]:
        b = ResourceObservedBattle(data, build, enemy, start, policy, trace=True)
        r = b.run()
        (args.out / f'trace_{build}_{enemy}_{start}_{policy}.json').write_text(
            json.dumps(dict(result=r, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in rows}
    changes = Counter()
    for s in sensitivity:
        if s['outcome'] != lookup[(s['build'], s['enemy'], s['start'], s['policy'])]['outcome']:
            changes[s['variant']] += 1
    summary = dict(checks=checks, layouts=layouts, baseline_count=len(rows),
                   baseline_outcomes=dict(Counter(r['outcome'] for r in rows)),
                   paired_count=len(paired), sensitivity_count=len(sensitivity),
                   outcome_changes_by_variant=dict(changes), hashes={
                       p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                       [FIXTURE, PREVIOUS, original_path, Path(__file__),
                        HERE / 'prologue_balance_20260913.py', HERE / 'prologue_balance_20260913_pacing.py']})
    (args.out / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k not in ('layouts', 'hashes')}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
