"""Standalone design experiment; no Godot runtime dependency. Python standard library.

Run from any directory: python analysis/prologue_balance_20260913.py
Authored trial content is in the adjacent JSON. See the dated report for assumptions.
"""
from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import heapq
import json
import random
from collections import Counter
from dataclasses import dataclass, field
from fractions import Fraction as F
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = Path(__file__).with_suffix('.json')


def factor(area):
    return 1 + F(5, 100) * max(area - 2, 0)


def fit(shapes, occupied=0):
    """Return one legal 3x3 layout (rotation allowed), or None."""
    if not shapes:
        return []
    w, h = shapes[0]
    for a, b in sorted({(w, h), (h, w)}):
        for y in range(4 - b):
            for x in range(4 - a):
                mask = sum(1 << (3 * yy + xx)
                           for yy in range(y, y + b) for xx in range(x, x + a))
                if occupied & mask:
                    continue
                tail = fit(shapes[1:], occupied | mask)
                if tail is not None:
                    return [(x, y, a, b)] + tail
    return None


@dataclass
class Item:
    id: str
    d: dict
    side: int
    slot: int
    due: int | None = None
    version: int = 0
    ready: bool = False
    bottles: int = 0


@dataclass
class Side:
    hp: F
    stamina: F
    hp_cap: F
    stamina_cap: F
    items: list[Item] = field(default_factory=list)
    armor: F = F(0)
    armor_cap: F = F(0)
    shield: F = F(0)
    armor_type: str = 'none'
    poison: dict | None = None
    poison_version: int = 0
    immune_until: int = 0
    effects: dict = field(default_factory=dict)
    bonuses: dict = field(default_factory=dict)
    stats: Counter = field(default_factory=Counter)


