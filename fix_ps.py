import json
with open('the_real_script.ps1', 'r', encoding='utf-8') as f:
    text = f.read()

cmd = json.loads(text)

# cmd is a string like: $script = @'\n ... '@ \n $script | Out-File ... 
# We just need to extract the part between @' and '@
start = cmd.find("@'")
end = cmd.rfind("'@")
python_code = cmd[start+2:end]

with open('do_mvvm.py', 'w', encoding='utf-8') as f:
    f.write(python_code)

print("Saved do_mvvm.py")
