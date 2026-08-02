import { webview } from '@kit.ArkWeb';
import { router, promptAction } from '@kit.ArkUI';
import { FocusCheckInCard } from '../components/FocusCheckInCard';
import { BottomNavBar } from '../components/BottomNavBar';
import { GiantAircraftOverlay } from '../components/GiantAircraftOverlay';
import { HangarFleetView } from '../components/HangarFleetView';
import { Airport } from '../models/AirportModel';

/**
 * Index.ets
 * Focus Flight 专注飞行 - 主界面
 * 极简全屏沉浸 3D 地球视界 + 底部中央 FocusCheckInCard / HangarFleetView 悬浮于 BottomNavBar 正上方
 * 包含最高层级从屏幕最底部升起覆盖所有 UI 的【巨型飞机阴影选座舱 GiantAircraftOverlay】
 */

@Entry
@Component
struct Index {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State activeTab: number = 0;
  @State isDayMode: boolean = false;
  @State isGiantAircraftVisible: boolean = false;
  @State giantAircraftY: string = '100%';
  @State giantAircraftBackdropOpacity: number = 0;
  @State bottomPanelOpacity: number = 1;
  @State bottomPanelOffsetY: string = '0%';
  @State mapSrc: Resource = $rawfile('earth.html');
  @State currentOrigin: Airport | null = null;
  @State currentDest: Airport | null = null;

  private isWebReady: boolean = false;
  private pendingOrigin: Airport | null = null;
  private pendingDest: Airport | null = null;

