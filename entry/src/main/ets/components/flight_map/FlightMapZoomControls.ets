/**
 * 🎯 右侧地图缩放悬浮控制器 (+ / − 按钮与当前缩放倍率展示)
 */
@Component
export struct FlightMapZoomControls {
  @Prop currentZoomLevel: number = 5.5;
  onZoomIn?: () => void;
  onZoomOut?: () => void;

  build() {
    Column({ space: 4 }) {
      Row() {
        Text('+')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
      }
      .width(34)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(15, 23, 42, 0.85)')
      .borderRadius(17)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
      .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.3)', offsetY: 2 })
      .onClick(() => {
        if (this.onZoomIn) this.onZoomIn();
      })

      Column({ space: 1 }) {
        Text(`${this.currentZoomLevel.toFixed(1)}x`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F06553')
      }
      .padding({ top: 2, bottom: 2 })

      Row() {
        Text('−')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
      }
      .width(34)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(15, 23, 42, 0.85)')
      .borderRadius(17)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
      .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.3)', offsetY: 2 })
      .onClick(() => {
        if (this.onZoomOut) this.onZoomOut();
      })
    }
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
