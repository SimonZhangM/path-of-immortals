"""Fifth isolated design experiment: conditional Boss recovery and weapon matchups.

The frozen event simulation remains unchanged. This observer adds a gated relic
through existing item events, and distinguishes temporary shortages from permanent
resource exhaustion. All timing uses simulation milliseconds and exact fractions.
"""
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
from prologue_balance_20260913_pacing import ObservedBattle
from prologue_balance_20260913_recovery_hp import ResourceObservedBattle

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURE = Path(__file__).with_suffix('.json')
PREVIOUS = HERE / 'prologue_balance_20260913_enemy_stamina.json'
RELIC = 'trial.boss.stamina_relic'


class BossRecoveryBattle(ObservedBattle):
    def __init__(self, *args, **kwargs):
        self.budget_initialized = False
        self.low_since = None
        self.resource_gaps = []
        super().__init__(*args, **kwargs)
        costs = [F(i.d.get('stamina_cost', 0)) for i in self.sides[1].items]
        self.enemy_min_cost = min((c for c in costs if c > 0), default=None)
        self.enemy_has_recovery = any(i.d.get('conditional_stamina') for i in self.sides[1].items)
        self.budget_initialized = True

    def enabled(self, item):
        s = self.sides[item.side]
        return s.stamina <= s.stamina_cap * F(item.d['threshold_ratio'])

    def schedule(self, item, at):
        if item.d.get('conditional_stamina') and not self.enabled(item):
            item.version += 1
            item.due, item.ready = None, False
            return
        super().schedule(item, at)

    def sync_relics(self):
        if self.outcome:
            return
        for side in self.sides:
            for item in side.items:
                if not item.d.get('conditional_stamina'):
                    continue
                if not self.enabled(item):
                    if item.due is not None:
                        item.version += 1
                        item.due = None
                        self.emit('boss_relic_disabled', item.side, item.id)
                elif item.due is None:
                    self.schedule(item, self.now + item.d['cd_ms'])
                    self.emit('boss_relic_started', item.side, item.id, due=item.due / 1000)

    def restore(self, *args, **kwargs):
        super().restore(*args, **kwargs)
        self.sync_relics()

    def activate(self, item):
        if not item.d.get('conditional_stamina'):
            super().activate(item)
            self.sync_relics()
            return
        item.due = None
        if not self.enabled(item):
            item.version += 1
            self.emit('boss_relic_disabled', item.side, item.id)
            return
        state = self.sides[item.side]
        state.stats['activations_relic'] += 1
        self.emit('activate', item.side, item.id, cost=0.0)
        # Full +2 can cross the threshold; only the normal maximum caps a gain.
        super().restore(item.side, 'stamina', item.d['stamina_gain'], source='boss_relic')
        if self.enabled(item):
            self.schedule(item, self.now + item.d['cd_ms'])
        else:
            item.version += 1
            self.emit('boss_relic_disabled', item.side, item.id)

    def emit(self, event, side=None, item=None, **values):
        if self.budget_initialized and side == 1 and event in ('activate', 'restore'):
            low = self.enemy_min_cost is not None and self.sides[1].stamina < self.enemy_min_cost
            if low and self.low_since is None:
                self.low_since = self.now
            elif not low and self.low_since is not None:
                self.resource_gaps.append((self.low_since, self.now))
                self.low_since = None
        super().emit(event, side, item, **values)

    def run(self):
        result = super().run()
        gaps = self.resource_gaps + ([(self.low_since, self.now)] if self.low_since is not None else [])
        result.update(
            enemy_has_stamina_recovery=self.enemy_has_recovery,
            enemy_resource_shortage_count=len(gaps),
            enemy_first_resource_shortage_s=gaps[0][0] / 1000 if gaps else '',
            enemy_resource_shortage_seconds=sum(b - a for a, b in gaps) / 1000,
            enemy_longest_resource_shortage_seconds=max((b - a for a, b in gaps), default=0) / 1000,
            enemy_resource_resumptions=len(self.resource_gaps),
            enemy_permanent_resource_stop_at_s=(
                self.low_since / 1000 if self.low_since is not None and not self.enemy_has_recovery else ''))
        return result


