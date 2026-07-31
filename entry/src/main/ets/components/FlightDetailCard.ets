/**
 * FlightDetailCard.ets (Focus Session Card)
 * 专注飞行 - 核心专注任务与计时面板
 * 仿图 1 极客玻璃拟态风格，融合番茄钟与航线巡航沉浸体验
 */

@Component
export struct FlightDetailCard {
  @State isExpanded: boolean = true;
  @State isTimerRunning: boolean = true;
  @State flightNo: string = 'Focus-01';
  @State focusTaskName: string = '深度高效学习航线';
  @State timerDisplay: string = '22:45';
  @State totalDuration: string = '25:00';
  @State focusEfficiency: string = '100%';
  @State altitude: string = 'FL250';
  @State milesEarned: string = '+225 KM';
  @State statusText: string = '巡航专注中';

  // 飞行徽章图标
  @Builder
  PlaneBadgeIcon() {
    Path()
      .commands('M 2 12 L 8 10 L 11 12 L 16 7 C 17 6 18 6 19 7 L 19 7 C 20 8 20 9.5 19 10.5 L 14 15 L 12 12 L 9 13.5 L 7.5 12 Z')
      .fill('#38BDF8')
      .width(14)
      .height(14)
  }

  build() {
    Column() {
      // 1. 卡片页眉（专注航班号、任务名称、沉浸标签）
      Row() {
        Row({ space: 6 }) {
          this.PlaneBadgeIcon()
          Text(this.flightNo)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }

        Blank()

        Row({ space: 6 }) {
          Text('深度沉浸')
            .fontSize(10)
            .fontColor('#38BDF8')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(56, 189, 248, 0.15)')
            .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 10 })
            .borderRadius(10)

          Text('番茄钟')
            .fontSize(10)
            .fontColor('#4ADE80')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(74, 222, 128, 0.15)')
            .border({ width: 1, color: 'rgba(74, 222, 128, 0.35)', radius: 10 })
            .borderRadius(10)
        }
      }
      .width('100%')

      // 任务标题小字
      Row() {
        Text(this.focusTaskName)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#CBD5E1')
      }
      .width('100%')
      .margin({ top: 4, bottom: 10 })

      if (this.isExpanded) {
        // 2. 专注倒计时与飞行进度条
        Column({ space: 6 }) {
          Row() {
            Column({ space: 2 }) {
              Text('起飞点')
                .fontSize(10)
                .fontColor('#64748B')
              Text('00:00')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            // 核心计时数字
            Column() {
              Text(this.timerDisplay)
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .fontColor('#38BDF8')
              Text(`目标时长 ${this.totalDuration}`)
                .fontSize(11)
                .fontColor('#94A3B8')
            }

            Blank()

            Column({ space: 2 }) {
              Text('降落点')
                .fontSize(10)
                .fontColor('#64748B')
              Text(this.totalDuration)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')

          // 进度条与飞机标记
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: 15, total: 100, type: ProgressType.Linear })
              .color('#38BDF8')
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .height(6)
              .borderRadius(3)

            Path()
              .commands('M 0 6 L 8 4 L 11 6 L 16 1 C 17 0 18 0 19 1 C 20 2 20 3.5 19 4.5 L 14 9 L 12 6 Z')
              .fill('#38BDF8')
              .width(14)
              .height(14)
          }
          .margin({ top: 6, bottom: 6 })
        }
        .width('100%')
        .padding({ top: 12, bottom: 12, left: 14, right: 14 })
        .backgroundColor('rgba(255, 255, 255, 0.04)')
        .borderRadius(14)
        .margin({ bottom: 12 })

        // 3. 专注 Telemetry 参数面板
        Row() {
          Column({ space: 2 }) {
            Text('专注状态')
              .fontSize(10)
              .fontColor('#64748B')
            Text(this.statusText)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#4ADE80')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 2 }) {
            Text('专注效率')
              .fontSize(10)
              .fontColor('#64748B')
            Text(this.focusEfficiency)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 2 }) {
            Text('巡航海拔')
              .fontSize(10)
              .fontColor('#64748B')
            Text(this.altitude)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 2 }) {
            Text('累积里程')
              .fontSize(10)
              .fontColor('#64748B')
            Text(this.milesEarned)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F59E0B')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .margin({ bottom: 12 })

        Divider().color('rgba(255, 255, 255, 0.08)').margin({ bottom: 12 })

        // 4. 专注操作按钮
        Row({ space: 10 }) {
          Button(this.isTimerRunning ? '暂停专注' : '继续专注')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.isTimerRunning ? 'rgba(56, 189, 248, 0.2)' : 'rgba(74, 222, 128, 0.2)')
            .fontColor(this.isTimerRunning ? '#38BDF8' : '#4ADE80')
            .border({ width: 1, color: this.isTimerRunning ? 'rgba(56, 189, 248, 0.4)' : 'rgba(74, 222, 128, 0.4)', radius: 18 })
            .borderRadius(18)
            .onClick(() => {
              this.isTimerRunning = !this.isTimerRunning;
            })

          Button('提前降落')
            .height(36)
            .padding({ left: 16, right: 16 })
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('rgba(255, 255, 255, 0.06)')
            .fontColor('#94A3B8')
            .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 18 })
            .borderRadius(18)
        }
        .width('100%')
      }

      // 展开/折叠控制
      Row() {
        Text(this.isExpanded ? '∧' : '∨')
          .fontSize(11)
          .fontColor('#94A3B8')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 6 })
      .onClick(() => {
        this.isExpanded = !this.isExpanded;
      })
    }
    .width(340)
    .padding(14)
    .backgroundColor('rgba(10, 15, 26, 0.86)')
    .border({ width: 1, color: 'rgba(255, 255, 255, 0.14)', radius: 20 })
    .borderRadius(20)
    .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.55)', offsetY: 6 })
  }
}
