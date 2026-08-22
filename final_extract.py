import sys, io, os

with open('entry/src/main/ets/pages/Index.ets', 'r', encoding='utf-8') as f:
    content = f.read()

# ----------------- do_1.py (Dialogs Overlay) -----------------
start1 = content.find("  @Builder\n  buildDialogLayer() {")
end1 = content.find("  @Builder\n", start1 + 10)
if end1 == -1: end1 = content.find("  build() {", start1)
inner1 = content[start1:end1]
inner1 = inner1[inner1.find('{')+1:inner1.rfind('}')]

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
  @StorageLink('isFullReportVisible') isFullReportVisible: boolean = false;
  @StorageLink('isStatsSheetVisible') isStatsSheetVisible: boolean = false;
  @StorageLink('selectedDestinationAirport') currentDestinationAirport: Airport | undefined = undefined;
  @StorageLink('selectedRouteStyle') selectedRouteStyle: string = 'classic';
  @StorageLink('selectedTrailEffect') selectedTrailEffect: string = 'none';

  triggerHapticFeedback: () => void = () => {};
  abortFlightAndReturnToHangar: () => void = () => {};
  onRouteStyleChanged: (routeId: string) => void = () => {};
  onTrailEffectChanged: (trailId: string) => void = () => {};
  returnFromMapToHangar: (isAborted?: boolean) => void = () => {};

  build() {
    Column() {
""" + inner1 + """    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
"""
with open('entry/src/main/ets/components/IndexDialogsOverlay.ets', 'w', encoding='utf-8') as f: f.write(comp1)
rep1 = """IndexDialogsOverlay({ 
        vm: this.vm,
        triggerHapticFeedback: (): void => { this.triggerHapticFeedback(); },
        abortFlightAndReturnToHangar: (): void => { this.abortFlightAndReturnToHangar(); },
        onRouteStyleChanged: (routeId: string): void => { this.onRouteStyleChanged(routeId); },
        onTrailEffectChanged: (trailId: string): void => { this.onTrailEffectChanged(trailId); },
        returnFromMapToHangar: (isAborted?: boolean): void => { this.returnFromMapToHangar(isAborted); }
      })"""
content = content[:start1] + content[end1:]
content = content.replace("this.buildDialogLayer()", rep1)

# ----------------- do_2.py (Flight Overlays) -----------------
start2 = content.find("  @Builder\n  buildFlightOverlays() {")
end2 = content.find("  @Builder\n", start2 + 10)
if end2 == -1: end2 = content.find("  build() {", start2)
inner2 = content[start2:end2]
inner2 = inner2[inner2.find('{')+1:inner2.rfind('}')]

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
  @StorageLink('selectedDestinationAirport') currentDestinationAirport: Airport | undefined = undefined;

  toggleMapTypeMode: () => void = () => {};
  toggleCameraFollowMode: () => void = () => {};
  returnFromMapToHangar: (isAborted?: boolean) => void = () => {};
  returnFromCabinToHangar: () => void = () => {};
  triggerHapticFeedback: () => void = () => {};

  build() {
    Column() {
""" + inner2 + """    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
"""
with open('entry/src/main/ets/components/IndexFlightOverlays.ets', 'w', encoding='utf-8') as f: f.write(comp2)
rep2 = """IndexFlightOverlays({ 
        vm: this.vm,
        toggleMapTypeMode: (): void => { this.toggleMapTypeMode(); },
        toggleCameraFollowMode: (): void => { this.toggleCameraFollowMode(); },
        returnFromMapToHangar: (isAborted?: boolean): void => { this.returnFromMapToHangar(isAborted); },
        returnFromCabinToHangar: (): void => { this.returnFromCabinToHangar(); },
        triggerHapticFeedback: (): void => { this.triggerHapticFeedback(); }
      })"""
content = content[:start2] + content[end2:]
content = content.replace("this.buildFlightOverlays()", rep2)

# ----------------- do_3.py (Hangar Hud) -----------------
start3 = content.find("  @Builder\n  buildHangarHudLayer() {")
end3 = content.find("  @Builder\n", start3 + 10)
if end3 == -1: end3 = content.find("  build() {", start3)
inner3 = content[start3:end3]
inner3 = inner3[inner3.find('{')+1:inner3.rfind('}')]

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
  @StorageLink('selectedDestinationAirport') currentDestinationAirport: Airport | undefined = undefined;
  @StorageLink('currentThemeIndex') currentThemeIndex: number = 0;

  showTopToast: (message: string, duration?: number) => void = () => {};
  onSeatSelectedInIndex: (seatId: string, tagId?: string, durationMinutes?: number) => void = () => {};
  onTractorClick: () => void = () => {};
  enterCabinSelectionFromHangar: () => void = () => {};
  onFuelTruckClick: () => void = () => {};

  build() {
    Column() {
""" + inner3 + """    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
"""
with open('entry/src/main/ets/components/IndexHangarHudLayer.ets', 'w', encoding='utf-8') as f: f.write(comp3)
rep3 = """IndexHangarHudLayer({ 
        vm: this.vm,
        showTopToast: (message: string, duration?: number): void => { this.showTopToast(message, duration); },
        onSeatSelectedInIndex: (seatId: string, tagId?: string, durationMinutes?: number): void => { this.onSeatSelectedInIndex(seatId, tagId, durationMinutes); },
        onTractorClick: (): void => { this.onTractorClick(); },
        enterCabinSelectionFromHangar: (): void => { this.enterCabinSelectionFromHangar(); },
        onFuelTruckClick: (): void => { this.onFuelTruckClick(); }
      })"""
content = content[:start3] + content[end3:]
content = content.replace("this.buildHangarHudLayer()", rep3)

# Add imports
imports = "import { IndexDialogsOverlay } from '../components/IndexDialogsOverlay';\nimport { IndexFlightOverlays } from '../components/IndexFlightOverlays';\nimport { IndexHangarHudLayer } from '../components/IndexHangarHudLayer';\n"
content = content.replace("import { FlightViewModel", imports + "import { FlightViewModel")

with open('entry/src/main/ets/pages/Index.ets', 'w', encoding='utf-8') as f: f.write(content)
print("Extracted all 3 layers perfectly")