class Battle:
    def __init__(self, data, build, enemy, start='full', policy='manual',
                 bottles=3, enemy_first=False, poison_first=True,
                 round_tenths=False, delay_ready=False, multiplier=True,
                 first_pill_extra_ms=0, seed=913, trace=False, limit_ms=300000):
        self.data = data
        self.build, self.enemy, self.start, self.policy = build, enemy, start, policy
        self.enemy_first, self.poison_first = enemy_first, poison_first
        self.round_tenths, self.delay_ready = round_tenths, delay_ready
        self.rng = random.Random(seed)
        self.queue, self.seq, self.now = [], 0, 0
        self.outcome, self.limit = None, limit_ms
        self.log = [] if trace else None
        p, e = data['player'], data['enemies'][enemy]
        ratio = F(1) if start == 'full' else F(2, 3)
        self.sides = [Side(self.q(F(p['hp']) * ratio), self.q(F(p['stamina']) * ratio),
                           F(p['hp']), F(p['stamina'])),
                      Side(F(e['hp']), F(e['stamina']), F(e['hp']), F(e['stamina']))]
        for side, ids in enumerate([data['builds'][build]['items'], e['items']]):
            state = self.sides[side]
            for slot, ident in enumerate(ids):
                d = data['items'][ident]
                item = Item(ident, d, side, slot, bottles=bottles)
                state.items.append(item)
                state.armor_cap += d.get('armor_cap', 0)
                state.armor += d.get('initial_armor', 0)
                state.armor_type = d.get('armor_type', state.armor_type)
                extra = first_pill_extra_ms if d['kind'] in ('pill', 'antidote') else 0
                if item.bottles or d['kind'] not in ('pill', 'antidote'):
                    self.schedule(item, d['cd_ms'] + extra)
            state.armor = min(state.armor, state.armor_cap)
        self.weapon_area = sum(i.d['area'] for i in self.sides[0].items
                               if i.d['kind'] == 'attack')
        self.cost_factor = factor(self.weapon_area) if multiplier else F(1)

    def q(self, value):
        value = F(value)
        return F((value * 10 + F(1, 2)).__floor__(), 10) if self.round_tenths else value

    def emit(self, event, side=None, item=None, **values):
        if self.log is not None:
            self.log.append(dict(t=round(self.now / 1000, 4), event=event, side=side,
                                 item=item, hp=[float(s.hp) for s in self.sides],
                                 stamina=[float(s.stamina) for s in self.sides],
                                 armor=[float(s.armor) for s in self.sides], **values))

    def push(self, at, priority, kind, side, item=None, token=0, payload=None):
        self.seq += 1
        order = (1 - side) if self.enemy_first else side
        attack = item is not None and item.d['kind'] == 'attack'
        area = -item.d['area'] if attack else 0
        damage = -item.d['damage'] if attack else 0
        # Random only resolves exact same-side area/damage attack ties.
        tie = self.rng.random() if attack else (item.slot if item else 0)
        heapq.heappush(self.queue, (at, priority, order, area, damage, tie,
                                   self.seq, kind, side, item, token, payload))

    def schedule(self, item, at):
        item.version += 1
        item.due, item.ready = at, False
        priority = {'relic': 1, 'armor': 2, 'pill': 3, 'antidote': 3,
                    'control': 4, 'poison': 5, 'buff': 6, 'attack': 8}[item.d['kind']]
        self.push(at, priority, 'item', item.side, item, item.version)

    def restore(self, side, resource, amount, cap=None, source='effect'):
        state = self.sides[side]
        current = getattr(state, resource)
        normal_cap = getattr(state, resource + '_cap')
        ceiling = normal_cap if cap is None else min(normal_cap, cap)
        ceiling = self.q(ceiling)
        gained = self.q(max(F(0), min(F(amount), ceiling - current)))
        # A rounded increment may not cross an exact fractional ceiling.
        gained = min(gained, max(F(0), ceiling - current))
        setattr(state, resource, current + gained)
        state.stats[resource + '_restored'] += gained
        state.stats[source + '_' + resource + '_restored'] += gained
        state.stats[source + '_' + resource + '_wasted'] += F(amount) - gained
        self.emit('restore', side, source, resource=resource, gain=float(gained))

    def hurt(self, side, amount, kind='direct'):
        state = self.sides[side]
        lost = min(state.hp, self.q(amount))
        state.hp -= lost
        state.stats[kind + '_hp_loss'] += lost
        self.emit('hp_loss', side, kind, loss=float(lost))
        if state.hp <= 0:
            self.outcome = 'defeat' if side == 0 else 'victory'
            self.emit(self.outcome)

    def hit(self, target, raw, attack_type):
        state = self.sides[target]
        shield_loss = min(state.shield, F(raw))
        state.shield -= shield_loss
        damage = self.q((F(raw) - shield_loss) *
                        F(self.data['damage_multipliers'][state.armor_type][attack_type]))
        armor_loss = min(state.armor, damage)
        state.armor -= armor_loss
        state.stats['armor_absorbed'] += armor_loss
        state.stats['shield_absorbed'] += shield_loss
        self.hurt(target, damage - armor_loss)

    def apply_poison(self, target, d):
        state = self.sides[target]
        if state.shield > 0 or self.now < state.immune_until:
            state.stats['poison_blocked'] += 1
            self.emit('poison_blocked', target)
            return
        if state.poison is not None and state.poison['until'] >= self.now:
            state.poison['until'] = self.now + d['duration_ms']
            self.emit('poison_refresh', target)
            return
        state.poison_version += 1
        state.poison = dict(until=self.now + d['duration_ms'], damage=d['tick_damage'],
                            interval=d['tick_ms'])
        self.push(self.now + d['tick_ms'], 7 if self.poison_first else 9,
                  'poison_tick', target, token=state.poison_version)
        self.emit('poison_apply', target)

    def poison_tick(self, target, token):
        state = self.sides[target]
        p = state.poison
        if p is None or token != state.poison_version:
            return
        if self.now > p['until']:
            state.poison = None
            return
        state.stats['poison_ticks'] += 1
        self.hurt(target, p['damage'], 'poison')
        if self.outcome:
            return
        # Keep the next grid tick pending across a fractional expiry. A refresh
        # between the last damage tick and expiry must preserve that tick grid.
        self.push(self.now + p['interval'], 7 if self.poison_first else 9,
                  'poison_tick', target, token=token)

    def use_medicine(self, item):
        state, d = self.sides[item.side], item.d
        item.ready = False
        item.bottles -= 1
        state.stats['bottles_' + item.id] += 1
        if item.bottles:
            self.schedule(item, self.now + d['cd_ms'])
        else:
            item.due = None
        if d['kind'] == 'antidote':
            state.stats['immunity_overwritten_ms'] += max(0, state.immune_until - self.now)
            state.poison, state.poison_version = None, state.poison_version + 1
            state.immune_until = self.now + d['duration_ms']
            self.emit('antidote', item.side, item.id, immune_until=state.immune_until / 1000)
        else:
            old = state.effects.get(item.id, dict(version=0, pending=0))
            state.stats['medicine_overwritten_ticks'] += old['pending']
            version = old['version'] + 1
            state.effects[item.id] = dict(version=version, pending=d['tick_count'],
                                          until=self.now + d['tick_count'] * d['tick_ms'])
            for tick in range(1, d['tick_count'] + 1):
                self.push(self.now + tick * d['tick_ms'], 0, 'medicine_tick',
                          item.side, item, version)
            self.emit('medicine', item.side, item.id, bottles_left=item.bottles)

    def consider_manual(self):
        if self.policy != 'manual' or self.outcome:
            return
        for item in self.sides[0].items:
            if not item.ready or item.bottles <= 0:
                continue
            d, state = item.d, self.sides[0]
            if d['kind'] == 'antidote':
                use = (state.poison is not None and state.poison['until'] >= self.now
                       and state.immune_until <= self.now)
            elif d['kind'] == 'pill':
                effect = state.effects.get(item.id, {})
                deficit = getattr(state, d['resource'] + '_cap') - getattr(state, d['resource'])
                use = effect.get('pending', 0) == 0 and deficit >= d['tick_gain'] * d['tick_count']
            else:
                continue
            if use:
                self.use_medicine(item)

    def activate(self, item):
        d, side = item.d, item.side
        state, target = self.sides[side], 1 - side
        kind = d['kind']
        item.due = None
        if kind in ('pill', 'antidote'):
            if self.policy == 'manual':
                item.ready = True
            else:
                self.use_medicine(item)
            return
        cost = self.q(F(d.get('stamina_cost', 0)) *
                      (self.cost_factor if side == 0 and kind == 'attack' else 1))
        if state.stamina < cost:
            state.stats['empty_' + kind] += 1
            self.emit('empty_rotation', side, item.id, cost=float(cost))
            self.schedule(item, self.now + d['cd_ms'])
            return
        state.stamina -= cost
        state.stats['stamina_spent'] += cost
        state.stats['activations_' + kind] += 1
        self.emit('activate', side, item.id, cost=float(cost))
        if kind == 'attack':
            bonus = state.bonuses.pop(item.id, 0)
            self.hit(target, d['damage'] + bonus, d['attack_type'])
        elif kind == 'armor':
            gain = min(F(d['armor_gain']), state.armor_cap - state.armor)
            state.armor += gain
            state.stats['armor_gained'] += gain
        elif kind == 'relic':
            for resource in ('hp', 'stamina'):
                self.restore(side, resource, d[resource + '_gain'],
                             F(d['cap_ratio']) * getattr(state, resource + '_cap'), 'relic')
        elif kind == 'poison':
            self.apply_poison(target, d)
        elif kind == 'buff':
            state.bonuses[d['target']] = d['bonus']
        elif kind == 'control':
            candidates = [i for i in self.sides[target].items
                          if i.due is not None or (self.delay_ready and i.ready)]
            if d['target_mode'] != 'all_items':
                candidates = [i for i in candidates if i.d['kind'] == 'attack']
            if d['target_mode'] == 'soonest_attack' and candidates:
                candidates = [min(candidates, key=lambda i: (i.due or self.now, i.slot))]
            for other in candidates:
                previous = other.due if other.due is not None else self.now
                self.schedule(other, previous + d['delay_ms'])
                self.emit('delay', target, other.id, due=other.due / 1000)
        if not self.outcome:
            self.schedule(item, self.now + d['cd_ms'])

    def run(self):
        while self.queue and not self.outcome:
            event = heapq.heappop(self.queue)
            at, _, _, _, _, _, _, kind, side, item, token, _ = event
            if at > self.limit:
                break
            self.now = at
            if kind == 'item':
                if token != item.version or item.due != at:
                    continue
                self.activate(item)
            elif kind == 'poison_tick':
                self.poison_tick(side, token)
            elif kind == 'medicine_tick':
                effect = self.sides[side].effects[item.id]
                if effect['version'] != token:
                    continue
                effect['pending'] -= 1
                self.restore(side, item.d['resource'], item.d['tick_gain'], source='medicine')
            self.consider_manual()
        if not self.outcome:
            self.now, self.outcome = self.limit, 'retreat'
            self.emit('retreat')
        self.queue.clear()
        p, e = self.sides
        result = dict(build=self.build, enemy=self.enemy, start=self.start, policy=self.policy,
                      outcome=self.outcome, seconds=self.now / 1000,
                      hp=float(p.hp), stamina=float(p.stamina),
                      enemy_hp=float(e.hp), enemy_stamina=float(e.stamina),
                      postbattle_hp=float(p.hp if self.outcome != 'defeat' else 1),
                      cost_multiplier=float(self.cost_factor))
        for prefix, state in [('player_', p), ('enemy_', e)]:
            result.update({prefix + k: float(v) for k, v in state.stats.items()})
        return result


