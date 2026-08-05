/**
 * RightLayerControls.ets
 * 右侧图层控制面板 (Right Layer Controls)
 * 仿照标杆航空 UI：城市节点、其他玩家显隐、飞机标签显隐
 */

@Component
export struct RightLayerControls {
  @State showCity: boolean = true;
  @State showOtherPlayers: boolean = true;
  @State showPlaneLabels: boolean = true;

  // 城市图标
  @Builder
  CityIcon() {
    Path()
      .commands('M 12 2 L 2 7 V 22 H 22 V 7 Z M 8 10 H 10 V 13 H 8 Z M 14 10 H 16 V 13 H 14 Z M 8 15 H 10 V 18 H 8 Z M 14 15 H 16 V 18 H 14 Z')
      .fill('#F8FAFC')
      .width(16)
      .height(16)
  }

  // 眼睛眼睛显隐图标
  @Builder
  EyeIcon(enabled: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      Path()
        .commands('M 12 4.5 C 7 4.5 2.7 7.6 1 12 C 2.7 16.4 7 19.5 12 19.5 C 17 19.5 21.3 16.4 23 12 C 21.3 7.6 17 4.5 12 4.5 Z M 12 17 C 9.2 17 7 14.8 7 12 C 7 9.2 9.2 7 12 7 C 14.8 7 17 9.2 17 12 C 17 14.8 14.8 17 12 17 Z M 12 9 C 10.3 9 9 10.3 9 12 C 9 13.7 10.3 15 12 15 C 13.7 15 15 13.7 15 12 C 15 10.3 13.7 9 12 9 Z')
        .fill(enabled ? '#F8FAFC' : '#64748B')
        .width(16)
        .height(16)
    }
    .width(16)
    .height(16)
  }

  build() {
    Column({ space: 8 }) {
      // 1. 城市图层
      Row({ space: 6 }) {
        this.CityIcon()
        Text('城市')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F8FAFC')
      }
      .padding({ left: 12, right: 14, top: 7, bottom: 7 })
      .backgroundColor('rgba(15, 23, 42, 0.78)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 16 })
      .borderRadius(16)
      .onClick(() => { this.showCity = !this.showCity; })

      // 2. 其他玩家图层
      Row({ space: 6 }) {
        this.EyeIcon(this.showOtherPlayers)
        Text('其他玩家')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.showOtherPlayers ? '#F8FAFC' : '#64748B')
      }
      .padding({ left: 12, right: 14, top: 7, bottom: 7 })
      .backgroundColor('rgba(15, 23, 42, 0.78)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 16 })
      .borderRadius(16)
      .onClick(() => { this.showOtherPlayers = !this.showOtherPlayers; })

      // 3. 飞机标签图层
      Row({ space: 6 }) {
        this.EyeIcon(this.showPlaneLabels)
        Text('飞机标签')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.showPlaneLabels ? '#F8FAFC' : '#64748B')
      }
      .padding({ left: 12, right: 14, top: 7, bottom: 7 })
      .backgroundColor('rgba(15, 23, 42, 0.78)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 16 })
      .borderRadius(16)
      .onClick(() => { this.showPlaneLabels = !this.showPlaneLabels; })
    }
    .padding({ right: 16, top: 12 })
  }
}
