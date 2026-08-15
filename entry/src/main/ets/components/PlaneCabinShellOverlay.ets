import { CabinInteriorOverlay } from './CabinInteriorOverlay';

/**
 * PlaneCabinShellOverlay.ets
 * 飞机实体、地面阴影、11.8 倍放大剖开外壳与透视机舱联动组件
 */

@Component
export struct PlaneCabinShellOverlay {
  @Prop isMapBackgroundVisible: boolean = false;
  @Prop isCabinExposed: boolean = false;
  @Prop isFullFocusMode: boolean = false;
  @Prop planeScale: number = 1.0;
  @Prop planeOpacity: number = 1.0;
  @Prop currentZoomScale: number = 1.0;
  @Prop planeX: number = 0;
  @Prop planeY: number = -45;
  @Prop planeRotate: number = 0;
  @Prop shellSplitOffset: number = 0;

  onSeatClick?: (seatId: string) => void;
  onConfirmFlight?: (seatId: string, tagId: string, durationMinutes: number) => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 飞机地面阴影
      Image($r('app.media.b737_800_top_3_shadow'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .opacity(this.isFullFocusMode ? 0 : this.planeOpacity)
        .scale({
          x: this.planeScale,
          y: this.planeScale
        })
        .rotate({ angle: this.planeRotate })
        .translate({ x: this.planeX + 8, y: this.planeY + 20 })
        .hitTestBehavior(HitTestMode.None)

      // 2. 飞机 3D 实体主图
      Image($r('app.media.b737_800_top_3'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .opacity(this.isFullFocusMode ? 0 : this.planeOpacity)
        .scale({
          x: this.planeScale,
          y: this.planeScale
        })
        .rotate({ angle: this.planeRotate })
        .translate({ x: this.planeX, y: this.planeY })
        .hitTestBehavior((this.isMapBackgroundVisible && !this.isCabinExposed) ? HitTestMode.None : HitTestMode.Transparent)

      // 2.5 全屏暗色遮罩：覆盖在放大的飞机之上，选座卡片之下 (使用 if 控制 DOM 挂载，绝对不阻挡底层点击)
      if (this.isFullFocusMode) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#0F172A') // 深邃沉浸暗夜蓝
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .transition(TransitionEffect.OPACITY.animation({ duration: 2500, curve: Curve.EaseInOut }))
          .hitTestBehavior(HitTestMode.None)
      }

      // 3. 放大后的机身无缝剖开与透视机舱
      if (this.isCabinExposed) {
        CabinInteriorOverlay({
          onSeatClick: (seatId: string): void => {
            if (this.onSeatClick) {
              this.onSeatClick(seatId);
            }
          },
          onConfirmFlight: (seatId: string, tagId: string, durationMinutes: number): void => {
            if (this.onConfirmFlight) {
              this.onConfirmFlight(seatId, tagId, durationMinutes);
            }
          }
        })
          .width('100%')
          .height('100%')
          .opacity(this.isCabinExposed ? 1 : 0)
          .scale({ x: this.isCabinExposed ? 1 : 0.9, y: this.isCabinExposed ? 1 : 0.9 })
          .animation({ duration: 600, curve: Curve.EaseOut })
          .zIndex(20)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
