import { router } from '@kit.ArkUI';

@Component
export struct DistractionReportView {
  onClose?: () => void;

  build() {
    Column() {
      // 头部导航栏
      Row() {
        // 关闭按钮
        Row() {
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(20)
            .height(20)
            .fillColor('rgba(255,255,255,0.7)')
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('rgba(255,255,255,0.1)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.onClose) this.onClose();
        })

        Text("深度分心报告")
          .fontSize(16)
          .fontColor("#FFFFFF")
          .fontWeight(FontWeight.Bold)

        // 分享按钮
        Row() {
          Image($r('sys.media.ohos_ic_public_share'))
            .width(20)
            .height(20)
            .fillColor('rgba(255,255,255,0.7)')
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('rgba(255,255,255,0.1)')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 20, right: 20, top: 48, bottom: 20 })

      Scroll() {
        Column({ space: 30 }) {
          
          // 1. 核心概览 (Summary)
          Column({ space: 8 }) {
            Text("52%")
              .fontSize(64)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: -10 })
            
            Text("的专注被中途打断")
              .fontSize(22)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Text("在你最近的 27 次专注中，有 14 次未能完美达成")
              .fontSize(14)
              .fontColor("rgba(255,255,255,0.6)")
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          
          // 2. 翻页钟 (Lost to Delays)
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              this.FlipCard("1")
              this.FlipCard("5")
              this.FlipCard("分")
              this.FlipCard("钟")
            }
            
            Text("因分心流失的总时长")
              .fontSize(18)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Text("平均每次打断耗费 1 分钟")
              .fontSize(14)
              .fontColor("rgba(255,255,255,0.6)")
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          
          // 3. 最惨痛打断 (Worst Delay)
          Column({ space: 8 }) {
            Text("最惨痛的摸鱼记录")
              .fontSize(18)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Row() {
              Text("45 分钟")
                .fontSize(16)
                .fontColor("#FCA5A5") // 橙红色
                .fontFamily("HarmonyOS Sans") // 模拟点阵体效果
                .fontWeight(FontWeight.Bold)
              Text("航线: 核心代码")
                .fontSize(16)
                .fontColor("#FCA5A5")
                .fontWeight(FontWeight.Bold)
              Text("切出后台")
                .fontSize(16)
                .fontColor("#FCA5A5")
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor("rgba(0,0,0,0.4)")
            .borderRadius(8)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          
          Divider().color("rgba(255,255,255,0.1)")

          // 4. 专注完成度 (My Performance)
          Column({ space: 16 }) {
            Text("专注完成度")
              .fontSize(18)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Column({ space: 12 }) {
              this.PerformanceBar("完美心流", "37%", "#4ADE80", 0.37)
              this.PerformanceBar("极度投入", "30%", "#86EFAC", 0.30)
              this.PerformanceBar("轻度走神", "14%", "#FBBF24", 0.14)
              this.PerformanceBar("中度摸鱼", "15%", "#F97316", 0.15)
              this.PerformanceBar("中途放弃", "4%", "#EF4444", 0.04)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          
          Divider().color("rgba(255,255,255,0.1)")
          
          // 5. 极易分心场景黑榜 (Worst Distraction Sources)
          Column({ space: 16 }) {
            Text("极易分心场景黑榜")
              .fontSize(18)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Text("在以下标签的专注中，失败率最高")
              .fontSize(14)
              .fontColor("rgba(255,255,255,0.6)")
              .margin({ top: -10 })
              
            Column({ space: 16 }) {
              this.BlacklistBar("背单词", "100% 失败", 1.0)
              this.BlacklistBar("看文献", "75% 打断", 0.75)
              this.BlacklistBar("写周报", "50% 拖延", 0.5)
            }
            .padding({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Row().height(40) // Bottom padding
        }
        .padding({ left: 24, right: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    // 深红色到深褐色的渐变背景，营造警示感
    .linearGradient({
      angle: 180,
      colors: [["#5B1515", 0], ["#2A0808", 0.4], ["#140303", 1]]
    })
  }

  @Builder FlipCard(char: string) {
    Stack() {
      // 上半部分背景
      Column().width('100%').height('50%').backgroundColor('#1A0808').position({ x: 0, y: 0 })
      // 下半部分背景
      Column().width('100%').height('50%').backgroundColor('#240A0A').position({ x: 0, y: '50%' })
      // 中间分割线
      Divider().color('#000000').strokeWidth(2).position({ x: 0, y: '50%' })
      
      Text(char)
        .fontSize(38)
        .fontColor("#FFFFFF")
        .fontWeight(FontWeight.Bold)
    }
    .width(48)
    .height(64)
    .borderRadius(6)
    .clip(true)
    .border({ width: 1, color: '#3A1414' })
  }
  
  @Builder PerformanceBar(label: string, percentText: string, barColor: string, ratio: number) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor("#FFFFFF")
        .fontWeight(FontWeight.Medium)
        .width(80)
        
      Row() {
        Row()
          .height('100%')
          .width(`${ratio * 100}%`)
          .backgroundColor(barColor)
          .borderRadius(4)
      }
      .layoutWeight(1)
      .height(16)
      .backgroundColor("rgba(0,0,0,0.3)")
      .borderRadius(4)
      .margin({ left: 12, right: 12 })
      
      Text(percentText)
        .fontSize(14)
        .fontColor("rgba(255,255,255,0.6)")
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }
  
  @Builder BlacklistBar(label: string, percentText: string, ratio: number) {
    Column({ space: 8 }) {
      Row() {
        Text(label).fontSize(16).fontColor("#FFFFFF").fontWeight(FontWeight.Medium)
        Blank()
        Text(percentText).fontSize(14).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
      }.width('100%')
      
      Row() {
        Row()
          .height('100%')
          .width(`${ratio * 100}%`)
          .backgroundColor("#EF4444")
          .borderRadius(4)
      }
      .width('100%')
      .height(12)
      .backgroundColor("rgba(0,0,0,0.3)")
      .borderRadius(4)
    }.width('100%')
  }
}
