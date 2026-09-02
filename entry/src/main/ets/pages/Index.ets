import { IndexDialogsOverlay } from '../components/IndexDialogsOverlay';
import { IndexFlightOverlays } from '../components/IndexFlightOverlays';
import { IndexHangarHudLayer } from '../components/IndexHangarHudLayer';
import { FloatingCapsuleNavBar } from '../components/FloatingCapsuleNavBar';
import { PreFlightBoardingPassOverlay, MemberTierType } from '../components/PreFlightBoardingPassOverlay';
import { IndexController } from '../controllers/IndexController';
import { FlightViewModel } from '../viewmodels/FlightViewModel';
import { common } from '@kit.AbilityKit';
import { display, promptAction, router, window } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { image } from '@kit.ImageKit';
import { displaySync } from '@kit.ArkGraphics2D';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { HomeFocusPanel } from '../components/HomeFocusPanel';
import { CabinInteriorOverlay } from '../components/CabinInteriorOverlay';
import { CyberMapHudControl } from '../components/CyberMapHudControl';
import { HeaderGreetingBar } from '../components/HeaderGreetingBar';
import { GroundServiceVehiclesOverlay } from '../components/GroundServiceVehiclesOverlay';
import { CyberThemeSelector } from '../components/CyberThemeSelector';
import { PlaneCabinShellOverlay } from '../components/PlaneCabinShellOverlay';
import { FlightMapHudOverlay } from '../components/FlightMapHudOverlay';
import { CabinWindowViewOverlay } from '../components/CabinWindowViewOverlay';
import { ArrivalBoardingPassCard } from '../components/ArrivalBoardingPassCard';
import { FlightAbortConfirmDialog } from '../components/FlightAbortConfirmDialog';
import { FlightTrailSettingsOverlay } from '../components/FlightTrailSettingsOverlay';
import { FlightTrailParticleOverlay } from '../components/FlightTrailParticleOverlay';
import { MapRenderHelper } from '../utils/MapRenderHelper';
import { SoundEffectHelper } from '../utils/SoundEffectHelper';
import { PlaneMarkerIconHelper } from '../utils/PlaneMarkerIconHelper';
import { FlightRouteEngine, RouteDistanceProfile } from '../utils/FlightRouteEngine';
import { FlightSessionStore, FlightSessionData } from '../services/FlightSessionStore';
import { PassportStatsView } from '../components/PassportStatsView';
import { DistractionReportView } from '../components/DistractionReportView';
import { LiveFlightLogDrawer } from '../components/LiveFlightLogDrawer';
import { FlightPassportFullReport } from '../components/FlightPassportFullReport';
import { ImmersiveWeatherOverlay } from '../components/ImmersiveWeatherOverlay';
import {
  LatLngPoint,
  interpolateLatLng
} from '../utils/GeodesicUtils';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { ctuAirportConfig } from '../models/airports/ctu';
import { pekAirportConfig } from '../models/airports/pek';

// ✈️ 动态从 ctuAirportConfig 直接读取起飞跑道起点与终点，100% 实时响应 ctu.ets 的任何修改！
function getCtuRunwayStart(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.start || { latitude: 30.592085, longitude: 103.958889 };
}

function getCtuRunwayEnd(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.end || { latitude: 30.562957, longitude: 103.945340 };
}

const CTU_RUNWAY_BEARING: number = ctuAirportConfig.runwayAngle ?? 158;

// 🌃 暗夜纯净航图自定义样式 JSON (彻底关闭地面 POI、地名、路名等文字注记，防止遮挡高空航线与彩虹)
const CLEAN_DARK_AVIATION_STYLE_JSON: string = '[{"mapFeature":"poi","options":"all","visibility":"off"},{"mapFeature":"road","featureName":"label","visibility":"off"},{"mapFeature":"administrative","featureName":"label","visibility":"off"},{"mapFeature":"transportation","featureName":"label","visibility":"off"}]';

// ✈️ 默认飞行终点：北京首都国际机场 (PEK) 跑道数据（用于三阶段航线无缝连接）
function getPekRunwayStart(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.start || { latitude: 40.079857, longitude: 116.603114 };
}

function getPekRunwayEnd(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.end || { latitude: 40.091200, longitude: 116.615000 };
}


