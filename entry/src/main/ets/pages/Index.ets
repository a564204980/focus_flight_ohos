import { webview } from '@kit.ArkWeb';
import { FocusCheckInCard } from '../components/FocusCheckInCard';
import { BottomNavBar } from '../components/BottomNavBar';
import { Airport } from '../models/AirportModel';

/**
 * Index.ets
 * Focus Flight 专注飞行 - 主界面
 * 极简全屏沉浸 3D 地球视界 + 底部中央 FocusCheckInCard 悬浮于 BottomNavBar 正上方
 */

@Entry
@Component
struct Index {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State activeTab: number = 0;
  @State isDayMode: boolean = false;
  private isWebReady: boolean = false;
  private pendingOrigin: Airport | null = null;
  private pendingDest: Airport | null = null;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 3D 地球沉浸背景
      Web({
        src: $rawfile('earth.html'),
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

      // 2. 右上角 Cyber HUD 昼夜模式切换按钮
      Row() {
        Row({ space: 6 }) {
          Text(this.isDayMode ? '☀️' : '🌙')
            .fontSize(14)
          Text(this.isDayMode ? '白天' : '夜景')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDayMode ? '#F59E0B' : '#38BDF8')
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .backgroundColor(this.isDayMode ? 'rgba(15, 23, 42, 0.78)' : 'rgba(10, 15, 26, 0.78)')
        .border({ width: 1, color: this.isDayMode ? 'rgba(245, 158, 11, 0.45)' : 'rgba(56, 189, 248, 0.35)' })
        .borderRadius(20)
        .backdropBlur(16)
        .shadow({ radius: 10, color: this.isDayMode ? 'rgba(245, 158, 11, 0.25)' : 'rgba(56, 189, 248, 0.2)' })
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

      // 3. 底部中央大悬浮面板层 (FocusCheckInCard 位于 BottomNavBar 正上方)
      Column({ space: 12 }) {
        FocusCheckInCard({
          onRouteChanged: (origin: Airport, dest: Airport | null) => {
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
          }
        })
        BottomNavBar({ activeIndex: $activeTab })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 20 })
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
    } catch (err) {
      // 防御捕获异常
    }
  }
}