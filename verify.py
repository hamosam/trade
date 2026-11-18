import re

with open('scenes/main.tscn', 'r', encoding='utf-8') as f:
    tscn = f.read()

nodes = {}
for line in tscn.splitlines():
    m = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?\]', line)
    if m:
        name = m.group(1)
        ntype = m.group(2)
        parent = m.group(3)
        if parent is None:
            full_path = '.'
        elif parent == '.':
            full_path = name
        else:
            full_path = parent + '/' + name
        nodes[full_path] = ntype

print(f'Total nodes in scene: {len(nodes)}')

scripts = [
    ('scripts/main.gd', ''),
    ('scripts/ui_diplomat.gd', 'MainViews/DiplomatView/'),
    ('scripts/ui_treasurer.gd', 'MainViews/TreasurerView/'),
    ('scripts/ui_technician.gd', 'MainViews/TechnicianView/'),
    ('scripts/ui_analyst.gd', 'MainViews/AnalystView/'),
    ('scripts/ui_spokesperson.gd', 'MainViews/SpokespersonView/'),
    ('scripts/ui_teacher.gd', 'MainViews/TeacherView/')
]

missing = []
for script_path, prefix in scripts:
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()
    for line in content.splitlines():
        m = re.search(r'@onready\s+var\s+\w+\s*=\s*\$([^\s]+)', line)
        if m:
            rel_path = m.group(1)
            target = (prefix + rel_path).strip('/')
            if target not in nodes:
                missing.append((script_path, rel_path, target))

if missing:
    print('MISSING NODES:')
    for s, r, t in missing:
        print(f'  In {s}: {r} -> {t} NOT FOUND')
else:
    print('ALL @onready NODE PATHS ARE 100% VALID!')
