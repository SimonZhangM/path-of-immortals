"""Prepare a narrowly scoped reset; apply only after the Godot copy check passes."""
import argparse
import hashlib
import json
import os
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts' / 'qingshihewan-golden-reset'
SOURCE = Path(os.environ['APPDATA']) / 'Godot/app_userdata/Path of Immortals/inventory_loadout.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def prepare():
    original = SOURCE.read_bytes()
    before = json.loads(original.decode('utf-8-sig'))
    after = json.loads(json.dumps(before))
    rules = read(ROOT / 'data/cultivation_growth.json')
    realm = next(i for i, row in enumerate(rules['realms']) if row['id'] == 'golden_core')
    board = next(read(path) for path in (ROOT / 'data/boards').glob('*.json') if read(path)['id'] == before['board_id'])
    limits = {key: rules['realms'][realm]['base'][i] + board.get('resource_bonuses', {}).get(key, 0)
              for i, key in enumerate(('hp', 'stamina', 'spirit'))}
    growth = after['growth']
    growth['realm'], growth['layer'] = realm, 1
    assert growth['progress'] < rules['realms'][realm]['upgrade'] * 100, 'Existing progress needs a separate decision'
    for key, limit in limits.items():
        growth['resources'][key] = min(growth['resources'][key], limit * 100)
    encounters = sorted(row['id'] for row in (read(path) for path in (ROOT / 'data/map_events').glob('*.json'))
                        if row.get('type') == 'encounter' and row.get('point_id', '').startswith('base.map.qingshihewan.point.'))
    assert len(encounters) == 11
    removed = {key: after.get('encounter_cooldowns', {}).pop(key) for key in encounters if key in after.get('encounter_cooldowns', {})}
    for key in before:
        if key not in ('growth', 'encounter_cooldowns'):
            assert before[key] == after[key], key
    for key in before['growth']:
        if key not in ('realm', 'layer', 'resources'):
            assert before['growth'][key] == after['growth'][key], key
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / 'before.json').write_bytes(original)
    write(WORK / 'candidate.json', after)
    plan = {'source': str(SOURCE), 'before_sha256': digest(original),
            'candidate_sha256': digest((WORK / 'candidate.json').read_bytes()),
            'encounters': encounters, 'removed_cooldowns': removed,
            'maxima': limits, 'cultivation_required': rules['realms'][realm]['upgrade'],
            'lifespan': rules['realms'][realm]['lifespan']}
    write(WORK / 'plan.json', plan)
    print(json.dumps(plan, ensure_ascii=True))


def apply():
    plan = read(WORK / 'plan.json')
    check = read(WORK / 'verified.json')
    assert check['passed'] and check['candidate_sha256'] == plan['candidate_sha256']
    assert str(SOURCE) == plan['source']
    original, candidate = SOURCE.read_bytes(), (WORK / 'candidate.json').read_bytes()
    assert digest(original) == plan['before_sha256'], 'Save changed; prepare and verify again'
    assert digest(candidate) == plan['candidate_sha256'], 'Candidate changed'
    backup = SOURCE.with_name(SOURCE.name + '.before-qingshi-golden-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.bak')
    with backup.open('xb') as stream:
        stream.write(original)
    temporary = SOURCE.with_name(SOURCE.name + '.qingshi-reset.tmp')
    with temporary.open('xb') as stream:
        stream.write(candidate)
        stream.flush()
        os.fsync(stream.fileno())
    assert digest(SOURCE.read_bytes()) == plan['before_sha256'], 'Save changed before replace'
    os.replace(temporary, SOURCE)
    assert digest(SOURCE.read_bytes()) == plan['candidate_sha256']
    write(WORK / 'applied.json', {'source': str(SOURCE), 'backup': str(backup), 'sha256': digest(candidate)})
    print('APPLIED; backup: ' + str(backup))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    options = parser.parse_args()
    apply() if options.apply else prepare()
