/**
 * LeftSidebarDock.ets
 * 左侧悬浮控制坞 (Left Sidebar Dock)
 * 仿照标杆航空 UI：仪表盘、维保、合作、VIP、财务与设置
 */

@Component
export struct LeftSidebarDock {
  @State activeIndex: number = 0;

  // 1. 仪表盘图标
  @Builder
  GaugeIcon(color: string) {
    Path()
      .commands('M 12 4 C 7 4 3 8 3 13 C 3 18 7 22 12 22 C 17 22 21 18 21 13 C 21 8 17 4 12 4 Z M 12 11 L 16 8 L 13.5 13.5 Z')
      .fill(color)
      .width(20)
      .height(20)
  }

  // 2. 扳手/维保图标
  @Builder
  WrenchIcon(color: string) {
    Path()
      .commands('M 14.7 3.3 C 13.4 4.6 13.2 6.6 14.1 8.1 L 4.4 17.8 C 3.8 18.4 3.8 19.4 4.4 20 C 5 20.6 6 20.6 6.6 20 L 16.3 10.3 C 17.8 11.2 19.8 11 21.1 9.7 C 22.3 8.5 22.5 6.7 21.7 5.3 L 18.5 8.5 L 15.9 5.9 L 19.1 2.7 C 17.7 1.9 15.9 2.1 14.7 3.3 Z')
      .fill(color)
      .width(20)
      .height(20)
  }

  // 3. 握手/合作图标
  @Builder
  HandshakeIcon(color: string) {
    Path()
      .commands('M 4 12 L 8 8 L 12 12 L 10 14 M 20 12 L 16 8 L 12 12 L 14 14 M 8 16 L 12 20 L 16 16')
      .stroke(color)
      .strokeWidth(2)
      .fill('none')
      .width(20)
      .height(20)
  }

  // 4. VIP 文本图标
  @Builder
  VipIcon(color: string) {
    Text('VIP')
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(color)
  }

  // 5. 银行/财务建筑图标
  @Builder
  BankIcon(color: string) {
    Path()
      .commands('M 12 2 L 2 7 V 9 H 22 V 7 Z M 4 10 H 6 V 17 H 4 Z M 9 10 H 11 V 17 H 9 Z M 14 10 H 16 V 17 H 14 Z M 19 10 H 21 V 17 H 19 Z M 2 19 H 22 V 21 H 2 Z')
      .fill(color)
      .width(20)
      .height(20)
  }

  // 6. 齿轮/设置图标
  @Builder
  GearIcon(color: string) {
    Path()
      .commands('M 12 8 C 9.8 8 8 9.8 8 12 C 8 14.2 9.8 16 12 16 C 14.2 16 16 14.2 16 12 C 16 9.8 14.2 8 12 8 Z M 19.4 13 C 19.5 12.7 19.5 12.3 19.5 12 C 19.5 11.7 19.5 11.3 19.4 11 L 21.5 9.4 C 21.7 9.2 21.8 8.9 21.6 8.6 L 19.6 5.2 C 19.5 4.9 19.2 4.8 18.9 4.9 L 16.4 5.9 C 15.9 5.5 15.3 5.2 14.7 4.9 L 14.3 2.3 C 14.3 2.1 14.1 1.9 13.8 1.9 L 9.8 1.9 C 9.5 1.9 9.3 2.1 9.3 2.3 L 8.9 4.9 C 8.3 5.2 7.7 5.5 7.2 5.9 L 4.7 4.9 C 4.4 4.8 4.1 4.9 4 5.2 L 2 8.6 C 1.8 8.9 1.9 9.2 2.1 9.4 L 4.2 11 C 4.1 11.3 4.1 11.7 4.1 12 C 4.1 12.3 4.1 12.7 4.2 13 L 2.1 14.6 C 1.9 14.8 1.8 15.1 2 15.4 L 4 18.8 C 4.1 19.1 4.4 19.2 4.7 19.1 L 7.2 18.1 C 7.7 18.5 8.3 18.8 8.9 19.1 L 9.3 21.7 C 9.3 21.9 9.5 22.1 9.8 22.1 L 13.8 22.1 C 14.1 22.1 14.3 21.9 14.3 21.7 L 14.7 19.1 C 15.3 18.8 15.9 18.5 16.4 18.1 L 18.9 19.1 C 19.2 19.2 19.5 19.1 19.6 18.8 L 21.6 15.4 C 21.8 15.1 21.7 14.8 21.5 14.6 Z')
      .fill(color)
      .width(20)
      .height(20)
  }

  // 7. 旗帜任务图标
  @Builder
  FlagIcon() {
    Path()
      .commands('M 5 3 V 21 M 5 4 H 19 L 14 9 L 19 14 H 5')
      .stroke('#F8FAFC')
      .strokeWidth(2)
      .fill('none')
      .width(20)
      .height(20)
  }

  build() {
    Column() {
      // 侧边核心 Dock 胶囊
      Column({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          this.GaugeIcon(this.activeIndex === 0 ? '#F59E0B' : '#F8FAFC')
        }
        .width(36)
        .height(36)
        .onClick(() => { this.activeIndex = 0; })

        Stack({ alignContent: Alignment.Center }) {
          this.WrenchIcon(this.activeIndex === 1 ? '#F59E0B' : '#F8FAFC')
        }
        .width(36)
        .height(36)
        .onClick(() => { this.activeIndex = 1; })

        Stack({ alignContent: Alignment.Center }) {
          this.HandshakeIcon(this.activeIndex === 2 ? '#F59E0B' : '#F8FAFC')
        }
        .width(36)
        .height(36)
        .onClick(() => { this.activeIndex = 2; })

        Stack({ alignContent: Alignment.Center }) {
          this.VipIcon(this.activeIndex === 3 ? '#F59E0B' : '#F8FAFC')
        }
        .width(36)
        .height(36)
        .onClick(() => { this.activeIndex = 3; })

        Stack({ alignContent: Alignment.Center }) {
          this.BankIcon(this.activeIndex === 4 ? '#F59E0B' : '#F8FAFC')
        }
        .width(36)
        .height(36)
        .onClick(() => { this.activeIndex = 4; })

        Stack({ alignContent: Alignment.Center }) {
          this.GearIcon(this.activeIndex === 5 ? '#F59E0B' : '#F8FAFC')
        }
        .width(36)
        .height(36)
        .onClick(() => { this.activeIndex = 5; })
      }
      .padding({ top: 12, bottom: 12, left: 6, right: 6 })
      .backgroundColor('rgba(15, 23, 42, 0.78)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 22 })
      .borderRadius(22)

      Blank()

      // 左下角任务旗帜按键
      Stack({ alignContent: Alignment.Center }) {
        this.FlagIcon()
      }
      .width(42)
      .height(42)
      .backgroundColor('rgba(15, 23, 42, 0.78)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 21 })
      .borderRadius(21)
      .margin({ bottom: 28 })
    }
    .height('100%')
    .padding({ left: 16, top: 12 })
  }
}
