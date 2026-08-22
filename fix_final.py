import sys, io, os

# Fix FlightViewModel.ets
with open('entry/src/main/ets/viewmodels/FlightViewModel.ets', 'r', encoding='utf-8') as f:
    vm_content = f.read()

vm_content = vm_content.replace("import { map } from '@kit.MapKit';", "import { map, mapCommon } from '@kit.MapKit';")
vm_lines = vm_content.split('\n')
vm_lines = [l for l in vm_lines if 'currentThemeIndex' not in l]
with open('entry/src/main/ets/viewmodels/FlightViewModel.ets', 'w', encoding='utf-8') as f:
    f.write('\n'.join(vm_lines))

# Fix Index.ets
with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    index = f.read()
# Put currentThemeIndex back as @State
index = index.replace("  @State vm: FlightViewModel = new FlightViewModel();", "  @State vm: FlightViewModel = new FlightViewModel();\n  @State currentThemeIndex: number = 0;")
index = index.replace("this.vm.currentThemeIndex", "this.currentThemeIndex")
# Fix the call to IndexHangarHudLayer to pass it as Link
index = index.replace("IndexHangarHudLayer({ \n        vm: this.vm,", "IndexHangarHudLayer({ \n        vm: this.vm,\n        currentThemeIndex: $currentThemeIndex,")
with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f:
    f.write(index)

# Fix IndexHangarHudLayer.ets
with open('entry/src/main/ets/components/IndexHangarHudLayer.ets', 'r', encoding='utf-8') as f:
    hhl = f.read()
hhl = hhl.replace("@StorageLink('currentThemeIndex') currentThemeIndex: number = 0;", "@Link currentThemeIndex: number;")
hhl = hhl.replace("this.vm.currentThemeIndex", "this.currentThemeIndex")
# Fix imports
hhl = hhl.replace("import { CyberHudOverlay } from './CyberHudOverlay';", "")
with open('entry/src/main/ets/components/IndexHangarHudLayer.ets', 'w', encoding='utf-8') as f:
    f.write(hhl)

# Fix IndexFlightOverlays.ets imports
with open('entry/src/main/ets/components/IndexFlightOverlays.ets', 'r', encoding='utf-8') as f:
    ifo = f.read()
ifo = ifo.replace("import { FlightDataTopPanel } from './FlightDataTopPanel';\nimport { FlightCameraControls } from './FlightCameraControls';", "")
with open('entry/src/main/ets/components/IndexFlightOverlays.ets', 'w', encoding='utf-8') as f:
    f.write(ifo)

print("Fixed imports and currentThemeIndex")
