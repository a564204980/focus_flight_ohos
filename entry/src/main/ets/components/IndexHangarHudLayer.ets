
import { HomeFocusPanel } from './HomeFocusPanel';
import { HeaderGreetingBar } from './HeaderGreetingBar';
import { CyberThemeSelector, FlightBookingSignboard } from './CyberThemeSelector';
import { GroundServiceVehiclesOverlay, FuelTruckHeadlightBeamOverlay } from './GroundServiceVehiclesOverlay';
import { PlaneCabinShellOverlay } from './PlaneCabinShellOverlay';
import { NightApronLightingOverlay, TaxiwayGroundLightsOverlay } from './NightApronLightingOverlay';
import { FlightViewModel } from '../viewmodels/FlightViewModel';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { FlightSessionStore } from '../services/FlightSessionStore';

@Component
export struct IndexHangarHudLayer {
  @ObjectLink vm: FlightViewModel;
  @StorageLink('selectedDestinationAirport') currentDestinationAirport: Airport | undefined = undefined;
  @StorageLink('currentThemeIndex') currentThemeIndex: number = 0;

  @StorageLink('userMemberTier') userMemberTier: string = 'lifetime';

  showTopToast: (message: string, duration?: number) => void = () => {};
  onSeatSelectedInIndex: (seatId: string, tagId?: string, durationMinutes?: number) => void = () => {};
  onTractorClick: () => void = () => {};
  enterCabinSelectionFromHangar: () => void = () => {};
  onFuelTruckClick: () => void = () => {};
  triggerPreFlightPosterCeremony: (isPreviewOnly?: boolean) => void = () => {};

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

      // 2.5 停机坪机位地面标牌组 (刻度尺上方右侧：测试海报、航班预订、机位装扮)
      if (this.vm.isHudVisible && !this.vm.isFullFocusMode && !this.vm.isMapBackgroundVisible) {
        Column({ space: 6 }) {
          // 🎫 测试机票海报与会员切换按钮组 (已按用户需求隐藏)
          // Row({ space: 6 }) { ... }

          FlightBookingSignboard()
          CyberThemeSelector()
        }
        .alignItems(HorizontalAlign.End)
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



      // 2.9 滑行道地坪内嵌蓝灯群 (贴地最低层级，被飞机/车辆/阴影自然遮挡)
      TaxiwayGroundLightsOverlay({
        isMapBackgroundVisible: this.vm.isMapBackgroundVisible
      })

      // ★ 夜间车头大灯光锥（独立图层）
      // 层级：位于夜色背景之上、所有摆件实体之下
      // 车灯光束不受全屏暗色蒙版影响（已移除），显示纯白亮光
      // 飞机机身/车辆实体在其上方自然遮挡地面光斑
      FuelTruckHeadlightBeamOverlay({
        isFullFocusMode: this.vm.isFullFocusMode,
        isMapBackgroundVisible: this.vm.isMapBackgroundVisible,
        fuelTruckX: this.vm.fuelTruckX,
        fuelTruckY: this.vm.fuelTruckY,
        fuelTruckRotate: this.vm.fuelTruckRotate
      })

      // 3. 地面勤务摆件实体（加油车/牵引车/廊桥，各自内置 colorFilter 夜色，位于车灯光束之上）
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


      // 4. 飞机实体与剖开机舱图层 (在地面大灯光束上方，飞机机身、机翼与发动机完美遮挡地面光斑)
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

      // 4.5 全场景夜幕滤镜与真实航行微光 (统领全景，将地面、所有车辆摆件与飞机统一融入夜色)
      NightApronLightingOverlay({
        isMapBackgroundVisible: this.vm.isMapBackgroundVisible,
        planeX: this.vm.planeX,
        planeY: this.vm.planeY,
        planeScale: this.vm.planeScale,
        planeRotate: this.vm.planeRotate
      })

      // 5. 底部专注控制面板
      HomeFocusPanel({
        isFlightInProgress: this.vm.isFlightInProgress,
        onShowTopToast: (msg: string) => {
          this.showTopToast(msg);
        },
        onStartFlight: (minutes?: number, dest?: Airport, isRoaming?: boolean) => {
          this.vm.isRoamingMode = !!isRoaming;
          if (minutes && minutes > 0) {
            this.vm.selectedFocusDurationMinutes = minutes;
          } else if (isRoaming) {
            this.vm.selectedFocusDurationMinutes = 0; // 漫游模式无上限
          }
          if (dest) {
            this.currentDestinationAirport = dest;
          }
          
          const destCode = isRoaming ? 'ROAM' : (dest ? dest.code : 'PEK');
          if (!isRoaming && dest) {
            AppStorage.setOrCreate('selectedDestinationAirport', dest);
          }
          AppStorage.setOrCreate('selectedDestinationCode', destCode);

          const activeTagTitle = AppStorage.get<string>('currentFocusTagTitle') || this.vm.currentFocusTagTitle || '深度学习';
          this.vm.currentFocusTagTitle = activeTagTitle;

          // 存储当前飞行会话并进入地图巡航就位
          FlightSessionStore.saveSession({
            isFlightActive: true,
            flightNo: isRoaming ? 'FF-ROAM' : 'FF-337',
            seatId: '01A',
            taskTitle: activeTagTitle,
            durationMin: this.vm.selectedFocusDurationMinutes,
            originCode: 'CTU',
            destCode: destCode,
            startTimeMs: Date.now(),
            checkInTimeMs: Date.now(),
            isRoamingMode: isRoaming,
            events: [{
              id: 'start_' + Date.now(),
              type: 'gate_departure',
              timestampMs: Date.now(),
              note: isRoaming ? '漫游模式启动，自由探索航线' : '设备锁定，航线开始'
            }]
          });

          this.triggerPreFlightPosterCeremony(false);
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