def validate(data):
    layouts = {}
    for group in ('builds', 'enemies'):
        for ident, build in data[group].items():
            items = [data['items'][i] for i in build['items']]
            assert all(d['area'] == d['shape'][0] * d['shape'][1] for d in items)
            layout = fit([d['shape'] for d in items])
            assert layout is not None, ident
            layouts[group + '.' + ident] = layout
    return layouts


def model_checks(data):
    """Small, hand-checkable timelines that guard consequential model behavior."""
    names = []
    def check(name, condition):
        assert condition, name
        names.append(name)

    def tiny(player_items, enemy_items=(), hp=100, stamina=50):
        d = copy.deepcopy(data)
        d['player'] = dict(hp=hp, stamina=stamina)
        d['builds']['test'] = dict(items=list(player_items))
        d['enemies']['test'] = dict(hp=1000, stamina=50, items=list(enemy_items))
        return d

    check('area formula: 2/3/4/6 cells', [factor(i) for i in (2, 3, 4, 6)] ==
          [F(1), F('1.05'), F('1.10'), F('1.20')])
    d = tiny(['trial.sword', 'trial.bow'], ['trial.wolf.claw'])
    b = Battle(d, 'test', 'test', trace=True, limit_ms=3500)
    b.run()
    check('player shared factor; enemy authored costs',
          b.sides[0].stamina == F('41.2') and b.sides[1].stamina == 48)
    for heal_at, expected in [(2400, [(2.4, 'activate')]),
                              (2500, [(2.4, 'empty_rotation'), (4.8, 'activate')])]:
        d = tiny(['trial.sword', 'trial.relic'], stamina=50)
        d['items']['trial.relic'].update(cd_ms=heal_at, stamina_gain=3)
        b = Battle(d, 'test', 'test', trace=True, limit_ms=4800 if heal_at == 2500 else 2400)
        b.sides[0].stamina = 0
        b.run()
        actual = [(r['t'], r['event']) for r in b.log
                  if r['item'] == 'trial.sword' and r['event'] in ('activate', 'empty_rotation')]
        check('same-time vs 100ms late restore ' + str(heal_at), actual == expected)
    d = tiny(['trial.sword'], ['trial.bat.control'])
    d['items']['trial.bat.control']['cd_ms'] = 2400
    b = Battle(d, 'test', 'test', trace=True, limit_ms=3000)
    b.run()
    check('same-time control postpones attack',
          [r['t'] for r in b.log if r['event'] == 'activate' and r['item'] == 'trial.sword'] == [2.9])
    d['items']['trial.bat.control']['cd_ms'] = 100
    b = Battle(d, 'test', 'test', limit_ms=100)
    b.run()
    check('delay can exceed base rotation', b.sides[0].items[0].due - 100 == 2800)
    b = Battle(tiny([]), 'test', 'test')
    p = b.sides[0]
    p.armor_type, p.shield, p.armor = 'heavy', F(5), F(12)
    b.hit(0, 15, 'pierce')
    check('shield then multiplier then consumable armor', p.hp == 100 and p.shield == 0 and p.armor == F('3.5'))
    b.hit(0, 10, 'pierce')
    check('remaining armor consumed on next attack', p.hp == 95 and p.armor == 0)
    poison = data['items']['trial.spider.poison']
    b = Battle(tiny([]), 'test', 'test', trace=True, limit_ms=5000)
    b.apply_poison(0, poison)
    b.run()
    check('poison four two-HP ticks', [(r['t'], r['loss']) for r in b.log if r['event'] == 'hp_loss'] ==
          [(1, 2), (2, 2), (3, 2), (4, 2)])
    b = Battle(tiny([]), 'test', 'test', trace=True, limit_ms=6000)
    b.apply_poison(0, poison)
    b.now = 500
    b.apply_poison(0, poison)
    b.sides[0].shield = F(10)
    b.run()
    check('refresh keeps next tick; later shield does not stop existing poison',
          [r['t'] for r in b.log if r['event'] == 'hp_loss'] == [1, 2, 3, 4])
    b = Battle(tiny([]), 'test', 'test')
    b.sides[0].shield = F(1)
    b.apply_poison(0, poison)
    check('remaining shield blocks a new poison application', b.sides[0].poison is None)
    b.hit(0, 1, 'pierce')
    b.apply_poison(0, poison)
    check('depleting shield allows new poison even without HP damage', b.sides[0].poison is not None)
    b = Battle(tiny(['trial.antidote']), 'test', 'test', limit_ms=26000)
    item = b.sides[0].items[0]
    b.apply_poison(0, poison)
    b.use_medicine(item)
    b.now = 10000
    b.use_medicine(item)
    b.apply_poison(0, poison)
    check('antidote clears; 5s remainder replaced by 15s', b.sides[0].poison is None and
          b.sides[0].immune_until == 25000 and b.sides[0].stats['poison_blocked'] == 1)
    b = Battle(tiny(['trial.hp']), 'test', 'test', trace=True, limit_ms=8000)
    b.sides[0].hp = 50
    item = b.sides[0].items[0]
    b.use_medicine(item)
    b.now = 1000
    b.use_medicine(item)
    # Remove the remaining bottle so auto/manual policy cannot add a third effect.
    item.bottles, item.due = 0, None
    item.version += 1
    b.run()
    check('new bottle replaces all pending older medicine ticks',
          [r['t'] for r in b.log if r['event'] == 'restore'] == [3, 5, 7] and b.sides[0].hp == 56)
    b = Battle(tiny(['trial.relic']), 'test', 'test')
    b.sides[0].hp, b.sides[0].stamina = F(90), F(33)
    b.activate(b.sides[0].items[0])
    check('relic separate caps never lower a high resource', b.sides[0].hp == 90 and b.sides[0].stamina == F(100, 3))
    d = tiny([], ['trial.boar.tusk', 'trial.boar.buff', 'trial.spider.poison', 'trial.spider.control'])
    d['enemies']['test']['stamina'] = 0
    b = Battle(d, 'test', 'test', limit_ms=8000)
    b.run()
    check('enemy exhaustion prevents attacks buffs poison control', b.sides[0].hp == 100 and
          all(b.sides[1].stats['empty_' + k] == 1 for k in ('attack', 'buff', 'poison', 'control')))
    d = tiny(['trial.sword'], ['trial.wolf.claw'], hp=1)
    d['items']['trial.wolf.claw']['cd_ms'] = 2400
    b = Battle(d, 'test', 'test', enemy_first=True, trace=True)
    r = b.run()
    check('immediate death prevents same-time retaliation; postbattle HP1',
          r['seconds'] == 2.4 and r['hp'] == 0 and r['postbattle_hp'] == 1 and
          b.sides[0].stats['activations_attack'] == 0 and not b.queue)
    b = Battle(tiny([]), 'test', 'test')
    r = b.run()
    check('resource stalemate reaches 300s forced retreat', r['outcome'] == 'retreat' and r['seconds'] == 300)
    d = tiny(['trial.sword', 'trial.bow', 'trial.hammer'], stamina=6)
    for ident in d['builds']['test']['items']:
        d['items'][ident]['cd_ms'] = 1000
    b = Battle(d, 'test', 'test', trace=True, limit_ms=1000)
    b.run()
    check('same-area competing weapons spend on highest base damage first',
          [r['item'] for r in b.log if r['event'] == 'activate'] == ['trial.bow'] and
          b.sides[0].stats['empty_attack'] == 2)
    return names


