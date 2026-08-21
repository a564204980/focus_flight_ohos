import { webview } from '@kit.ArkWeb';

@Component
export struct FlightPassportFullReport {
  onClose?: () => void;
  @State earthAngle: number = 0;
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      // ʽɫͷ
      Column() {
        Row() {
          // Զ弸λƹرհť (ѭ UI Skill)
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(32).height(32)
              .backgroundColor("rgba(255,255,255,0.1)") // ɫµİ͸
              .borderRadius(16)
            
            Stack({ alignContent: Alignment.Center }) {
              Rect().width(14).height(2.5).radius(1).fill("#FFFFFF").rotate({ angle: 45 })
              Rect().width(14).height(2.5).radius(1).fill("#FFFFFF").rotate({ angle: -45 })
            }
          }
          .width(32).height(32)
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })
          
          Text('רעͳ')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            
          // ť
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(32).height(32)
              .backgroundColor("rgba(255,255,255,0.1)")
              .borderRadius(16)
            Image($r("sys.media.ohos_ic_public_share"))
              .width(16).height(16).fillColor("#FFFFFF")
          }
        }
        .width("100%")
        .padding({ left: 20, right: 20, top: 48, bottom: 16 })
        
        // ALL-TIME / 2026 Tabs
        Row({ space: 12 }) {
          Text("ܼ¼")
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor("#FFFFFF")
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor("rgba(255,255,255,0.15)")
            .borderRadius(16)

          Text("2026")
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor("rgba(255,255,255,0.5)")
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        }
        .width("100%")
        .padding({ left: 20, right: 20, bottom: 16 })
      }
      .width("100%")
      .backgroundColor("#110928") // ҹɫ

      //  (ɫ)
      Scroll() {
        Column() {
          // ----------------------------------------------------
          // տƬ (The Passport Map Card)
          // ----------------------------------------------------
          Column() {
            // ɻװ
            Row() {
              Text("                 ").fontSize(10).fontColor("rgba(255,255,255,0.2)").maxLines(1).textOverflow({ overflow: TextOverflow.Clip })
            }.width("100%").margin({ top: 16 })

            // 3D ͼ (ԭ WebGL Ƕ)
            Stack({ alignContent: Alignment.Center }) {
              Web({ src: $rawfile("earth.html"), controller: this.controller })
                .width("100%")
                .height(280)
                .backgroundColor(Color.Transparent) //  Web ͸Դ #030712 Ҳҹ
            }.width("100%").height(280).margin({ top: 10 })

            // 
            Row({ space: 4 }) {
              Text("").fontSize(18)
            }.width("100%").justifyContent(FlexAlign.Center).margin({ bottom: 20 })

            Divider().color("rgba(255,255,255,0.05)")

            // ձ
            Row() {
              Column({ space: 4 }) {
                Text("רл").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#FFFFFF").letterSpacing(1)
                Row({ space: 4 }) {
                  Text("").fontSize(10)
                  Text("ٷ֤  רע¼  Ȩ").fontSize(10).fontColor("rgba(255,255,255,0.5)").fontWeight(FontWeight.Medium)
                }
              })
            }
            .width("100%")
            .height(36)
            .backgroundColor("rgba(255, 255, 255, 0.04)") // ǳɫγ
            .borderRadius({ topLeft: 24, topRight: 24 })
            .clip(true)
            .justifyContent(FlexAlign.Start)

            // 3D ͼ (ԭ WebGL Ƕ)
            Stack({ alignContent: Alignment.Center }) {
              Web({ src: $rawfile("earth.html"), controller: this.controller })
                .width("100%")
                .height(280)
                .backgroundColor(Color.Transparent) //  Web ͸Դ #030712 Ҳҹ
                .width("100%")
                .height(280)
                .backgroundColor(Color.Transparent) //  Web ͸Դ #030712 Ҳҹ
            }.width("100%").height(280)

            // 
            Row({ space: 4 }) {
              Text("").fontSize(18)
            }.width("100%").justifyContent(FlexAlign.Center).margin({ bottom: 20 })

            Divider().color("rgba(255,255,255,0.05)")

            // ձ
            Row() {
              Column({ space: 4 }) {
                Text("רл").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#FFFFFF").letterSpacing(1)
                Row({ space: 4 }) {
                  Text("").fontSize(10)
                  Text("ٷ֤  רע¼  Ȩ").fontSize(10).fontColor("rgba(255,255,255,0.5)").fontWeight(FontWeight.Medium)
                }
              }.alignItems(HorizontalAlign.Start)
              
              Blank()
              

            }.width("100%").padding({ left: 24, right: 24, top: 24, bottom: 24 }).alignItems(VerticalAlign.Top)
            }.width("100%").padding({ left: 24, right: 24, top: 24, bottom: 24 }).alignItems(VerticalAlign.Top)

            // 
            Grid() {
              GridItem() { this.DarkGridItem("ִɺ ()", "27") }
              GridItem() { this.DarkGridItem("ۼ (km)", "128,714") }
              GridItem() { this.DarkGridItem("ܼƷʱ", "7d 1h") }
              GridItem() { this.DarkGridItem("̽Ŀĵ ()", "21") }
              GridItem() { this.DarkGridItem("˾ ()", "14") }
            }
            .columnsTemplate("1fr 1fr")
            .rowsGap(24)
            .columnsGap(16)
            .padding({ left: 24, right: 24 })
            
