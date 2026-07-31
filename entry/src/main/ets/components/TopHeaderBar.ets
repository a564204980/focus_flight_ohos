/**
 * TopHeaderBar.ets
 * 专注飞行 - 顶部状态栏 (Focus Header Bar)
 * 纯粹极简品牌展示（已移除顶部的三个状态模块）
 */

@Component
export struct TopHeaderBar {
  // 飞行品牌 Logo
  @Builder
  BrandLogo() {
    Path()
      .commands('M 12 2 L 2 19 L 12 15 L 22 19 Z')
      .fill('#38BDF8')
      .width(18)
      .height(18)
  }

  build() {
    Row() {
      // 左侧：品牌 Logo 与标题
      Row({ space: 8 }) {
        this.BrandLogo()
        Text('Focus Flight')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
        Text('专注飞行')
          .fontSize(11)
          .fontColor('#94A3B8')
      }
      .padding({ left: 14, right: 16, top: 8, bottom: 8 })
      .backgroundColor('rgba(10, 15, 26, 0.82)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 18 })
      .borderRadius(18)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }
}
