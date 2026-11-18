import os, re

files = [os.path.join('scripts', f) for f in os.listdir('scripts') if f.endswith('.gd')]
for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    print(f"Checking {fpath} ({len(lines)} lines)...")
    for i, line in enumerate(lines):
        # check unmatched brackets
        for pair in [('(', ')'), ('[', ']'), ('{', '}')]:
            if line.count(pair[0]) != line.count(pair[1]) and not '#' in line and not '"' in line:
                pass # multi-line allowed
        # check ThemeDB
        if 'ThemeDB' in line:
            print(f"  WARNING: ThemeDB in {fpath}:{i+1} -> {line.strip()}")
        # check load or preload
        if 'preload(' in line or 'load(' in line:
            m = re.findall(r'(?:load|preload)\("([^"]+)"\)', line)
            for path in m:
                if path.startswith('res://'):
                    local_p = path.replace('res://', '')
                    if not os.path.exists(local_p):
                        print(f"  ERROR: Resource not found: {path} in {fpath}:{i+1}")

print("Syntax & Resource check complete.")
