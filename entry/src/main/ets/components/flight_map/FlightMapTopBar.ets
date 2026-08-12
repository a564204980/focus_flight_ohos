import { findAirportByCode } from '../../models/AirportModel';

/**
 * 🎯 顶部航线状态条：起点/终点信息卡片 + 关闭按钮
 */
@Component
export struct FlightMapTopBar {
  @Prop selectedCode: string = '';
  @Prop currentMinutes: number = 15;
  @Prop routeDistanceKm: number = 0;
  @Prop ctuScreenX: number = 0;
  @Prop ctuScreenY: number = 0;
  @Prop currentZoomLevel: number = 5.5;
  onClose?: () => void;

  build() {
    Row() {
      Row({ space: 10 }) {
        Row({ space: 6 }) {
          Text('成都')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text('✈️')
            .fontSize(11)
          Text(this.selectedCode
            ? (findAirportByCode(this.selectedCode)?.city || this.selectedCode)
            : '选择目的地')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.selectedCode ? '#F06553' : 'rgba(255, 255, 255, 0.55)')
          Text(`[X:${Math.round(this.ctuScreenX)} Y:${Math.round(this.ctuScreenY)} Z:${this.currentZoomLevel}]`)
            .fontSize(9)
            .fontColor('#FFD700')
        }

        Divider()
          .vertical(true)
          .height(12)
          .color('rgba(255, 255, 255, 0.2)')

        Text(this.selectedCode
          ? `${Math.round(this.routeDistanceKm)} km · ${this.currentMinutes}min`
          : `待选择 · ${this.currentMinutes}min`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#94A3B8')
      }
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor('rgba(15, 23, 42, 0.88)')
      .borderRadius(20)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
      .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.35)', offsetY: 3 })

      Blank()

      // 右侧关闭 ✕
      Row() {
        Text('✕')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#94A3B8')
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(15, 23, 42, 0.88)')
      .borderRadius(18)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)' })
      .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.3)', offsetY: 2 })
      .onClick(() => {
        if (this.onClose) this.onClose();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
