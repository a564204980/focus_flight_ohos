import { CabinInteriorOverlay } from './CabinInteriorOverlay';

/**
 * PlaneCabinShellOverlay.ets
 * 飞机实体、地面阴影、机身皮肤涂装【自机头向机尾推进覆盖】全息激光扫掠换装动效、11.8 倍放大剖开外壳与透视机舱联动组件
 */

@Component
export struct PlaneCabinShellOverlay {
  @Watch('onSkinChange') @StorageLink('selectedPlaneSkinIndex') selectedPlaneSkinIndex: number = 0;
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
  @Prop selectedDurationMinutes: number = 15;

  onSeatClick?: (seatId: string) => void;
  onConfirmFlight?: (seatId: string, tagId: string, durationMinutes: number) => void;

  // ✈️ 自机头向机尾推进覆盖状态
  @State currentSkinIndex: number = 0; // 底层旧皮肤
  @State topSkinIndex: number = 0;     // 顶层推进展开新皮肤
  @State sweepProgress: number = 1.0;  // 0.0 -> 1.0 推进覆盖进度
  @State isSweeping: boolean = false;

  aboutToAppear(): void {
    this.currentSkinIndex = this.selectedPlaneSkinIndex;
    this.topSkinIndex = this.selectedPlaneSkinIndex;
    this.sweepProgress = 1.0;
  }

  onSkinChange(): void {
    const nextSkin = this.selectedPlaneSkinIndex;
    if (nextSkin !== this.topSkinIndex) {
      // 1. 底层先固定为当前皮肤作为垫底背景
      this.currentSkinIndex = this.topSkinIndex;
      // 2. 顶层设定为新皮肤，扫掠高度归零
      this.topSkinIndex = nextSkin;
      this.sweepProgress = 0.0;
      this.isSweeping = true;

      // 3. 启动自机头向机尾推进的平滑扫掠动效 (900ms 丝滑 FastOutSlowIn)
      setTimeout(() => {
        this.getUIContext()?.animateTo({
          duration: 900,
          curve: Curve.FastOutSlowIn,
          onFinish: () => {
            this.currentSkinIndex = nextSkin;
            this.isSweeping = false;
          }
        }, () => {
          this.sweepProgress = 1.0;
        });
      }, 30);
    }
  }

  private getPlaneImageByIndex(skinIndex: number): Resource {
    if (skinIndex === 1) {
      return $r('app.media.plane_skin_whale');
    }
    if (skinIndex === 2) {
      return $r('app.media.plane_skin_aurora');
    }
    return $r('app.media.plane_skin_cat');
  }

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
      Image(this.getPlaneImageByIndex(this.selectedPlaneSkinIndex))
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
      // 2.5 全屏暗色遮罩：覆盖在放大的飞机之上，选座卡片之下
      if (this.isFullFocusMode) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#0F172A')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .transition(TransitionEffect.OPACITY.animation({ duration: 2500, curve: Curve.EaseInOut }))
          .hitTestBehavior(HitTestMode.None)
      }

      // 3. 放大后的机身无缝剖开与透视机舱
      if (this.isCabinExposed) {
        CabinInteriorOverlay({
          selectedDurationMinutes: this.selectedDurationMinutes,
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
