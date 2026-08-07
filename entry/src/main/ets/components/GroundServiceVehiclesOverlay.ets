/**
 * GroundServiceVehiclesOverlay.ets
 * 停机坪地面勤务设备图层（包含加油车、牵引车、廊桥及其浓重地面阴影）
 */

@Component
export struct GroundServiceVehiclesOverlay {
  @Prop isFullFocusMode: boolean = false;
  @Prop isMapBackgroundVisible: boolean = false;
  @Prop isVehiclesDocked: boolean = true;
  @Prop fuelTruckX: number = -350;
  @Prop fuelTruckY: number = 220;
  @Prop fuelTruckRotate: number = 90;

  onFuelTruckClick?: () => void;
  onTractorClick?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 牵引车阴影
      Image($r('app.media.qiangyingche_shadow'))
        .width(90)
        .height(90)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .translate({
          x: (this.isVehiclesDocked ? -125 : -340) + 2,
          y: (this.isVehiclesDocked ? -90 : 120) + 3
        })
        .rotate({ angle: this.isVehiclesDocked ? 0 : 45 })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 2. 加油车阴影
      Image($r('app.media.jiayouche_shadow'))
        .width(110)
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .translate({
          x: this.fuelTruckX + 4,
          y: this.fuelTruckY + 4
        })
        .rotate({ angle: this.fuelTruckRotate })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 3. 廊桥阴影
      Image($r('app.media.langqiao_shadow'))
        .width(320)
        .height(163.6)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .translate({
          x: (this.isVehiclesDocked ? -150 : -380) + 36,
          y: -160 + 18
        })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 4. 地面勤务车辆（加油车实体）
      Image($r('app.media.jiayouche'))
        .width(110)
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .hitTestBehavior((this.isFullFocusMode || this.isMapBackgroundVisible) ? HitTestMode.None : HitTestMode.Default)
        .translate({
          x: this.fuelTruckX,
          y: this.fuelTruckY
        })
        .rotate({ angle: this.fuelTruckRotate })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .onClick(() => {
          if (this.onFuelTruckClick) {
            this.onFuelTruckClick();
          }
        })

      // 5. 地面勤务车辆（牵引车实体）
      Image($r('app.media.qiangyingche'))
        .width(90)
        .height(90)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .hitTestBehavior((this.isFullFocusMode || this.isMapBackgroundVisible) ? HitTestMode.None : HitTestMode.Default)
        .translate({
          x: this.isVehiclesDocked ? -125 : -340,
          y: this.isVehiclesDocked ? -90 : 120
        })
        .rotate({ angle: this.isVehiclesDocked ? 0 : 45 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .onClick(() => {
          if (this.onTractorClick) {
            this.onTractorClick();
          }
        })

      // 6. 廊桥实体
      Image($r('app.media.langqiao'))
        .width(320)
        .height(163.6)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .translate({ x: this.isVehiclesDocked ? -150 : -380, y: -160 })
        .animation({ duration: 800, curve: Curve.EaseOut })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