@Entry
@Component
struct Index {
  @State vm: FlightViewModel = new FlightViewModel();
  private controller!: IndexController;
  @StorageLink('currentThemeIndex') currentThemeIndex: number = 0;

  @StorageLink('isFullReportVisible') isFullReportVisible: boolean = false;
  @StorageLink('isStatsSheetVisible') isStatsSheetVisible: boolean = false;
  @StorageLink('isSettingsSheetVisible') isSettingsSheetVisible: boolean = false;
  @StorageLink('isFlightAlertsSheetVisible') isFlightAlertsSheetVisible: boolean = false;
  @StorageLink('isThemeSelectSheetVisible') isThemeSelectSheetVisible: boolean = false;
  @StorageLink('isBookFlightSheetVisible') isBookFlightSheetVisible: boolean = false;
  @StorageLink('isProPaywallVisible') isProPaywallVisible: boolean = false;

  aboutToAppear() {
    this.controller = new IndexController(this.vm);
    this.controller.setContext(this.getUIContext());
    this.controller.aboutToAppear();
  }
  onPageShow() { this.controller?.onPageShow(); }
  onPageHide() { this.controller?.onPageHide(); }
  aboutToDisappear() { this.controller?.aboutToDisappear(); }
  @Builder
  buildBaseLayer() {
      // 1. 全屏背景层 (未放大时为停机坪 bg_1，仅在【飞机完全放大完毕】或【点击座椅后】无缝切为华为花瓣地图精修机场)
      Stack({ alignContent: Alignment.Center }) {
        // 底层：停机坪地面 (固定底层)
        Image($r('app.media.bg_1'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.05, y: 1.05 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : 1)
          .animation({ duration: 800, curve: Curve.EaseInOut })

        // 主题附加层1：晴空航迹 (Index 1)
        Image(this.controller.bgThemes[1])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 1 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层2：云鲸航线 (Index 2)
        Image(this.controller.bgThemes[2])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 2 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层3：戴竹蜻蜓蓝色胖子 (Index 3)
        Image(this.controller.bgThemes[3])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 3 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层4：空港幻想 (Index 4)
        Image(this.controller.bgThemes[4])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 4 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层5：机修大队 (Index 5)
        Image(this.controller.bgThemes[5])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 5 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层6：星港先锋 (Index 6)
        Image(this.controller.bgThemes[6])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 6 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 主题附加层7：苍穹机甲 (Index 7)
        Image(this.controller.bgThemes[7])
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.0, y: 1.0 })
          .translate({ x: 4 })
          .opacity(this.vm.isMapBackgroundVisible ? 0 : (this.currentThemeIndex === 7 ? 0.6 : 0))
          .animation({ duration: 600, curve: Curve.EaseInOut })

        // 上层：华为原生花瓣地图 (Petal Maps) 精修机场地图
        if (this.vm.isMapBackgroundVisible) {
          MapComponent({ mapOptions: this.controller.huaweiMapOptions, mapCallback: this.controller.huaweiMapCallback })
            .width('100%')
            .height('100%')
            .renderGroup(true)
            .opacity(this.vm.isMapBackgroundVisible ? 1 : 0)
            .animation({ duration: 800, curve: Curve.EaseInOut })
            .onTouch((event: TouchEvent) => {
              // 🛡️ 位移阈值判断真实拖拽：记录按下坐标，仅当位移 > 8vp 才认定为地图拖拽并取消跟随
              // 纯点击（含 HUD 按钮穿透的 Down）与轻微抖动不超阈值，绝不误取消镜头跟随
              if (event.type === TouchType.Down) {
                this.controller.mapTouchStartX = event.touches[0].x;
                this.controller.mapTouchStartY = event.touches[0].y;
              } else if (event.type === TouchType.Move && (this.vm.isCameraFollowLocked || this.controller.isCameraFlyingBack)) {
                const dx = event.touches[0].x - this.controller.mapTouchStartX;
                const dy = event.touches[0].y - this.controller.mapTouchStartY;
                if (Math.sqrt(dx * dx + dy * dy) > 8) {
                  this.vm.isCameraFollowLocked = false;
                  this.controller.isCameraFlyingBack = false;
                  if (this.controller.groundFlybackTimerSync) {
                    this.controller.groundFlybackTimerSync.stop();
                    this.controller.groundFlybackTimerSync = undefined;
                  }
                }
              }

              if (event.type === TouchType.Move || event.type === TouchType.Up) {
                if (!this.vm.isCameraFollowLocked) {
                  this.controller.updatePlaneScreenPosition();
                }
              }

              // 🎯 用户松手后启动 2 秒无操作自动平滑飞回飞机
              if (event.type === TouchType.Up && !this.vm.isCameraFollowLocked && this.vm.isFlightInProgress) {
                if (this.controller.groundFlybackTimerSync) {
                  this.controller.groundFlybackTimerSync.stop();
                }
                this.controller.groundFlybackTimerSync = displaySync.create();
                let waitFrames = 0;
                this.controller.groundFlybackTimerSync.on('frame', () => {
                  waitFrames++;
                  if (waitFrames >= 120) { // 约 2 秒
                    if (this.controller.groundFlybackTimerSync) {
                      this.controller.groundFlybackTimerSync.stop();
                      this.controller.groundFlybackTimerSync = undefined;
                    }
                    this.controller.startCameraFlyback();
                  }
                });
                this.controller.groundFlybackTimerSync.start();
              }
            })

          // 🎨 60FPS 极简唯美尾迹粒子与流光浮层 (梦幻泡泡/星光粉尘/凝结尾迹云/极光/彩虹)
          if (this.vm.isFlightInProgress) {
            FlightTrailParticleOverlay({
              isFlightActive: this.vm.isFlightInProgress && !this.vm.isFlightPaused,
              trailId: this.controller.selectedTrailEffect,
              planeScreenOffsetX: this.vm.planeScreenOffsetX,
              planeScreenOffsetY: this.vm.planeScreenOffsetY,
              planeScreenRotation: this.vm.planeScreenDynamicRotation,
              currentMapBearing: this.controller.currentMapBearing,
              currentZoomLevel: this.controller.currentZoomLevel,
              currentFlightRawIndex: this.vm.currentFlightRawIndex,
              flightPoints: this.vm.currentFlightPoints
            })
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.None)
              .zIndex(150)
          }

          // ⛈️ 沉浸式禅意天气系统 (天色渐暗 -> 细雨 -> 暴雨 -> 惊雷 -> 平滑放晴，随地图坐标实时平移)
          ImmersiveWeatherOverlay({
            weatherType: this.vm.currentWeatherType,
            planeScreenOffsetX: this.vm.planeScreenOffsetX,
            planeScreenOffsetY: this.vm.planeScreenOffsetY
          })
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
            .zIndex(155)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.controller.screenVpWidth = newArea.width as number;
        this.controller.screenVpHeight = newArea.height as number;
      })


    }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.buildBaseLayer()
      IndexHangarHudLayer({ 
        vm: this.vm,
        showTopToast: (message: string, duration?: number): void => { this.controller.showTopToast(message, duration); },
        onSeatSelectedInIndex: (seatId: string, tagId?: string, durationMinutes?: number): void => { this.controller.onSeatSelectedInIndex(seatId, tagId, durationMinutes); },
        onTractorClick: (): void => { this.controller.onTractorClick(); },
        enterCabinSelectionFromHangar: (): void => { this.controller.enterCabinSelectionFromHangar(); },
        onFuelTruckClick: (): void => { this.controller.onFuelTruckClick(); },
        triggerPreFlightPosterCeremony: (isPreviewOnly?: boolean): void => { this.controller.triggerPreFlightPosterCeremony(isPreviewOnly); }
      })
      IndexFlightOverlays({ 
        vm: this.vm,
        toggleMapTypeMode: (): void => { this.controller.toggleMapTypeMode(); },
        toggleCameraFollowMode: (): void => { this.controller.toggleCameraFollowMode(); },
        toggleWeatherMode: (): void => { this.controller.toggleWeatherMode(); },
        returnFromMapToHangar: (isAborted?: boolean): void => { this.controller.returnFromMapToHangar(isAborted); },
        returnFromCabinToHangar: (): void => { this.controller.returnFromCabinToHangar(); },
        triggerHapticFeedback: (): void => { this.controller.triggerHapticFeedback(); }
      })

      // 终极停机坪按钮屏蔽层 (Global Event Blocking Layer)
      // 当打开任何全屏弹窗或抽屉时，这层透明膜会拦截所有漏网的点击与滑动，彻底禁用底层的停机坪按钮与地球交互
      if (this.isFullReportVisible || this.isStatsSheetVisible || this.isSettingsSheetVisible || 
          this.isFlightAlertsSheetVisible || this.isThemeSelectSheetVisible || this.isProPaywallVisible ||
          this.vm.isDistractionReportVisible || this.vm.isAbortDialogVisible || this.vm.isArrivalBoardingPassVisible) {
        Row()
          .width('100%')
          .height('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {})
          .gesture(PanGesture().onActionUpdate(() => {}))
      }

      IndexDialogsOverlay({ 
        vm: this.vm,
        triggerHapticFeedback: (): void => { this.controller.triggerHapticFeedback(); },
        abortFlightAndReturnToHangar: (): void => { this.controller.abortFlightAndReturnToHangar(); },
        onRouteStyleChanged: (routeId: string): void => { this.controller.onRouteStyleChanged(routeId); },
        onTrailEffectChanged: (trailId: string): void => { this.controller.onTrailEffectChanged(trailId); },
        onSkinSelected: (skinIndex: number): void => { this.controller.playPlaneSkinChangeAnimation(skinIndex); },
        returnFromMapToHangar: (isAborted?: boolean): void => { this.controller.returnFromMapToHangar(isAborted); }
      })

      // 🌟 全局常驻底部导航栏 (在首页平铺，在常规抽屉变胶囊，在全屏弹窗/飞行中/预订弹窗中彻底隐藏)
      if (!this.vm.isFlightInProgress &&
          !this.vm.isFullFocusMode &&
          !this.vm.isMapBackgroundVisible &&
          !this.vm.isCabinExposed &&
          !this.isFullReportVisible &&
          !this.isProPaywallVisible &&
          !this.isFlightAlertsSheetVisible &&
          !this.isThemeSelectSheetVisible &&
          !this.isBookFlightSheetVisible &&
          !this.vm.isDistractionReportVisible &&
          !this.vm.isLiveLogVisible &&
          !this.vm.isTrailSettingsVisible &&
          !this.vm.isArrivalBoardingPassVisible &&
          !this.vm.isAbortDialogVisible) {
        Column() {
          FloatingCapsuleNavBar({
            isFlightInProgress: this.vm.isFlightInProgress,
            isFullFocusMode: this.vm.isFullFocusMode
          })
        }
        .width('100%')
        .padding({ bottom: 28 })
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .alignItems(HorizontalAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
        .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.FastOutSlowIn }))
        .zIndex(600)
      }

      // 🎫 电影级起飞仪式过场：页面缓缓变暗 + 拟物机票从顶部物理掉落 + 盖章准予起飞
      if (this.vm.isPreFlightBoardingPassVisible) {
        PreFlightBoardingPassOverlay({
          isVisible: this.vm.isPreFlightBoardingPassVisible,
          isPreviewOnly: this.vm.isPreFlightPosterPreviewOnly,
          originAirport: findAirportByCode('CTU'),
          destAirport: AppStorage.get<Airport>('selectedDestinationAirport') || findAirportByCode('PEK'),
          durationMinutes: this.vm.selectedFocusDurationMinutes,
          focusTagTitle: this.vm.currentFocusTagTitle,
          seatId: '01A',
          initialMemberTier: (AppStorage.get<string>('userMemberTier') as MemberTierType) || 'lifetime',
          isRoamingMode: this.vm.isRoamingMode,
          onClose: () => {
            this.vm.isPreFlightBoardingPassVisible = false;
            this.vm.isPreFlightPosterPreviewOnly = false;
          },
          onFinish: () => {
            this.vm.isPreFlightBoardingPassVisible = false;
            this.vm.isPreFlightPosterPreviewOnly = false;
            this.controller.startFlightAnimationDirectly();
          }
        })
          .zIndex(950)
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      // 🛡️ 只有在机舱展开选座模式下才响应全屏点击收起逻辑
      if (this.vm.isCabinExposed && !this.vm.isMapBackgroundVisible) {
        this.controller.returnFromCabinToHangar();
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
  onBackPress(): boolean {
    return this.controller?.onBackPress() ?? false;
  }
}
