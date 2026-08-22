import sys, io, re, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    content = f.read()

start2 = content.find("  @Builder\n  buildFlightOverlays() {")
end2 = content.find("  @Builder\n", start2 + 10)
if end2 == -1: end2 = content.find("  build() {", start2)
body2 = content[start2:end2]
inner2 = body2[body2.find('{')+1:body2.rfind('}')]

comp2 = """import { FlightDataTopPanel } from './FlightDataTopPanel';
import { FlightCameraControls } from './FlightCameraControls';
import { CabinInteriorOverlay } from './CabinInteriorOverlay';
import { CabinWindowViewOverlay } from './CabinWindowViewOverlay';
import { FlightMapHudOverlay } from './FlightMapHudOverlay';
import { FlightViewModel } from '../viewmodels/FlightViewModel';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { FlightSessionStore } from '../services/FlightSessionStore';

@Component
export struct IndexFlightOverlays {
  @ObjectLink vm: FlightViewModel;
  @Link currentDestinationAirport: Airport | undefined;

  toggleMapTypeMode: () => void = () => {};
  toggleCameraFollowMode: () => void = () => {};
  returnFromMapToHangar: (isAborted?: boolean) => void = () => {};
  returnFromCabinToHangar: () => void = () => {};
  triggerHapticFeedback: () => void = () => {};

  build() {
    Column() {
"""
comp2 += inner2
comp2 += """    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
"""
with open('entry/src/main/ets/components/IndexFlightOverlays.ets', 'w', encoding='utf-8') as f:
    f.write(comp2)

rep2 = """IndexFlightOverlays({ 
        vm: this.vm,
        currentDestinationAirport: $currentDestinationAirport,
        toggleMapTypeMode: (): void => { this.toggleMapTypeMode(); },
        toggleCameraFollowMode: (): void => { this.toggleCameraFollowMode(); },
        returnFromMapToHangar: (isAborted?: boolean): void => { this.returnFromMapToHangar(isAborted); },
        returnFromCabinToHangar: (): void => { this.returnFromCabinToHangar(); },
        triggerHapticFeedback: (): void => { this.triggerHapticFeedback(); }
      })"""
content = content[:start2] + content[end2:]
content = content.replace("this.buildFlightOverlays()", rep2)

if "import { IndexFlightOverlays }" not in content:
    content = content.replace("import { FlightViewModel", "import { IndexFlightOverlays } from '../components/IndexFlightOverlays';\nimport { FlightViewModel")

with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f:
    f.write(content)
print("Extracted IndexFlightOverlays")
