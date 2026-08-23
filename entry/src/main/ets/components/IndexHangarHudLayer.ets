
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
    Stack({ alignContent: Alignment.Top }) {

    HeaderGreetingBar({
        isHudVisible: this.vm.isHudVisible,
        isFullFocusMode: this.vm.isFullFocusMode,
        isMapBackgroundVisible: this.vm.isMapBackgroundVisible
      })

      // 2.1 顶部沉浸式通知胶囊 (图2指定红框区域)
      if (this.vm.isTopToastVisible) {
        Row({ space: 6 }) {
          Text(this.vm.topToastMessage)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E293B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor('rgba(255, 255, 255, 0.95)')
        .borderRadius(16)
        .border({ width: 1, color: 'rgba(226, 232, 240, 0.8)' })
        .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.08)', offsetY: 3 })
        .position({ x: '50%', y: 56 })
        .markAnchor({ x: '50%', y: 0 })
        .zIndex(999)
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: -16 }))
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        )
      }

      // 2.5 停机坪机位地面标牌互动 (刻度尺上方右侧)
      if (this.vm.isHudVisible && !this.vm.isFullFocusMode && !this.vm.isMapBackgroundVisible) {
        Column() {
          CyberThemeSelector()
        }
        .position({ x: '100%', y: '73%' })
        .markAnchor({ x: '100%', y: '100%' })
        .margin({ right: 24, bottom: 6 })
        .zIndex(200)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // 2.6 加油车状态提示 (用户指定位置：刻度尺上方左侧，纯单行文字)
      if (this.vm.isHudVisible && !this.vm.isFullFocusMode && !this.vm.isMapBackgroundVisible && this.vm.isFuelTruckMessageVisible) {
        Text(this.vm.fuelTruckMessageText)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#64748B')
          .position({ x: '0%', y: '73%' })
          .markAnchor({ x: '0%', y: '100%' })
          .margin({ left: 24, bottom: 6 })
          .zIndex(200)
          .transition(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 16 }))
              .animation({ duration: 350, curve: Curve.EaseOut })
          )
      }



      // 3. 地面勤务设备与阴影层
      GroundServiceVehiclesOverlay({
        isFullFocusMode: this.vm.isFullFocusMode,
        isMapBackgroundVisible: this.vm.isMapBackgroundVisible,
        isVehiclesDocked: this.vm.isVehiclesDocked,
        fuelTruckX: this.vm.fuelTruckX,
        fuelTruckY: this.vm.fuelTruckY,
        fuelTruckRotate: this.vm.fuelTruckRotate,
        onFuelTruckClick: () => this.onFuelTruckClick(),
        onTractorClick: () => this.onTractorClick()
      })


      // 4. 飞机实体与剖开机舱图层
      PlaneCabinShellOverlay({
        isMapBackgroundVisible: this.vm.isMapBackgroundVisible,
        isCabinExposed: this.vm.isCabinExposed,
        isFullFocusMode: this.vm.isFullFocusMode,
        planeScale: this.vm.planeScale,
        planeOpacity: this.vm.planeOpacity,
        currentZoomScale: this.vm.currentZoomScale,
        planeX: this.vm.planeX,
        planeY: this.vm.planeY,
        planeRotate: this.vm.planeRotate,
        shellSplitOffset: this.vm.shellSplitOffset,
        selectedDurationMinutes: this.vm.selectedFocusDurationMinutes,
        onSeatClick: (seatId: string): void => {
          this.onSeatSelectedInIndex(seatId, 'study', this.vm.selectedFocusDurationMinutes);
        },
        onConfirmFlight: (seatId: string, tagId: string, durationMinutes: number): void => {
          this.onSeatSelectedInIndex(seatId, tagId, durationMinutes);
        }
      })
        .hitTestBehavior(HitTestMode.Transparent)

      // 5. 底部专注控制面板
      HomeFocusPanel({
        isFlightInProgress: this.vm.isFlightInProgress,
        onShowTopToast: (msg: string) => {
          this.showTopToast(msg);
        },
        onStartFlight: (minutes?: number, dest?: Airport) => {
          if (minutes && minutes > 0) {
            this.vm.selectedFocusDurationMinutes = minutes;
          }
          if (dest) {
            this.currentDestinationAirport = dest;
          }
          this.enterCabinSelectionFromHangar();
        }
      })
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .opacity((this.vm.isHudVisible && !this.vm.isFullFocusMode && !this.vm.isMapBackgroundVisible) ? 1 : 0)
        .translate({ y: (this.vm.isHudVisible && !this.vm.isFullFocusMode && !this.vm.isMapBackgroundVisible) ? 0 : 260 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .zIndex(100)

        }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
