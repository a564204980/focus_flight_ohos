/**
 * BottomNavBar.ets
 * Focus Flight 高级暗黑玻璃悬浮导航舱 (Pure White Icons & Typography)
 * 底部图标与文字统一使用纯白 (#FFFFFF) / 柔白 (rgba(255,255,255,0.55)) 色彩系统
 */

export interface NavTabItem {
  id: number;
  title: string;
}

@Component
export struct BottomNavBar {
  @Link activeIndex: number;

  private tabs: NavTabItem[] = [
    { id: 0, title: '专注' },
    { id: 1, title: '日志' },
    { id: 2, title: '机库' }
  ];

  build() {
    Row({ space: 4 }) {
      ForEach(this.tabs, (tab: NavTabItem) => {
        Column({ space: 3 }) {
          // 上：20vp 高清矢量图标 (选中态 Flight Ice Blue #0284C7，未选中态灰黑 55% 透明度)
          if (tab.id === 0) {
            Image($r('app.media.ic_airport'))
              .width(20)
              .height(20)
              .fillColor(this.activeIndex === tab.id ? '#0284C7' : 'rgba(15, 23, 42, 0.55)')
          } else if (tab.id === 1) {
            Image($r('app.media.ic_logbook'))
              .width(20)
              .height(20)
              .fillColor(this.activeIndex === tab.id ? '#0284C7' : 'rgba(15, 23, 42, 0.55)')
          } else {
            Image($r('app.media.ic_hangar'))
              .width(20)
              .height(20)
              .fillColor(this.activeIndex === tab.id ? '#0284C7' : 'rgba(15, 23, 42, 0.55)')
          }

          // 下：11fp 舒展文本 (选中态 Flight Ice Blue #0284C7，未选中态灰黑 55% 透明度)
          Text(tab.title)
            .fontSize(11)
            .fontWeight(this.activeIndex === tab.id ? FontWeight.Bolder : FontWeight.Medium)
            .fontColor(this.activeIndex === tab.id ? '#0284C7' : 'rgba(15, 23, 42, 0.55)')
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
        .height(46)
        .backgroundColor(this.activeIndex === tab.id ? 'rgba(2, 132, 199, 0.15)' : 'transparent')
        .borderRadius(23) // 同心全胶囊 (46 / 2 = 23vp)
        .onClick(() => {
          this.getUIContext()?.animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
            this.activeIndex = tab.id;
          });
        })
      }, (tab: NavTabItem) => tab.id.toString())
    }
    .width(340) // 100% 对齐上方 FocusCheckInCard 的 340vp 宽度
    .height(56)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 5, right: 5, top: 5, bottom: 5 })
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .backdropBlur(30)
    .border({ width: 1, color: 'rgba(255, 255, 255, 0.9)', radius: 28 })
    .borderRadius(28)
    .shadow({ radius: 30, color: 'rgba(2, 132, 199, 0.15)', offsetY: 12 })
    .margin({ bottom: 24 })
  }
}