def revision_checks(old, data):
    assert data['enemies']['gray_spider']['stamina'] == 61
    for ident, enemy in data['enemies'].items():
        expected = copy.deepcopy(old['enemies'][ident])
        if ident == 'gray_spider':
            expected['stamina'] += 10
        if ident in ('boar', 'boss_spider'):
            expected['items'].append(RELIC)
        assert enemy == expected, ident
    cds = {'trial.sword': 3500, 'trial.bow': 4500, 'trial.hammer': 4000}
    for ident, prior in old['items'].items():
        expected = copy.deepcopy(prior)
        if ident in cds:
            expected['cd_ms'] = cds[ident]
        assert data['items'][ident] == expected, ident
    matrix = copy.deepcopy(old['damage_multipliers'])
    for c in data['current_revision_changes']['coefficient_changes']:
        assert matrix[c['armor']][c['attack']] == c['before']
        matrix[c['armor']][c['attack']] = c['after']
    assert data['damage_multipliers'] == matrix
    assert data['player'] == old['player'] and data['builds'] == old['builds']
    return ['only gray spider +10, two Boss relics, approved CDs and matrix entries changed']


def gated_checks(data):
    checks = []

    def probe(cost=None, cd=1500, limit=7000, cap=105, initial=71):
        d = copy.deepcopy(data)
        d['player'] = dict(hp=100000, stamina=0, spirit=0)
        d['builds']['test'] = dict(items=[])
        ids = []
        if cost is not None:
            d['items']['trial.test.spend'] = dict(kind='attack', cd_ms=cd, stamina_cost=cost,
                                                area=1, shape=[1, 1], damage=0, attack_type='slash')
            ids.append('trial.test.spend')
        ids.append(RELIC)
        d['enemies']['test'] = dict(hp=100, stamina=cap, items=ids)
        b = BossRecoveryBattle(d, 'test', 'test', trace=True, limit_ms=limit)
        b.sides[1].stamina = F(initial)
        return b

    b = probe()
    assert all(i.due is None for i in b.sides[1].items)
    b.run()
    assert not [r for r in b.log if r['event'] == 'restore']
    checks.append('above threshold: no recovery and no prewarmed cooldown')

    b = probe(initial=70, limit=2000)
    b.sync_relics()
    assert b.sides[1].items[0].due == 2000
    b.run()
    assert b.sides[1].stamina == 72 and b.sides[1].items[0].due is None
    checks.append('exact 2/3 enables a full 2s wait; +2 crosses threshold then clears CD')

    b = probe(cost=1)
    b.run()
    assert [r['t'] for r in b.log if r['event'] == 'restore'] == [3.5, 6.5]
    assert [(r['t'], r['due']) for r in b.log if r['event'] == 'boss_relic_started'] == [(1.5, 3.5), (4.5, 6.5)]
    checks.append('inactive reset/re-entry; spending while enabled preserves progress')

    b = probe(cap=98, initial=65, limit=2000)
    b.sync_relics()
    b.run()
    assert b.sides[1].stamina == 67
    checks.append('fractional threshold 196/3 stays exact; gain not clamped at 2/3')

    b = probe(cost=3, cd=2000, initial=1, limit=2000)
    b.sync_relics()
    r = b.run()
    assert r['enemy_activations_attack'] == 1 and r.get('enemy_empty_attack', 0) == 0
    checks.append('same-time Boss recovery pays the attack before resource consumption')

    b = probe(cost=3, cd=2000, initial=1, limit=4000)
    b.now = 100
    b.sync_relics()
    r = b.run()
    assert [(e['t'], e['event']) for e in b.log if e['item'] == 'trial.test.spend'
            and e['event'] in ('activate', 'empty_rotation')] == [(2.0, 'empty_rotation'), (4.0, 'activate')]
    assert r['enemy_resource_resumptions'] == 1 and r['enemy_permanent_resource_stop_at_s'] == ''
    checks.append('100ms-late recovery skips full attack CD; temporary shortage is not permanent exhaustion')

    # These categories are not present in ordinary prologue fights; verify hits directly.
    for armor in ('none', 'light', 'heavy', 'spiritual'):
        for attack in ('pierce', 'slash', 'blunt', 'spell'):
            b = probe()
            target = b.sides[1]
            target.armor_type, target.armor = armor, F(3)
            before = target.hp
            b.hit(1, 10, attack)
            assert before - target.hp == F(10) * F(data['damage_multipliers'][armor][attack]) - 3
    checks.append('all 16 attack/armor coefficients applied before consumable armor, including spell/spiritual')
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'artifacts' / 'balance-2026-09-13-boss-recovery')
    args = parser.parse_args()
    data = json.loads(FIXTURE.read_text(encoding='utf-8-sig'))
    old = json.loads(PREVIOUS.read_text(encoding='utf-8-sig'))
    original_path = HERE / 'prologue_balance_20260913.json'
    original = json.loads(original_path.read_text(encoding='utf-8-sig'))
    checks = model_checks(original) + revision_checks(old, data) + gated_checks(data)
    layouts = validate(data)
    args.out.mkdir(parents=True, exist_ok=True)
    rows, paired, sensitivity, budgets = [], [], [], []
    for build in data['builds']:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = BossRecoveryBattle(data, build, enemy, start, policy).run()
                    rows.append(r)
                    before = ResourceObservedBattle(old, build, enemy, start, policy).run()
                    compatible = BossRecoveryBattle(old, build, enemy, start, policy).run()
                    for field in ('outcome', 'seconds', 'hp', 'stamina', 'enemy_hp', 'enemy_stamina'):
                        assert before[field] == compatible[field], (build, enemy, field)
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
    checks.append('new subclass reproduces old model outcomes/time/resources in all 1120 old-fixture scenarios')
    # Attribute changes without promoting any counterfactual to the approved input.
    for label in ('no_boss_relic', 'old_matrix', 'old_weapon_cds'):
        d = copy.deepcopy(data)
        if label == 'no_boss_relic':
            for e in ('boar', 'boss_spider'):
                d['enemies'][e]['items'].remove(RELIC)
        elif label == 'old_matrix':
            d['damage_multipliers'] = copy.deepcopy(old['damage_multipliers'])
        else:
            for i in ('trial.sword', 'trial.bow', 'trial.hammer'):
                d['items'][i]['cd_ms'] = old['items'][i]['cd_ms']
        for build in ('sword_guard', 'bow_guard', 'hammer_guard', 'dual_sword_bow_balanced',
                      'dual_sword_hammer_balanced', 'dual_bow_hammer_stamina',
                      'single_hammer_full', 'single_bow_shield'):
            for enemy in ('boar', 'boss_spider'):
                for start in ('full', 'rested'):
                    s = BossRecoveryBattle(d, build, enemy, start, 'manual').run()
                    s['variant'] = label
                    sensitivity.append(s)
    for enemy in data['enemies']:
        d = copy.deepcopy(data)
        d['player'] = dict(hp=100000, stamina=0, spirit=0)
        d['builds']['budget_probe'] = dict(items=[])
        b = BossRecoveryBattle(d, 'budget_probe', enemy, trace=True)
        r = b.run()
        regen = r.get('enemy_boss_relic_stamina_restored', 0)
        assert abs(d['enemies'][enemy]['stamina'] + regen - r['enemy_stamina_spent'] - r['enemy_stamina']) < 1e-8
        paid = [e for e in b.log if e['event'] == 'activate' and e['side'] == 1 and e.get('cost', 0) > 0]
        last_attack = [e for e in paid if d['items'][e['item']]['kind'] == 'attack'][-1]['t']
        r['last_attack_seconds'] = last_attack
        if enemy in ('boar', 'boss_spider'):
            assert last_attack >= 295 and r['enemy_permanent_resource_stop_at_s'] == ''
        budgets.append(r)
        (args.out / f'probe_{enemy}.json').write_text(
            json.dumps(dict(result=r, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    checks.append('all 8 resource probes conserve stamina; Boss attacks continue through 300s with intermittent shortages')
    write_csv(args.out / 'baseline.csv', rows)
    write_csv(args.out / 'paired_before_after.csv', paired)
    write_csv(args.out / 'sensitivity.csv', sensitivity)
    write_csv(args.out / 'resource_budgets.csv', budgets)
    write_csv(args.out / 'exhausted_victories.csv', [r for r in rows if r['outcome'] == 'victory'
              and r['enemy_permanent_resource_stop_at_s'] != '' and r['seconds'] > r['enemy_permanent_resource_stop_at_s']])
    for build, enemy, policy in [
        ('sword_guard', 'wolf', 'manual'), ('bow_guard', 'wolf', 'manual'),
        ('dual_bow_hammer_stamina', 'boss_spider', 'manual'),
        ('single_bow_shield', 'boss_spider', 'manual'),
        ('single_hammer_full', 'boss_spider', 'manual'),
        ('hammer_guard', 'boar', 'manual')]:
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
                   sensitivity_count=len(sensitivity), resource_probe_count=len(budgets),
                   outcome_changes_by_variant=dict(changes), hashes={
                       p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in
                       [FIXTURE, PREVIOUS, original_path, Path(__file__),
                        HERE / 'prologue_balance_20260913.py', HERE / 'prologue_balance_20260913_pacing.py',
                        HERE / 'prologue_balance_20260913_recovery_hp.py']})
    (args.out / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k not in ('layouts', 'hashes')}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
