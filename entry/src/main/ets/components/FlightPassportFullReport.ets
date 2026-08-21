import { webview } from '@kit.ArkWeb';

@Observed
export class ChartItem {
  label: string;
  value: number;
  constructor(label: string, value: number) {
    this.label = label;
    this.value = value;
  }
}

@Component
export struct FlightPassportFullReport {
  onClose?: () => void;
  @State earthAngle: number = 0;
  @State currentChartMode: string = 'week';
  @State chartData: Array<ChartItem> = [
    new ChartItem("周日", 3),
    new ChartItem("周一", 7),
    new ChartItem("周二", 2),
    new ChartItem("周三", 4),
    new ChartItem("周四", 3),
    new ChartItem("周五", 4),
    new ChartItem("周六", 4)
  ];
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      // 沉浸式深紫色头部导航
      Column() {
        Row() {
          // 自定义几何绘制关闭按钮 (遵循 UI Skill)
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(32).height(32)
              .backgroundColor("rgba(255,255,255,0.1)") // 暗色背景下的半透明底盘
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
          
          Text('专注飞行统计')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            
          // 分享按钮
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
          Text("总记录")
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor("#FFFFFF")
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor("rgba(255,255,255,0.15)")
            .borderRadius(16)

          Text("2026年")
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor("rgba(255,255,255,0.5)")
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        }
        .width("100%")
        .padding({ left: 20, right: 20, bottom: 16 })
      }
      .width("100%")
      .backgroundColor("#110928") // 深紫夜空色

