import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    text = f.read()

# Add import
if "import { FlightViewModel }" not in text:
    text = "import { FlightViewModel } from '../viewmodels/FlightViewModel';\n" + text

# Add vm declaration
if "@State vm: FlightViewModel" not in text:
    idx = text.find("struct Index {")
    if idx != -1:
        brace_idx = text.find("{", idx)
        text = text[:brace_idx+1] + "\n  @State vm: FlightViewModel = new FlightViewModel();" + text[brace_idx+1:]

with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f:
    f.write(text)
print("Fixed Index.ets MVVM declaration")
