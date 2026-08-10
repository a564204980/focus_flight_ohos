import os, re
AIRPORT_TS = r'entry/src/main/ets/models/AllAirportsData.ts'
with open(AIRPORT_TS, encoding='utf-8') as f:
    content = f.read()
names = re.findall(r"name:\s*'([^']+)'", content)
max_n = max(names, key=len)
print('Max name:', max_n, len(max_n))
for n in sorted(names, key=len, reverse=True)[:15]:
    print(f"  {len(n)}: {n}")
