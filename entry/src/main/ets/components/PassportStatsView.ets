
import { router } from '@kit.ArkUI';

@Component
export struct PassportStatsView {
  onClose?: () => void;
  onOpenFullReport?: () => void;
  onOpenDistractionReport?: () => void;

  build() {
    Scroll() {
      Column({ space: 24 }) {
        // 1. Header: Passport + Icons
        Row() {
          Text("飞行护照")
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor("#000000")
          
          Blank()

          // Custom Close Button
          Stack({ alignContent: Alignment.Center }) {
            // 背景与阴影
            Row()
              .width(32)
              .height(32)
              .backgroundColor("#FFFFFF")
              .borderRadius(16)
              .shadow({ radius: 6, color: "rgba(0,0,0,0.08)", offsetY: 2 })

            // 完美居中且加粗的自定义“X”号
            Stack({ alignContent: Alignment.Center }) {
              Rect().width(14).height(2.5).radius(1).fill("#000000").rotate({ angle: 45 })
              Rect().width(14).height(2.5).radius(1).fill("#000000").rotate({ angle: -45 })
            }
          }
          .width(32)
          .height(32)
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })
        }
        .width("100%")
        .padding({ top: 12 })

        // 2. Tabs (All-Time / 2026)
        Row({ space: 12 }) {
          Text("总记录")
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor("#000000")
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor("#FFFFFF")
            .borderRadius(16)
            .shadow({ radius: 4, color: "rgba(0,0,0,0.03)", offsetY: 1 })

          Text("2026年")
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor("#94A3B8")
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        }
        .width("100%")

        // 3. Main Card (Dark Blue)
        Column() {
          // Card Header
          Row() {
            Column({ space: 2 }) {
              Text("我的专注航行记录")
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor("rgba(255,255,255,0.9)")
                .letterSpacing(0.5)
              Text("Focus Flight · 终身专注里程碑")
                .fontSize(9)
                .fontColor("rgba(255,255,255,0.5)")
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Image($r("sys.media.ohos_ic_public_share"))
              .width(16).height(16).fillColor("#FFFFFF")
          }.width("100%").padding(20)

          // Grid Data
          Row() {
            Column({ space: 4 }) {
              Text("完成专注 (次)").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("27").fontSize(32).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).height(38)
              Text("16 次短途 / 11 次长航").fontSize(12).fontColor("rgba(255,255,255,0.7)")
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text("专注总时长").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("8,580 分钟").fontSize(28).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).height(38)
              Text("约合 343 次标准番茄钟").fontSize(12).fontColor("rgba(255,255,255,0.7)")
            }.alignItems(HorizontalAlign.Start).layoutWeight(1.5)
          }.width("100%").alignItems(VerticalAlign.Top).padding({ left: 20, right: 20, bottom: 20 })

          Row() {
            Column({ space: 4 }) {
              Text("折合小时").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("143 小时").fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text("探索目的地").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("21").fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(0.7)

            Column({ space: 4 }) {
              Text("连续专注(天)").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("14").fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(0.8)
          }.width("100%").alignItems(VerticalAlign.Top).padding({ left: 20, right: 20, bottom: 20 })

          Divider().color("rgba(255,255,255,0.1)").margin({ left: 20, right: 20 })

          // Bottom Action
          Row() {
            Text("查看完整专注飞行统计").fontSize(14).fontColor("#FFFFFF").fontWeight(FontWeight.Medium)
            Blank()
            Image($r("sys.media.ohos_ic_public_arrow_right")).width(16).height(16).fillColor("#FFFFFF")
          }
          .width("100%")
          .padding(20)
          .onClick(() => {
            if (this.onOpenFullReport) {
              this.onOpenFullReport();
            }
          })
        }
        .width("100%")
        .borderRadius(24)
        .linearGradient({ angle: 135, colors: [ ["#0A0F24", 0], ["#1B2245", 1] ] })
        .shadow({ radius: 20, color: "rgba(10, 15, 36, 0.3)", offsetY: 10 })

        // 4. Distractions Card (Red)
        Column() {
          Column() {
            Text("15").fontSize(56).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).margin({ bottom: -8 })
            Text("次专注被中途打断").fontSize(18).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            Text("通常在开始后的第 3 分钟最容易分心").fontSize(14).fontColor("rgba(255,255,255,0.7)").margin({ top: 4 })
          }.alignItems(HorizontalAlign.Start).width("100%").padding(20)

          Divider().color("rgba(255,255,255,0.1)").margin({ left: 20, right: 20 })

          Row() {
            Text("查看完整分心记录").fontSize(14).fontColor("#FFFFFF").fontWeight(FontWeight.Medium)
            Blank()
            Image($r("sys.media.ohos_ic_public_arrow_right")).width(16).height(16).fillColor("#FFFFFF")
          }.width("100%").padding(20)
          .onClick(() => {
            if (this.onOpenDistractionReport) {
              this.onOpenDistractionReport();
            }
          })
        }
        .width("100%")
        .borderRadius(24)
        .linearGradient({ angle: 135, colors: [ ["#6B1C1C", 0], ["#421212", 1] ] })
        .shadow({ radius: 16, color: "rgba(107, 28, 28, 0.2)", offsetY: 8 })

        // 5. Most Flown Mode Card (Light Blue)
        Column() {
          Row() {
            Column({ space: 4 }) {
              Text("最常使用的专注模式").fontSize(16).fontColor("#475569").fontWeight(FontWeight.Medium)
              Text("深度长航").fontSize(32).fontColor("#1E3A8A").fontWeight(FontWeight.Bold)
              Text("5 次完美执行").fontSize(14).fontColor("#3B82F6").fontWeight(FontWeight.Medium)
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Image($r("sys.media.ohos_ic_public_share"))
              .width(16).height(16).fillColor("#3B82F6")
          }.width("100%").padding(20)

          Image($r("app.media.b737_shell_left")) // We can still show the plane as the metaphor for "深度长航"
            .width("90%")
            .objectFit(ImageFit.Contain)
            .margin({ top: -20, bottom: 10 })
            .opacity(0.9)

          Divider().color("rgba(0,0,0,0.05)").margin({ left: 20, right: 20 })

          Row() {
            Text("查看完整模式统计").fontSize(14).fontColor("#1E3A8A").fontWeight(FontWeight.Medium)
            Blank()
            Image($r("sys.media.ohos_ic_public_arrow_right")).width(16).height(16).fillColor("#1E3A8A")
          }.width("100%").padding(20)
        }
        .width("100%")
        .borderRadius(24)
        .linearGradient({ angle: 135, colors: [ ["#E0F2FE", 0], ["#BAE6FD", 1] ] })
        .shadow({ radius: 16, color: "rgba(186, 230, 253, 0.4)", offsetY: 8 })

        // Bottom space for scrolling
        Row().height(40)
      }
      .width("100%")
      .padding({ left: 20, right: 20, top: 10 })
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#fff7f4")
    .scrollBar(BarState.Off)
  }
}