      // 白色滚动内容区
      Scroll() {
        Column() {
          // ----------------------------------------------------
          // 顶级护照卡片 (The Passport Map Card)
          // ----------------------------------------------------
          Column() {
            // 顶部飞机装饰带
            Row({ space: 16 }) {
              ForEach([
                'plane', 'plane', 'plane', 'plane', 'plane', 
                'dot', 'CTU', 'dot', 
                'plane', 'plane', 'plane', 'plane', 'plane'
              ], (item: string, index: number) => {
                // 简单的颜色渐变映射
                Row() {
                  if (item === 'plane') {
                    Image($r("app.media.ic_nav_flight"))
                      .width(14)
                      .height(14)
                      .fillColor(this.getGradientColor(index, 13))
                      .rotate({ angle: 90 })
                  } else if (item === 'dot') {
                    Circle()
                      .width(4)
                      .height(4)
                      .fill(this.getGradientColor(index, 13))
                  } else {
                    Text(item)
                      .fontSize(14)
                      .fontColor(this.getGradientColor(index, 13))
                      .fontWeight(FontWeight.Bold)
                      .letterSpacing(2)
                  }
                }
              }, (item: string, index: number) => index.toString())
            }
            .width("100%")
            .margin({ top: 6, bottom: 6 })
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .zIndex(1)

            // 3D 地图 (原生 WebGL 嵌入)
            Stack({ alignContent: Alignment.Center }) {
              Web({ src: $rawfile("earth.html"), controller: this.controller })
                .width("100%")
                .height(280)
                .backgroundColor(Color.Transparent)
            }.width("100%").height(280)

            // 国旗排
            Row({ space: 4 }) {
              Text("🇺🇸🇿🇦🇦🇺🇯🇵🇰🇷🇨🇳🇦🇪🇳🇿🇨🇦🇧🇷🇬🇧🇫🇷🇳🇴🇭🇰").fontSize(18)
            }.width("100%").justifyContent(FlexAlign.Center).margin({ bottom: 20 })

            Divider().color("rgba(255,255,255,0.05)")

            // 护照标题区
            Row() {
              Column({ space: 4 }) {
                Text("个人专属飞行护照").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#FFFFFF").letterSpacing(1)
                Row({ space: 4 }) {
                  Text("🛂").fontSize(10) // Small icon
                  Text("官方认证 · 终身专注记录 · 授权机长").fontSize(10).fontColor("rgba(255,255,255,0.5)").fontWeight(FontWeight.Medium)
                }
              }.alignItems(HorizontalAlign.Start)
              
              Blank()
              
              // Flight Icon Button
              Stack({ alignContent: Alignment.Center }) {
                 Row().width(32).height(32).borderRadius(6).linearGradient({ angle: 135, colors: [["#A78BFA", 0], ["#60A5FA", 0.5], ["#FBCFE8", 1]] })
                 Image($r("app.media.ic_nav_flight")).width(16).height(16).fillColor("#FFFFFF").rotate({ angle: 90 })
              }
            }.width("100%").padding({ left: 24, right: 24, top: 24, bottom: 24 }).alignItems(VerticalAlign.Top)

            // 数据网格
            Grid() {
              GridItem() { this.DarkGridItem("执飞航班 (次)", "27") }
              GridItem() { this.DarkGridItem("累计里程 (km)", "128,714") }
              GridItem() { this.DarkGridItem("总计飞行时长", "7d 1h") }
              GridItem() { this.DarkGridItem("探索目的地 (个)", "21") }
              GridItem() { this.DarkGridItem("合作航司 (家)", "14") }
            }
            .columnsTemplate("1fr 1fr")
            .rowsGap(24)
            .columnsGap(16)
            .padding({ left: 24, right: 24 })

            // 底部机读码 (MRZ Code) - 保持大写英文字母符合护照真实感，加入 FOCUS 拼音
            Text("P<CHN<<FOCUS<<ZHANG<<<<<<<<<<<<<<<<<<<<<<<<<<\nALLTIME<<ZHUANZHU<HANGXIAN<<MEMBER2026<<<<<<<")
              .fontSize(10)
              .fontFamily("Courier") // 模拟等宽机读字体
              .fontColor("rgba(255,255,255,0.4)")
              .lineHeight(14)
              .letterSpacing(1)
              .margin({ top: 40, bottom: 40, left: 20, right: 20 })
          }
          .width("100%")
          .backgroundColor("rgba(30, 16, 69, 0.85)") // 保持护照卡的底色，增加微弱透明度
          .borderRadius({ topLeft: 24, topRight: 24 })
          .clip(true)
          .margin({ top: 10 })

          // ----------------------------------------------------
          // 下方的主数据卡片区 (白色底背)
          // ----------------------------------------------------
          Column() {
            // 1. Flights 总览
            Row() {
              Column({ space: 4 }) {
                Text("完成专注次数").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000")
                Text("27").fontSize(48).fontWeight(FontWeight.Bold).fontColor("#000000")
                Text("16 次短途番茄钟 / 11 次深空长航").fontSize(14).fontColor("#94A3B8").margin({ top: 4 })
              }.alignItems(HorizontalAlign.Start)
              
              Blank()
              
              // Share Button (Small)
              Row() {
                Image($r("sys.media.ohos_ic_public_share")).width(14).height(14).fillColor("#000000")
                Text("分享").fontSize(12).fontWeight(FontWeight.Medium).fontColor("#000000").margin({ left: 4 })
              }.padding({ left: 12, right: 12, top: 6, bottom: 6 }).border({ width: 1, color: "#E2E8F0" }).borderRadius(16)
            }.width("100%").padding({ left: 20, right: 20, top: 20, bottom: 20 }).alignItems(VerticalAlign.Top)

            Divider().color("#F1F5F9").margin({ left: 20, right: 20, bottom: 20 })

            // 2. 柱状图统计 (Focus Time Trend)
            Column() {
              Row() {
                Text("专注趋势").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000").layoutWeight(1)
                
                Row() {
                  // 按月份 Tab
                  Text("按月份")
                    .fontSize(12)
                    .fontColor(this.currentChartMode === 'month' ? "#000000" : "#94A3B8")
                    .backgroundColor(this.currentChartMode === 'month' ? "#F1F5F9" : "transparent")
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(12)
                    .margin({ left: 16 })
                    .onClick(() => {
                      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
                        this.currentChartMode = 'month';
                        let monthData: Array<ChartItem> = [
                          new ChartItem("1月", 5), new ChartItem("2月", 3), new ChartItem("3月", 8),
                          new ChartItem("4月", 6), new ChartItem("5月", 7), new ChartItem("6月", 5),
                          new ChartItem("7月", 8), new ChartItem("8月", 4), new ChartItem("9月", 6),
                          new ChartItem("10月", 2), new ChartItem("11月", 5), new ChartItem("12月", 7)
                        ];
                        for (let i = 0; i < 7; i++) {
                          this.chartData[i].label = monthData[i].label;
                          this.chartData[i].value = monthData[i].value;
                        }
                        for (let i = 7; i < 12; i++) {
                          this.chartData.push(new ChartItem(monthData[i].label, monthData[i].value));
                        }
                      });
                    })

                  // 按星期 Tab
                  Text("按星期")
                    .fontSize(12)
                    .fontColor(this.currentChartMode === 'week' ? "#000000" : "#94A3B8")
                    .backgroundColor(this.currentChartMode === 'week' ? "#F1F5F9" : "transparent")
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(12)
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
                        this.currentChartMode = 'week';
                        let weekData: Array<ChartItem> = [
                          new ChartItem("周日", 3), new ChartItem("周一", 7), new ChartItem("周二", 2),
                          new ChartItem("周三", 4), new ChartItem("周四", 3), new ChartItem("周五", 4),
                          new ChartItem("周六", 4)
                        ];
                        for (let i = 0; i < 7; i++) {
                          this.chartData[i].label = weekData[i].label;
                          this.chartData[i].value = weekData[i].value;
                        }
                        if (this.chartData.length > 7) {
                          this.chartData.splice(7, this.chartData.length - 7);
                        }
                      });
                    })
                }.padding({ left: 20, bottom: 16 })
              }.width("100%")

              Scroll() {
                Row() {
                  ForEach(this.chartData, (item: ChartItem, index: number) => {
                    DayBarComponent({ item: item })
                      .transition({ type: TransitionType.Insert, translate: { x: 40 }, opacity: 0 })
                      .transition({ type: TransitionType.Delete, translate: { x: 40 }, opacity: 0 })
                  }, (item: ChartItem, index: number) => index.toString())
                }
                .width(this.currentChartMode === 'week' ? "100%" : "140%")
                .justifyContent(FlexAlign.SpaceEvenly)
                .padding({ left: 10, right: 10, bottom: 20 })
                .animation({ duration: 400, curve: Curve.EaseInOut })
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width("100%")
              .height(140)
            }.width("100%")

            Divider().color("#F1F5F9").margin({ left: 20, right: 20, bottom: 20 })

            // 3. Flight Distance 里程
            Column({ space: 4 }) {
              Text("飞行里程").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000")
              Row() {
                Text("128,714").fontSize(48).fontWeight(FontWeight.Bold).fontColor("#000000")
                Text("km").fontSize(24).fontWeight(FontWeight.Medium).fontColor("#94A3B8").margin({ left: 4, bottom: 6 })
              }.alignItems(VerticalAlign.Bottom)
              Text("相当于 8,580 分钟的心流时间\n约合 343 次标准番茄钟").fontSize(14).fontColor("#94A3B8").margin({ top: 4 })
            }.width("100%").alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, bottom: 16 })

            // 里程碑进度条 (绕地球)
            Stack({ alignContent: Alignment.Start }) {
              Row().width("100%").height(32).backgroundColor("#F1F5F9").borderRadius(16)
              Row() {
                Text("🌍").fontSize(20).margin({ left: 6 })
                Blank()
                Text("3.2x 绕地球一圈").fontSize(12).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).margin({ right: 12 })
              }
              .width("90%")
              .height(32)
              .linearGradient({ angle: 90, colors: [["#6366F1", 0], ["#4F46E5", 1]] })
              .borderRadius(16)
            }.width("100%").padding({ left: 20, right: 20, bottom: 12 })

            Stack({ alignContent: Alignment.Start }) {
              Row().width("100%").height(32).backgroundColor("#F1F5F9").borderRadius(16)
              Row() {
                Text("🌕").fontSize(20).margin({ left: 6 })
                Blank()
                Text("0.3x 登月进度").fontSize(12).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).margin({ right: 12 })
              }
              .width("30%")
              .height(32)
              .linearGradient({ angle: 90, colors: [["#8B5CF6", 0], ["#7C3AED", 1]] })
              .borderRadius(16)
            }.width("100%").padding({ left: 20, right: 20, bottom: 30 })

            Divider().color("#F1F5F9").margin({ left: 20, right: 20, bottom: 20 })

            // 4. Flight Time 时长
            Column({ space: 4 }) {
              Text("专注总时长").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000")
              Text("169h 25m").fontSize(40).fontWeight(FontWeight.Bold).fontColor("#000000")
            }.width("100%").alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, bottom: 16 })
            
            // 四宫格换算
            Row() {
              this.TimeGridItem("累计天数", "7.1")
              this.TimeGridItem("折合周数", "1.0")
            }.width("100%").padding({ left: 20, right: 20, bottom: 16 })
            Row() {
              this.TimeGridItem("折合月数", "0.2")
              this.TimeGridItem("折合年数", "0.02")
            }.width("100%").padding({ left: 20, right: 20, bottom: 30 })

            // 5. 排行榜 (Top Visited Airports) -> 最常专注任务
            Column({ space: 16 }) {
              Text("最常执行任务 (Top Tags)").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000")
              Text("21 个总标签").fontSize(24).fontColor("#94A3B8").margin({ top: -8 })
              
              this.HorizontalBarItem("SFO 核心代码", 12, "100%")
              this.HorizontalBarItem("DFW 读书笔记", 4, "40%")
              this.HorizontalBarItem("LAX 外语背词", 3, "30%")
              this.HorizontalBarItem("AKL 冥想放松", 2, "20%")
            }.width("100%").alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, bottom: 60 })

          } // Closes bottom white Column
          .width("100%")
          .backgroundColor("#FFFFFF")
          .borderRadius({ topLeft: 24, topRight: 24 })
          .margin({ top: -24 }) // 盖住地图的底部
        } // Closes Scroll's Column
        .width("100%")
      } // Closes Scroll
      .width("100%")
      .layoutWeight(1)

    } // Closes build()'s outer Column
    .width("100%")
    .height("100%")
    .backgroundColor("#110928")
  } // Closes build()

  getGradientColor(index: number, total: number): string {
    // 模拟渐变色：橙红 #F6C492 -> 紫色 #C074E1 -> 青蓝 #81E8E6
    const t = index / Math.max(1, total - 1);
    // 简单地把 t 分成两段
    if (t < 0.5) {
      // 橙色到紫色
      const t2 = t * 2;
      const r = Math.round(0xF6 + (0xC0 - 0xF6) * t2);
      const g = Math.round(0xC4 + (0x74 - 0xC4) * t2);
      const b = Math.round(0x92 + (0xE1 - 0x92) * t2);
      return `rgb(${r},${g},${b})`;
    } else {
      // 紫色到青色
      const t2 = (t - 0.5) * 2;
      const r = Math.round(0xC0 + (0x81 - 0xC0) * t2);
      const g = Math.round(0x74 + (0xE8 - 0x74) * t2);
      const b = Math.round(0xE1 + (0xE6 - 0xE1) * t2);
      return `rgb(${r},${g},${b})`;
    }
  }

  @Builder
  TimeGridItem(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label).fontSize(12).fontColor("#94A3B8")
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor("#000000")
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }

  @Builder
  HorizontalBarItem(label: string, count: number, percentWidth: string) {
    Row({ space: 12 }) {
      Text(label).fontSize(14).fontWeight(FontWeight.Bold).fontColor("#000000").width(90)
      Row()
        .height(16)
        .width(percentWidth)
        .backgroundColor("#8B5CF6")
        .borderRadius(8)
        .layoutWeight(1)
      Text(count.toString()).fontSize(14).fontColor("#94A3B8").width(24).textAlign(TextAlign.End)
    }.width("100%")
  }

  @Builder
  DarkGridItem(label: string, value: string, unit?: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(10).fontColor("rgba(255,255,255,0.5)").letterSpacing(1)
      Row() {
        Text(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor("#FFFFFF")
        if (unit) {
          Text(unit).fontSize(16).fontColor("rgba(255,255,255,0.5)").margin({ left: 4, bottom: 4 })
        }
      }.alignItems(VerticalAlign.Bottom)
    }.alignItems(HorizontalAlign.Start).width("100%")
  }
}

@Component
export struct DayBarComponent {
  @ObjectLink item: ChartItem;

  build() {
    Column({ space: 8 }) {
      // Bar
      Stack({ alignContent: Alignment.Bottom }) {
        Row().width(24).height(100).backgroundColor("transparent")
        Row().width(24).height(this.item.value * 12).backgroundColor("#6366F1").borderRadius(4)
          .animation({ duration: 400, curve: Curve.EaseInOut }) // animate height
      }
      Text(this.item.label).fontSize(12).fontColor("#94A3B8").fontWeight(FontWeight.Medium)
    }
  }
}