def write_csv(path, rows):
    keys = list(dict.fromkeys(k for r in rows for k in r))
    with path.open('w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, keys)
        w.writeheader()
        w.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'artifacts' / 'balance-2026-09-13')
    args = parser.parse_args()
    data = json.loads(FIXTURE.read_text(encoding='utf-8-sig'))
    layouts, checks = validate(data), model_checks(data)
    args.out.mkdir(parents=True, exist_ok=True)
    baseline = []
    for build in data['builds']:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    baseline.append(Battle(data, build, enemy, start, policy,
                                           bottles=data['default_bottles_per_type']).run())
    write_csv(args.out / 'baseline.csv', baseline)
    sensitivity = []
    variants = dict(enemy_first=dict(enemy_first=True), poison_last=dict(poison_first=False),
                    rounded=dict(round_tenths=True), delay_ready=dict(delay_ready=True),
                    no_surcharge=dict(multiplier=False), one_bottle=dict(bottles=1),
                    six_bottles=dict(bottles=6), later_medicine=dict(first_pill_extra_ms=3000))
    for variant, options in variants.items():
        for build in data['builds']:
            for enemy in ('boar', 'boss_spider'):
                for start in ('full', 'rested'):
                    for policy in ('auto', 'manual'):
                        r = Battle(data, build, enemy, start, policy, **options).run()
                        r['variant'] = variant
                        sensitivity.append(r)
    write_csv(args.out / 'sensitivity.csv', sensitivity)
    traces = [('triple_guard', 'boss_spider', 'rested', 'manual'),
              ('triple_stamina', 'boss_spider', 'rested', 'manual'),
              ('hammer_antidote', 'boss_spider', 'full', 'auto'),
              ('hammer_antidote', 'boss_spider', 'rested', 'manual'),
              ('bow_guard', 'boar', 'rested', 'manual')]
    for build, enemy, start, policy in traces:
        b = Battle(data, build, enemy, start, policy, trace=True)
        r = b.run()
        (args.out / f'trace_{build}_{enemy}_{start}_{policy}.json').write_text(
            json.dumps(dict(result=r, events=b.log), ensure_ascii=False, indent=2), encoding='utf-8')
    summary = dict(model_checks=checks, legal_layouts=layouts,
                   fixture_sha256=hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
                   script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                   baseline_count=len(baseline), baseline_outcomes=dict(Counter(r['outcome'] for r in baseline)),
                   sensitivity_count=len(sensitivity))
    (args.out / 'verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k != 'legal_layouts'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
