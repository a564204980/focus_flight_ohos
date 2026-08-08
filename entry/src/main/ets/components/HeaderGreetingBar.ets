/**
 * HeaderGreetingBar.ets
 * 首页顶部 Cyber HUD 状态栏（包含“早上好 / 航班就绪 / CTU ✈️ PEK”战术简报）
 */

@Component
export struct HeaderGreetingBar {
  @Prop isHudVisible: boolean = true;
  @Prop isFullFocusMode: boolean = false;
  @Prop isMapBackgroundVisible: boolean = false;
  @State greetingText: string = '你好';

  aboutToAppear() {
    const hour = new Date().getHours();
    if (hour >= 0 && hour < 6) {
      this.greetingText = '凌晨好';
    } else if (hour >= 6 && hour < 9) {
      this.greetingText = '早上好';
    } else if (hour >= 9 && hour < 12) {
      this.greetingText = '上午好';
    } else if (hour >= 12 && hour < 14) {
      this.greetingText = '中午好';
    } else if (hour >= 14 && hour < 18) {
      this.greetingText = '下午好';
    } else {
      this.greetingText = '晚上好';
    }
  }

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.greetingText)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')

        Row({ space: 4 }) {
          Text('✔')
            .fontSize(11)
            .fontColor('#10B981')
          Text('航班就绪')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')
        }
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Row({ space: 8 }) {
        Row() {
          Text('CTU 成都双流国际机场')
            .fontSize(11)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#D97706')
        }
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor('rgba(251, 191, 36, 0.15)')
        .borderRadius(4)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 56 })
    .position({ x: 0, y: 0 })
    .opacity((this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 1 : 0)
    .animation({ duration: 800, curve: Curve.EaseOut })
    .zIndex(100)
  }
}
