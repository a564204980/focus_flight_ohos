import { CabinInteriorOverlay } from './CabinInteriorOverlay';

/**
 * PlaneCabinShellOverlay.ets
 * 飞机实体、地面阴影、11.8 倍放大剖开外壳与透视机舱联动组件
 */

@Component
export struct PlaneCabinShellOverlay {
  @Prop isMapBackgroundVisible: boolean = false;
  @Prop isCabinExposed: boolean = false;
  @Prop planeScale: number = 1.0;
  @Prop currentZoomScale: number = 1.0;
  @Prop planeX: number = 0;
  @Prop planeY: number = -45;
  @Prop planeRotate: number = 0;
  @Prop shellSplitOffset: number = 0;

  onSeatClick?: (seatId: string) => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 飞机地面阴影
      Image($r('app.media.b737_800_top_3_shadow'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .visibility((this.isMapBackgroundVisible && !this.isCabinExposed) ? Visibility.None : Visibility.Visible)
        .opacity((this.isMapBackgroundVisible && !this.isCabinExposed) ? 0 : 1.0)
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
        .visibility((this.isMapBackgroundVisible && !this.isCabinExposed) ? Visibility.None : Visibility.Visible)
        .opacity((this.isMapBackgroundVisible && !this.isCabinExposed) ? 0 : 1.0)
        .scale({
          x: this.planeScale,
          y: this.planeScale
        })
        .rotate({ angle: this.planeRotate })
        .translate({ x: this.planeX, y: this.planeY })
        .hitTestBehavior((this.isMapBackgroundVisible && !this.isCabinExposed) ? HitTestMode.None : HitTestMode.Transparent)

      // 3. 放大后的机身无缝剖开与透视机舱
      if (this.isCabinExposed) {
        Stack({ alignContent: Alignment.Center }) {
          // 下层：全景机舱内部与座位
          CabinInteriorOverlay({
            onSeatClick: (seatId: string): void => {
              if (this.onSeatClick) {
                this.onSeatClick(seatId);
              }
            }
          })
            .opacity(this.isCabinExposed ? 1 : 0)
            .scale({ x: this.isCabinExposed ? 1 : 0.9, y: this.isCabinExposed ? 1 : 0.9 })
            .animation({ duration: 600, curve: Curve.EaseOut })

          // 上层：与主飞机 100% 保持同等 11.8 倍放大倍率的左右剖开外壳
          Row() {
            // 左半机身真实外壳
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.b737_800_top_3'))
                .width(300)
                .height(428.7)
                .objectFit(ImageFit.Contain)
                .scale({ x: this.planeScale, y: this.planeScale })
                .translate({ x: 82.5, y: this.planeY - 50 })

              Column()
                .width('100%')
                .height('100%')
                .border({ width: { right: 2 }, color: 'rgba(180, 160, 140, 0.85)' })
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.12)', offsetX: 3 })
            }
            .width('50%')
            .height('100%')
            .clip(true)
            .translate({ x: -this.shellSplitOffset })
            .opacity(1 - this.shellSplitOffset / 320)

            // 右半机身真实外壳
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.b737_800_top_3'))
                .width(300)
                .height(428.7)
                .objectFit(ImageFit.Contain)
                .scale({ x: this.planeScale, y: this.planeScale })
                .translate({ x: -82.5, y: this.planeY - 50 })

              Column()
                .width('100%')
                .height('100%')
                .border({ width: { left: 2 }, color: 'rgba(180, 160, 140, 0.85)' })
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.12)', offsetX: -3 })
            }
            .width('50%')
            .height('100%')
            .clip(true)
            .translate({ x: this.shellSplitOffset })
            .opacity(1 - this.shellSplitOffset / 320)
          }
          .width('100%')
          .height('100%')
          .clip(true)
          .hitTestBehavior(HitTestMode.None)
        }
        .width('88%')
        .height(530)
        .borderRadius(24)
        .clip(true)
        .translate({ y: 50 })
        .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.08)', offsetY: 4 })
        .zIndex(20)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
