"""Unapproved weapon-only proposal: bow vs light armor uses 1.25, global table stays 1.20.

A private lookup alias lets this experiment reuse the unchanged damage formula;
it is not a new production damage category or a player-only rule. Any wielder of
the authored bow would get the same target-armor adjustment.
"""
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
from prologue_bow_light_proposals_20260913 import BUILDS, FIXTURE, OUT, ROOT


class BowLightBonusBattle(BossRecoveryBattle):
    def __init__(self, data, *args, **kwargs):
        owned = copy.deepcopy(data)
        for armor, coefficients in owned['damage_multipliers'].items():
            coefficients['candidate_bow_pierce'] = '1.25' if armor == 'light' else coefficients['pierce']
        self.active_source = None
        super().__init__(owned, *args, **kwargs)

    def activate(self, item):
        previous = self.active_source
        self.active_source = item.id
        try:
            super().activate(item)
        finally:
            self.active_source = previous

    def hit(self, target, raw, attack_type):
        if self.active_source == 'trial.bow':
            attack_type = 'candidate_bow_pierce'
        super().hit(target, raw, attack_type)


def scoped_checks(data):
    d = copy.deepcopy(data)
    d['builds']['test'] = dict(items=['trial.bow'])
    d['enemies']['test'] = dict(hp=1000, stamina=50, items=['trial.spider.fang'])
    for armor in ('none', 'light', 'heavy', 'spiritual'):
        b = BowLightBonusBattle(d, 'test', 'test')
        enemy = b.sides[1]
        enemy.armor_type, enemy.armor, enemy.shield = armor, F(2), F(3)
        b.activate(b.sides[0].items[0])
        coefficient = F('1.25') if armor == 'light' else F(data['damage_multipliers'][armor]['pierce'])
        assert enemy.hp == 1000 - ((9 - 3) * coefficient - 2)
        assert b.sides[0].stamina == 45
    b = BowLightBonusBattle(d, 'test', 'test')
    player = b.sides[0]
    player.armor_type, player.armor, player.shield = 'light', F(2), F(3)
    b.activate(b.sides[1].items[0])
    assert player.hp == 50 - F('0.4')
    assert data['damage_multipliers']['light']['pierce'] == '1.20'
    return ['bow-specific effect retains shield -> coefficient -> consumable armor ordering',
            'all non-light bow coefficients and its stamina cost unchanged',
            'enemy fang still uses global 1.20; source context restored after activation']


def main():
    data = json.loads(FIXTURE.read_text(encoding='utf-8'))
    checks = scoped_checks(data)
    baseline_path = ROOT / 'artifacts' / 'balance-2026-09-13-matrix-bow9' / 'baseline.csv'
    with baseline_path.open(encoding='utf-8-sig', newline='') as f:
        lookup = {(r['build'], r['enemy'], r['start'], r['policy']): r for r in csv.DictReader(f)}
    rows, sensitivity, transitions = [], [], Counter()
    for build in BUILDS:
        for enemy in data['enemies']:
            for start in ('full', 'rested'):
                for policy in ('auto', 'manual'):
                    r = BowLightBonusBattle(data, build, enemy, start, policy).run()
                    before = lookup[(build, enemy, start, policy)]
                    if 'trial.bow' not in data['builds'][build]['items'] or enemy not in ('bird', 'gray_spider', 'boar'):
                        for field in ('outcome', 'seconds', 'hp', 'stamina', 'enemy_hp', 'enemy_stamina'):
                            assert str(r[field]) == before[field], (build, enemy, field)
                    r['variant'] = 'bow_only_light_1.25'
                    for field in ('outcome', 'seconds', 'hp', 'stamina', 'player_stamina_spent'):
                        r['baseline_' + field] = before.get(field, '0')
                    rows.append(r)
                    transitions[before['outcome'] + ' -> ' + r['outcome']] += 1
                    s = BowLightBonusBattle(data, build, enemy, start, policy, enemy_first=True).run()
                    s['normal_priority_outcome'] = r['outcome']
                    sensitivity.append(s)
    checks.append('all non-bow builds and non-light-target scenarios reproduce sixth-round results/resources')
    OUT.mkdir(parents=True, exist_ok=True)
    write_csv(OUT / 'bow_only_light125.csv', rows)
    write_csv(OUT / 'bow_only_light125_enemy_first.csv', sensitivity)
    summary = dict(status='unapproved weapon-specific proposal; no changes to baseline or global matrix',
                   checks=checks, count=len(rows), transitions=dict(transitions),
                   enemy_first_count=len(sensitivity),
                   enemy_first_outcome_changes=sum(r['outcome'] != r['normal_priority_outcome'] for r in sensitivity),
                   hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in (FIXTURE, baseline_path, Path(__file__),
                                     Path(__file__).with_name('prologue_bow_light_proposals_20260913.py'))})
    (OUT / 'scoped_verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    for r in rows:
        if r['build'] == 'bow_guard' and r['start'] == 'rested' and r['policy'] == 'manual' and r['enemy'] in ('bird', 'gray_spider', 'boar'):
            print(r['enemy'], r['outcome'], r['seconds'], r['hp'], r['stamina'], r['player_stamina_spent'])


if __name__ == '__main__':
    main()
