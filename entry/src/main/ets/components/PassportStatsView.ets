
import { router } from '@kit.ArkUI';

@Component
export struct PassportStatsView {
  onClose?: () => void;
  onOpenFullReport?: () => void;

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
              Text("专属专注护照")
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor("rgba(255,255,255,0.9)")
                .letterSpacing(0.5)
              Text("✈ 记录您的每一次心流旅程")
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
              Text("执飞航班").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("27").fontSize(32).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
              Text("11 次越洋长途").fontSize(12).fontColor("rgba(255,255,255,0.7)")
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text("飞行里程").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("128,714 km").fontSize(28).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
              Text("相当于绕地球 3.2 圈").fontSize(12).fontColor("rgba(255,255,255,0.7)")
            }.alignItems(HorizontalAlign.Start).layoutWeight(1.5)
          }.width("100%").padding({ left: 20, right: 20, bottom: 20 })

          Row() {
            Column({ space: 4 }) {
              Text("飞行时长").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("7天 1小时").fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text("经停机场").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("21").fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(0.7)

            Column({ space: 4 }) {
              Text("专注标签").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text("14").fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(0.8)
          }.width("100%").padding({ left: 20, right: 20, bottom: 20 })

          Divider().color("rgba(255,255,255,0.1)").margin({ left: 20, right: 20 })

          // Bottom Action
          Row() {
            Text("查看完整飞行统计").fontSize(14).fontColor("#FFFFFF").fontWeight(FontWeight.Medium)
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
            Text("分钟因分心而损失").fontSize(18).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            Text("中途返航的平均耗时为 3 分钟").fontSize(14).fontColor("rgba(255,255,255,0.7)").margin({ top: 4 })
          }.alignItems(HorizontalAlign.Start).width("100%").padding(20)

          Divider().color("rgba(255,255,255,0.1)").margin({ left: 20, right: 20 })

          Row() {
            Text("查看完整延误统计").fontSize(14).fontColor("#FFFFFF").fontWeight(FontWeight.Medium)
            Blank()
            Image($r("sys.media.ohos_ic_public_arrow_right")).width(16).height(16).fillColor("#FFFFFF")
          }.width("100%").padding(20)
        }
        .width("100%")
        .borderRadius(24)
        .linearGradient({ angle: 135, colors: [ ["#6B1C1C", 0], ["#421212", 1] ] })
        .shadow({ radius: 16, color: "rgba(107, 28, 28, 0.2)", offsetY: 8 })

        // 5. Most Flown Aircraft Card (Light Blue)
        Column() {
          Row() {
            Column({ space: 4 }) {
              Text("最常执飞座驾").fontSize(16).fontColor("#475569").fontWeight(FontWeight.Medium)
              Text("B737-800").fontSize(32).fontColor("#1E3A8A").fontWeight(FontWeight.Bold)
              Text("5 次执飞").fontSize(14).fontColor("#3B82F6").fontWeight(FontWeight.Medium)
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Image($r("sys.media.ohos_ic_public_share"))
              .width(16).height(16).fillColor("#3B82F6")
          }.width("100%").padding(20)

          Image($r("app.media.b737_shell_left")) // Using a plane asset we have
            .width("90%")
            .objectFit(ImageFit.Contain)
            .margin({ top: -20, bottom: 10 })
            .opacity(0.9)

          Divider().color("rgba(0,0,0,0.05)").margin({ left: 20, right: 20 })

          Row() {
            Text("查看完整机队统计").fontSize(14).fontColor("#1E3A8A").fontWeight(FontWeight.Medium)
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

