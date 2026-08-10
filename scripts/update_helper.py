import os, re

PROJECT_DIR = r'd:\project\focus_flight_ohos'
AIRPORT_TS  = os.path.join(PROJECT_DIR, 'entry/src/main/ets/models/AllAirportsData.ts')
HELPER_ETS  = os.path.join(PROJECT_DIR, 'entry/src/main/ets/utils/AirportMarkerHelper.ets')

with open(AIRPORT_TS, encoding='utf-8') as f:
    content = f.read()

pattern = r"code:\s*'([A-Z]{3,4})'"
codes = sorted(list(set(re.findall(pattern, content))))

cand_lines = []
dest_lines = []
for c in codes:
    cand_lines.append(f"    '{c}': $rawfile('textures/markers/mk_{c}_cand.png'),")
    dest_lines.append(f"    '{c}': $rawfile('textures/markers/mk_{c}_dest.png'),")

cand_block = "\n".join(cand_lines)
dest_block = "\n".join(dest_lines)

ets_content = f"""// 自动生成的机场地图胶囊标记资源字典

export class AirportMarkerHelper {{
  private static candidateMap: Record<string, Resource> = {{
{cand_block}
  }};

  private static destMap: Record<string, Resource> = {{
{dest_block}
  }};

  public static getCandidateIcon(code: string): Resource {{
    return AirportMarkerHelper.candidateMap[code] || $rawfile('textures/markers/mk_CTU_cand.png');
  }}

  public static getDestActiveIcon(code: string): Resource {{
    return AirportMarkerHelper.destMap[code] || $rawfile('textures/markers/mk_CTU_dest.png');
  }}
}}
"""

with open(HELPER_ETS, 'w', encoding='utf-8') as f:
    f.write(ets_content)

print(f"成功更新 AirportMarkerHelper.ets，包含 {len(codes)} 个机场的 $rawfile 映射。")
