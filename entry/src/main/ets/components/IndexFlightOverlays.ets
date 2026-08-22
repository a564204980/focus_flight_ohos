
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

    // 6. 飞行地图 HUD 悬浮控制层 (仅在机舱展开或地图飞行模式下挂载渲染，绝不干扰停机坪首页交互)
      if (this.vm.isCabinExposed || (this.vm.isMapBackgroundVisible && !this.vm.isCabinExposed)) {
        FlightMapHudOverlay({
          isMapBackgroundVisible: this.vm.isMapBackgroundVisible,
          isCabinExposed: this.vm.isCabinExposed,
          isWindowViewMode: this.vm.isWindowViewMode,
          isCameraFollowLocked: this.vm.isCameraFollowLocked,
          currentMapType: this.vm.currentMapType,
          currentFocusTagTitle: this.vm.currentFocusTagTitle,
          remainingTimeString: this.vm.remainingTimeString,
          isTurbulenceAlertVisible: this.vm.isTurbulenceAlertVisible,
          turbulenceMessageText: this.vm.turbulenceMessageText,
          onOpenSettings: () => {
            this.triggerHapticFeedback();
            this.vm.isTrailSettingsVisible = !this.vm.isTrailSettingsVisible;
          },
          onToggleWindowView: () => {
            this.triggerHapticFeedback();
            this.vm.isWindowViewMode = !this.vm.isWindowViewMode;
            FlightSessionStore.updateWindowViewMode(this.vm.isWindowViewMode);
          },
          onTestArrivalBoardingPass: () => {
            this.triggerHapticFeedback();
            this.vm.isArrivalBoardingPassVisible = true;
          },
          onToggleMapType: () => this.toggleMapTypeMode(),
          onToggleCameraFollow: () => this.toggleCameraFollowMode(),
          onExitFlight: () => {
            this.triggerHapticFeedback();
            if (this.vm.isFlightInProgress) {
              this.vm.isAbortDialogVisible = true;
            } else if (this.vm.isMapBackgroundVisible) {
              this.returnFromMapToHangar(false);
            } else {
              this.returnFromCabinToHangar();
            }
          },
          onOpenLiveLog: () => {
            this.vm.isLiveLogVisible = true;
          }
        })
          .hitTestBehavior(HitTestMode.Transparent)
          .zIndex(260)
      }

      // 6.5 🪟 机舱舷窗沉浸专注视角 (StandBy 桌面时钟模式)
      if (this.vm.isWindowViewMode && this.vm.isFlightInProgress) {
        CabinWindowViewOverlay({
          remainingTimeString: this.vm.remainingTimeString,
          currentFocusTagTitle: this.vm.currentFocusTagTitle,
          originAirport: findAirportByCode('CTU'),
          destinationAirport: this.currentDestinationAirport || findAirportByCode('PEK'),
          isFlightPaused: this.vm.isFlightPaused,
          isTurbulenceActive: this.vm.isTurbulenceAlertVisible,
          turbulenceMessageText: this.vm.turbulenceMessageText
        })
          .zIndex(250)
      }

        }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
