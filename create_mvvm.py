import sys, io, re, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    content = f.read()

states = []
state_lines = []

lines = content.split('\n')
for line in lines:
    match = re.match(r'^\s*(?:private\s+|public\s+)?(?:@State\s+)([a-zA-Z0-9_]+)(\?)?\s*:\s*([^=]+)(?:=\s*(.*))?', line)
    if match:
        name = match.group(1)
        if name == 'currentDestinationAirport':
            continue # We keep this in Index.ets as @State because it's a model
            
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

vm_class = "import { map } from '@kit.MapKit';\n"
vm_class += "import { Airport } from '../models/AirportModel';\n\n"
vm_class += "@Observed\nexport class FlightViewModel {\n"
for s in states:
    opt_str = '?' if s['is_opt'] else ''
    val_str = f" = {s['val']}" if s['val'] else ""
    vm_class += f"  {s['name']}{opt_str}: {s['type']}{val_str};\n"
vm_class += "}\n"

os.makedirs('entry/src/main/ets/viewmodels', exist_ok=True)
with open('entry/src/main/ets/viewmodels/FlightViewModel.ets', 'w', encoding='utf-8') as f:
    f.write(vm_class)

# Delete state lines
new_lines = []
for line in lines:
    if line not in state_lines:
        new_lines.append(line)
        
new_content = '\n'.join(new_lines)

# Inject vm
vm_decl = "  @State vm: FlightViewModel = new FlightViewModel();\n"
struct_start = new_content.find("struct Index {")
brace_idx = new_content.find("{", struct_start)
new_content = new_content[:brace_idx+1] + "\n" + vm_decl + new_content[brace_idx+1:]

import_decl = "import { FlightViewModel } from '../viewmodels/FlightViewModel';\n"
new_content = import_decl + new_content

# Replace this.xxx with this.vm.xxx
state_names = { s['name'] for s in states }
def repl(m):
    prop = m.group(1)
    if prop in state_names:
        return f"this.vm.{prop}"
    return m.group(0)

new_content = re.sub(r'this\.([a-zA-Z0-9_]+)', repl, new_content)

with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Created MVVM")
