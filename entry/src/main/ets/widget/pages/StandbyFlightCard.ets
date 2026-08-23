const ACTION_ROUTER: string = 'router';
const ABILITY_NAME: string = 'EntryAbility';

@Entry
@Component
struct StandbyFlightCard {
  /*
   * 🎛️ 卡片属性参数（由 EntryFormAbility 或 formBindingData 实时驱动）
   */
  readonly flightNo: string = 'FF-2026';
  readonly taskTitle: string = '深度专注';
  readonly originCode: string = 'CTU';
  readonly destCode: string = 'PEK';
  readonly destCity: string = '北京';
  readonly remainingTime: string = '25:00';
  readonly remainingKm: number = 1680;
  readonly progressPercent: number = 45;
  readonly isFlightActive: boolean = false;
  readonly todayFocusHours: string = '2.5';
  readonly rankTitle: string = '资深机长';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. OLED 纯黑背景 + 微光星空底纹
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#030712')

      // 2. 极光微光渐变氛围晕影
      Row()
        .width('140%')
        .height('140%')
        .radialGradient({
          center: ['50%', '30%'],
          radius: '70%',
          colors: [
            ['rgba(99, 102, 241, 0.15)', 0.0],
            ['rgba(56, 189, 248, 0.08)', 0.5],
            ['rgba(3, 7, 18, 0)', 1.0]
          ]
        })

      // 3. 卡片主内容区
      Column() {
        // 顶部航线状态栏
        Row() {
          Row({ space: 4 }) {
            Text('✈️')
              .fontSize(12)
            Text(`${this.originCode} ➔ ${this.destCode}`)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
          }
          .padding({ left: 6, right: 8, top: 3, bottom: 3 })
          .backgroundColor('rgba(30, 41, 59, 0.7)')
          .borderRadius(8)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })

          Blank()

          // 状态胶囊标签
          Row({ space: 4 }) {
            Circle({ width: 5, height: 5 })
              .fill(this.isFlightActive ? '#10B981' : '#6366F1')
            Text(this.isFlightActive ? '巡航中' : this.rankTitle)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isFlightActive ? '#34D399' : '#A5B4FC')
          }
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.isFlightActive ? 'rgba(16, 185, 129, 0.15)' : 'rgba(99, 102, 241, 0.12)')
          .borderRadius(6)
        }
        .width('100%')

        Blank()

        // 中间核心：赛博翻页大时钟 / 倒计时
        Column({ space: 2 }) {
          Text(this.isFlightActive ? this.remainingTime : `${this.todayFocusHours}h`)
            .fontSize(36)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')
            .fontFamily('HarmonyOS Sans')
            .shadow({ radius: 12, color: 'rgba(99, 102, 241, 0.4)', offsetX: 0, offsetY: 2 })

          Text(this.isFlightActive ? `飞往${this.destCity} · 剩余 ${this.remainingKm}KM` : `今日累计飞行 · ${this.taskTitle}`)
            .fontSize(10)
            .fontColor('#94A3B8')
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Center)

        Blank()

        // 底部进度条与一键起飞
        Column({ space: 6 }) {
          // 胶囊进度条
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(4)
              .backgroundColor('rgba(255, 255, 255, 0.1)')
              .borderRadius(2)

            Row()
              .width(`${Math.max(5, Math.min(100, this.progressPercent))}%`)
              .height(4)
              .linearGradient({
                angle: 90,
                colors: [
                  ['#6366F1', 0.0],
                  ['#38BDF8', 1.0]
                ]
              })
              .borderRadius(2)
          }
          .width('100%')

          // 快捷操作栏
          Row() {
            Text(this.isFlightActive ? '点击回舱查看航迹 ➔' : '一键登机启航 ➔')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor('#60A5FA')

            Blank()

            Text(this.isFlightActive ? `${this.progressPercent}%` : '25m 航班')
              .fontSize(10)
              .fontColor('#64748B')
          }
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        action: ACTION_ROUTER,
        abilityName: ABILITY_NAME,
        params: {
          message: 'from_standby_card'
        }
      });
    })
  }
}
