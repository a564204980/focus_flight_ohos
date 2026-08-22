import sys

with open('the_real_script.ps1', 'r', encoding='utf-8') as f:
    text = f.read()

# The string might look like: "$script = @'\nimport sys..."
start = text.find("import sys, io, re, os")
end = text.rfind("'@")
python_code = text[start:end]

# It has literal \n from the JSON string format, so let's unescape it manually!
# Actually, if it's literally saved with \n as string, we can do:
python_code = python_code.replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\')

with open('do_mvvm.py', 'w', encoding='utf-8') as f:
    f.write(python_code)
print("Saved do_mvvm.py")
