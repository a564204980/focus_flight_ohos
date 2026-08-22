import sys, io, re, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    content = f.read()

# We will move all @State variables into FlightViewModel
# First, let's extract them.
states = []
state_lines = []

lines = content.split('\
')
for line in lines:
    match = re.match(r'^\s*(?:private\s+|public\s+)?(?:@State\s+)([a-zA-Z0-9_]+)(\?)?\s*:\s*([a-zA-Z0-9_<>\.\|\[\] ]+)(?:\s*=\s*(.*))?', line)
    if match:
        name = match.group(1)
        is_opt = match.group(2)
        typ = match.group(3).strip()
        val = match.group(4)
        if val and val.endswith(';'): val = val[:-1]
        states.append({
            'name': name,
            'is_opt': is_opt,
            'type': typ,
            'val': val
        })
        state_lines.append(line)

vm_class = "import { map } from 