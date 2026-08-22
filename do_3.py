import sys, io, re, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    content = f.read()

start3 = content.find("  @Builder\n  buildHangarHudLayer() {")
end3 = content.find("  @Builder\n", start3 + 10)
if end3 == -1: end3 = content.find("  build() {", start3)
body3 = content[start3:end3]
inner3 = body3[body3.find('{')+1:body3.rfind('}')]

comp3 = """import { CyberHudOverlay } from './CyberHudOverlay';
import { HomeFocusPanel } from './HomeFocusPanel';
import { HeaderGreetingBar } from './HeaderGreetingBar';
import { CyberThemeSelector } from './CyberThemeSelector';
import { GroundServiceVehiclesOverlay } from './GroundServiceVehiclesOverlay';
import { PlaneCabinShellOverlay } from './PlaneCabinShellOverlay';
import { FlightViewModel } from '../viewmodels/FlightViewModel';
import { Airport, findAirportByCode } from '../models/AirportModel';

@Component
export struct IndexHangarHudLayer {
  @ObjectLink vm: FlightViewModel;
  @Link currentDestinationAirport: Airport | undefined;

  showTopToast: (message: string, duration?: number) => void = () => {};
  onSeatSelectedInIndex: (seatId: string, tagId?: string, durationMinutes?: number) => void = () => {};
  onTractorClick: () => void = () => {};
  enterCabinSelectionFromHangar: () => void = () => {};
  onFuelTruckClick: () => void = () => {};

  build() {
    Column() {
"""
comp3 += inner3
comp3 += """    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
"""
with open('entry/src/main/ets/components/IndexHangarHudLayer.ets', 'w', encoding='utf-8') as f:
    f.write(comp3)

rep3 = """IndexHangarHudLayer({ 
        vm: this.vm,
        currentDestinationAirport: $currentDestinationAirport,
        showTopToast: (message: string, duration?: number): void => { this.showTopToast(message, duration); },
        onSeatSelectedInIndex: (seatId: string, tagId?: string, durationMinutes?: number): void => { this.onSeatSelectedInIndex(seatId, tagId, durationMinutes); },
        onTractorClick: (): void => { this.onTractorClick(); },
        enterCabinSelectionFromHangar: (): void => { this.enterCabinSelectionFromHangar(); },
        onFuelTruckClick: (): void => { this.onFuelTruckClick(); }
      })"""
content = content[:start3] + content[end3:]
content = content.replace("this.buildHangarHudLayer()", rep3)

if "import { IndexHangarHudLayer }" not in content:
    content = content.replace("import { FlightViewModel", "import { IndexHangarHudLayer } from '../components/IndexHangarHudLayer';\nimport { FlightViewModel")

with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f:
    f.write(content)
print("Extracted IndexHangarHudLayer")
