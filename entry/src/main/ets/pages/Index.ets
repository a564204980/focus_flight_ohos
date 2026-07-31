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
        .mixedMode(MixedMode.All)
        .onPageEnd(() => {
          this.isWebReady = true;
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

      // 2. 底部中央大悬浮面板层 (FocusCheckInCard 位于 BottomNavBar 正上方)
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