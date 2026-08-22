import sys, io, re, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    content = f.read()

start1 = content.find("  @Builder\n  buildDialogLayer() {")
end1 = content.find("  @Builder\n", start1 + 10)
if end1 == -1: end1 = content.find("  build() {", start1)
body1 = content[start1:end1]
inner1 = body1[body1.find('{')+1:body1.rfind('}')]

comp1 = """import { FlightAbortConfirmDialog } from './FlightAbortConfirmDialog';
import { FlightTrailSettingsOverlay } from './FlightTrailSettingsOverlay';
import { PassportStatsView } from './PassportStatsView';
import { DistractionReportView } from './DistractionReportView';
import { LiveFlightLogDrawer } from './LiveFlightLogDrawer';
import { FlightPassportFullReport } from './FlightPassportFullReport';
import { ArrivalBoardingPassCard } from './ArrivalBoardingPassCard';
import { FlightViewModel } from '../viewmodels/FlightViewModel';
import { Airport, findAirportByCode } from '../models/AirportModel';

@Component
export struct IndexDialogsOverlay {
  @ObjectLink vm: FlightViewModel;
  @Link currentDestinationAirport: Airport | undefined;

  triggerHapticFeedback: () => void = () => {};
  abortFlightAndReturnToHangar: () => void = () => {};
  onRouteStyleChanged: (routeId: string) => void = () => {};
  onTrailEffectChanged: (trailId: string) => void = () => {};
  returnFromMapToHangar: (isAborted?: boolean) => void = () => {};

  build() {
    Column() {
"""
comp1 += inner1
comp1 += """    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
"""
with open('entry/src/main/ets/components/IndexDialogsOverlay.ets', 'w', encoding='utf-8') as f:
    f.write(comp1)

rep1 = """IndexDialogsOverlay({ 
        vm: this.vm,
        currentDestinationAirport: $currentDestinationAirport,
        triggerHapticFeedback: (): void => { this.triggerHapticFeedback(); },
        abortFlightAndReturnToHangar: (): void => { this.abortFlightAndReturnToHangar(); },
        onRouteStyleChanged: (routeId: string): void => { this.onRouteStyleChanged(routeId); },
        onTrailEffectChanged: (trailId: string): void => { this.onTrailEffectChanged(trailId); },
        returnFromMapToHangar: (isAborted?: boolean): void => { this.returnFromMapToHangar(isAborted); }
      })"""
content = content[:start1] + content[end1:]
content = content.replace("this.buildDialogLayer()", rep1)

if "import { IndexDialogsOverlay }" not in content:
    content = content.replace("import { FlightViewModel", "import { IndexDialogsOverlay } from '../components/IndexDialogsOverlay';\nimport { FlightViewModel")

with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f:
    f.write(content)
print("Extracted IndexDialogsOverlay")
