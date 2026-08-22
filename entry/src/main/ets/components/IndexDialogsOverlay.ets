import { FlightAbortConfirmDialog } from './FlightAbortConfirmDialog';
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
  @State selectedDistractionYear: string = 'all';

  triggerHapticFeedback: () => void = () => {};
  abortFlightAndReturnToHangar: () => void = () => {};
  onRouteStyleChanged: (routeId: string) => void = () => {};
  onTrailEffectChanged: (trailId: string) => void = () => {};
  returnFromMapToHangar: (isAborted?: boolean) => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {

    // 7. 专注飞行终止备降二次确认弹窗 (优雅航空沉浸式提示)
      if (this.vm.isAbortDialogVisible) {
        FlightAbortConfirmDialog({
          isVisible: this.vm.isAbortDialogVisible,
          onCancel: () => {
            this.triggerHapticFeedback();
            this.vm.isAbortDialogVisible = false;
          },
          onConfirmAbort: () => {
            this.triggerHapticFeedback();
            this.abortFlightAndReturnToHangar();
          }
        })
          .zIndex(290)
      }

      // 7.5 🎫 专属【落地通关登机牌】华丽结算卡片 (Dribbble 顶级质感)
      if (this.vm.isArrivalBoardingPassVisible) {
        ArrivalBoardingPassCard({
          isVisible: this.vm.isArrivalBoardingPassVisible,
          durationMinutes: this.vm.selectedFocusDurationMinutes > 0 ? this.vm.selectedFocusDurationMinutes : 45,
          flightDistanceKm: Math.round((this.vm.selectedFocusDurationMinutes > 0 ? this.vm.selectedFocusDurationMinutes : 45) * 20.4),
          focusTagTitle: this.vm.currentFocusTagTitle,
          originAirport: findAirportByCode('CTU'),
          destinationAirport: this.currentDestinationAirport || findAirportByCode('PEK'),
          seatId: '01A',
          onCompleteAndExit: () => {
            this.vm.isArrivalBoardingPassVisible = false;
            this.returnFromMapToHangar(false);
          }
        })
          .zIndex(300)
      }

      // 8. 飞行视觉个性化设置抽屉 (航线效果 + 巡航尾迹双 Tab 切换)
      if (this.vm.isTrailSettingsVisible) {
        FlightTrailSettingsOverlay({
          isVisible: this.vm.isTrailSettingsVisible,
          currentRouteStyle: $selectedRouteStyle,
          currentTrailId: $selectedTrailEffect,
          onSelectRoute: (routeId: string) => {
            this.onRouteStyleChanged(routeId);
          },
          onSelectTrail: (trailId: string) => {
            this.onTrailEffectChanged(trailId);
          },
          onClose: () => {
            this.triggerHapticFeedback();
            this.vm.isTrailSettingsVisible = false;
          }
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(300)
      }

      // 9. 飞行护照底部抽屉面板 (Passport Stats Drawer, zIndex 500)
      Stack({ alignContent: Alignment.Bottom }) {
        // 半透明黑色背景遮罩
        Rect()
          .width('100%')
          .height('100%')
          .fill('rgba(0, 0, 0, 0.45)')
          .opacity(this.isStatsSheetVisible ? 1 : 0)
          .hitTestBehavior(this.isStatsSheetVisible ? HitTestMode.Default : HitTestMode.None)
          .animation({ duration: 300 })
          .onClick(() => {
            if (this.isStatsSheetVisible) {
              this.isStatsSheetVisible = false;
            }
          })

        // 抽屉卡片主体
        Column() {
          // 顶部小横条指示器
          Row() {
            Row()
              .width(36)
              .height(4)
              .backgroundColor('#D1D5DB')
              .borderRadius(2)
          }
          .width('100%')
          .height(20)
          .justifyContent(FlexAlign.Center)

          PassportStatsView({
            onClose: () => {
              this.isStatsSheetVisible = false;
            },
            onOpenFullReport: () => {
              this.isFullReportVisible = true;
              // 关键：isStatsSheetVisible 保持为 true！下层护照抽屉不动、不收起！
            },
            onOpenDistractionReport: (year: string) => {
              this.selectedDistractionYear = year || 'all';
              this.vm.isDistractionReportVisible = true;
            }
          })
          .layoutWeight(1)
        }
        .width('100%')
        .height('88%')
        .backgroundColor('#fff7f4')
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({ radius: 25, color: 'rgba(0,0,0,0.25)', offsetY: -6 })
        .position({ x: 0, y: this.isStatsSheetVisible ? '12%' : '120%' })
        .animation({ duration: 350, curve: Curve.FastOutSlowIn })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .hitTestBehavior(this.isStatsSheetVisible ? HitTestMode.Default : HitTestMode.None)
      .zIndex(500)

      // 10. 专注飞行日志全屏页面（提前常驻挂载 WebGL 3D 地球，0ms秒开无白屏，zIndex 900）
      FlightPassportFullReport({
        isVisible: this.isFullReportVisible,
        onClose: () => {
          this.isFullReportVisible = false;
          // 关键：关闭全屏日志时，由于 isStatsSheetVisible 仍为 true，直接露出下方的护照抽屉！
        }
      })
        .width('100%')
        .height('100%')
        .backgroundColor('#110928')
        .opacity(this.isFullReportVisible ? 1 : 0)
        .position({ x: 0, y: this.isFullReportVisible ? 0 : '120%' })
        .hitTestBehavior(this.isFullReportVisible ? HitTestMode.Default : HitTestMode.None)
        .animation({ duration: 380, curve: Curve.FastOutSlowIn })
        .zIndex(900)

      // 11. 专属分心报告 (Distraction Report, zIndex 950)
      if (this.vm.isDistractionReportVisible) {
        DistractionReportView({
          selectedYear: this.selectedDistractionYear,
          onClose: () => {
            this.vm.isDistractionReportVisible = false;
          }
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(950)
          .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 380, curve: Curve.FastOutSlowIn }))
      }

      // 12. 实时飞行日志（椅背屏幕）抽屉 (zIndex 960)
      if (this.vm.isLiveLogVisible) {
        LiveFlightLogDrawer({
          isTurbulent: this.vm.isTurbulenceAlertVisible,
          onClose: () => {
            this.vm.isLiveLogVisible = false;
          }
        })
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(960)
      }
      }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
