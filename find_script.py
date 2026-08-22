import json

with open(r'C:\Users\Lenovo\.gemini\antigravity\brain\d2b10bb2-ab28-4460-83a0-611ae6e555a3\.system_generated\logs\transcript.jsonl', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines:
    data = json.loads(line)
    if 'tool_calls' in data:
        for tc in data['tool_calls']:
            if 'CommandLine' in tc['args']:
                cmd = tc['args']['CommandLine']
                if 'export class FlightViewModel' in cmd and '$script = @\'' in cmd:
                    with open('the_real_script.ps1', 'w', encoding='utf-8') as out:
                        out.write(cmd)
                    print("Found!")
                    exit(0)