  private closeGiantAircraft(): void {
    this.getUIContext()?.animateTo({
      duration: 400,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        this.isGiantAircraftVisible = false;
      }
    }, () => {
      this.giantAircraftY = '150%';
      this.giantAircraftBackdropOpacity = 0;
      this.bottomPanelOpacity = 1;
      this.bottomPanelOffsetY = '0%';
    });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 全屏地图视界 (默认 3D 地球，确认登机后平滑切入 OpenFreeMap 矢量地图)
      Web({
        src: this.mapSrc,
        controller: this.controller
      })
        .width('100%')
        .height('100%')
        .backgroundColor('#020617')
        .domStorageAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .javaScriptAccess(true)
        .copyOptions(CopyOptions.None)
        .mixedMode(MixedMode.All)
        .onPageEnd(() => {
          this.isWebReady = true;
          if (this.isDayMode) {
            try {
              this.controller.runJavaScript("if (typeof window.setDayNightMode === 'function') { window.setDayNightMode('day'); }");
            } catch (err) {
              // 防御捕获异常
            }
          }
          if (this.pendingOrigin && this.pendingDest) {
            this.triggerDrawRoute(this.pendingOrigin, this.pendingDest);
            this.pendingOrigin = null;
            this.pendingDest = null;
          } else if (this.pendingOrigin) {
            this.triggerFlyTo(this.pendingOrigin);
            this.pendingOrigin = null;
          }
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. 战力机库全屏覆盖层 (当 activeTab === 2 时展开)
      if (this.activeTab === 2) {
        HangarFleetView()
          .width('100%')
          .height('100%')
          .zIndex(100)
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // 3. 右上角 Cyber HUD 昼夜模式切换按钮 (仅在专注 Tab 0 时显示)
      if (this.activeTab === 0) {
        Row() {
          Row({ space: 6 }) {
            Text(this.isDayMode ? '☀️' : '🌙')
              .fontSize(14)
            Text(this.isDayMode ? '白天' : '夜景')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDayMode ? '#F59E0B' : '#0EA5E9')
          }
          .padding({ left: 12, right: 14, top: 8, bottom: 8 })
          .backgroundColor(this.isDayMode ? 'rgba(15, 23, 42, 0.78)' : 'rgba(10, 15, 26, 0.78)')
          .border({ width: 1, color: this.isDayMode ? 'rgba(245, 158, 11, 0.45)' : 'rgba(14, 165, 233, 0.35)' })
          .borderRadius(20)
          .backdropBlur(16)
          .shadow({ radius: 10, color: this.isDayMode ? 'rgba(245, 158, 11, 0.25)' : 'rgba(14, 165, 233, 0.2)' })
          .onClick(() => {
            this.isDayMode = !this.isDayMode;
            const modeStr = this.isDayMode ? 'day' : 'night';
            try {
              this.controller.runJavaScript(`if (typeof window.setDayNightMode === 'function') { window.setDayNightMode('${modeStr}'); }`);
            } catch (err) {
              // 防御捕获异常
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .position({ x: 0, y: 48 })
        .padding({ right: 16 })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(10)
      }

      // 4. 底部悬浮控制层 (FocusCheckInCard / BottomNavBar)
      Column({ space: 12 }) {
        if (this.activeTab === 0) {
          FocusCheckInCard({
            onRouteChanged: (origin: Airport, dest: Airport | null) => {
              this.currentOrigin = origin;
              this.currentDest = dest;
              if (this.isWebReady) {
                if (dest) {
                  this.triggerDrawRoute(origin, dest);
                } else {
                  this.triggerFlyTo(origin);
                }
              } else {
                this.pendingOrigin = origin;
                this.pendingDest = dest;
              }
            },
            onRequestSeatSelection: () => {
              // 触发最高层级：1. 全屏高斯模糊背景优雅淡入
              this.isGiantAircraftVisible = true;
              this.getUIContext()?.animateTo({
                duration: 400,
                curve: Curve.FastOutSlowIn
              }, () => {
                this.giantAircraftBackdropOpacity = 1;
                this.bottomPanelOpacity = 0;
                this.bottomPanelOffsetY = '80vp';
              });

              // 2. 战术机体以顺滑自然曲线(500ms)升起出场
              this.getUIContext()?.animateTo({
                duration: 500,
                curve: Curve.FastOutSlowIn
              }, () => {
                this.giantAircraftY = '0%';
              });
            }
          })
        }
        BottomNavBar({ activeIndex: $activeTab })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 20 })
      .opacity(this.bottomPanelOpacity)
      .translate({ y: this.bottomPanelOffsetY })
      .zIndex(200)

      // 5. 最高层级 zIndex(9999)：解耦型全屏高斯模糊 + 缓慢移动机体组件
      if (this.isGiantAircraftVisible) {
        GiantAircraftOverlay({
          isVisible: this.isGiantAircraftVisible,
          backdropOpacity: this.giantAircraftBackdropOpacity,
          bodyOffsetY: this.giantAircraftY,
          onConfirmSeat: (seatId: string, taskTitle?: string, durationMin?: number) => {
            this.closeGiantAircraft();
            promptAction.showToast({
              message: `🎉 登机成功！进入巡航视界`,
              duration: 1200
            });
            setTimeout(() => {
              router.pushUrl({
                url: 'pages/MapPage',
                params: {
                  flightNo: 'CA933',
                  seatId: seatId || '1F',
                  taskTitle: taskTitle || '💻 深度编程',
                  durationMin: durationMin || 25,
                  originCode: this.currentOrigin ? this.currentOrigin.code : 'TFU',
                  destCode: this.currentDest ? this.currentDest.code : 'CDG'
                }
              });
            }, 250);
          },
          onClose: () => {
            this.closeGiantAircraft();
          }
        })
        .zIndex(9999)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#020617')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private triggerFlyTo(airport: Airport): void {
    try {
      this.controller.runJavaScript(`if (typeof window.flyToLocation === 'function') { window.flyToLocation(${airport.lat}, ${airport.lon}, '${airport.city}', '${airport.code}'); }`);
    } catch (err) {
      // 防御捕获异常
    }
  }

  private triggerDrawRoute(origin: Airport, dest: Airport): void {
    try {
      this.controller.runJavaScript(`if (typeof window.drawFlightRoute === 'function') { window.drawFlightRoute(${origin.lat}, ${origin.lon}, '${origin.city}', '${origin.code}', ${dest.lat}, ${dest.lon}, '${dest.city}', '${dest.code}'); }`);
      this.controller.runJavaScript(`if (typeof window.initFlightRoute === 'function') { window.initFlightRoute(${origin.lat}, ${origin.lon}, '${origin.city}', '${origin.code}', ${dest.lat}, ${dest.lon}, '${dest.city}', '${dest.code}'); }`);
    } catch (err) {
      // 防御捕获异常
    }
  }
}