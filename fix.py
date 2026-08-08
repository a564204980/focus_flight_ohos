import re

path = 'd:/project/focus_flight_ohos/entry/src/main/ets/pages/Index.ets'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('\\\'', "'")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed quotes')
