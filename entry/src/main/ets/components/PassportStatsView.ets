
import { router } from '@kit.ArkUI';
import { FlightRecordRepository, FlightStatsSummary } from '../database/FlightRecordRepository';

interface TimeTabItem {
  id: string;
  label: string;
}

@Component
export struct PassportStatsView {
  onClose?: () => void;
  onOpenFullReport?: () => void;
  onOpenDistractionReport?: (year: string) => void;

  @StorageProp('isStatsSheetVisible') @Watch('onStatsSheetVisibleChanged') isStatsSheetVisible: boolean = false;
  @StorageProp('flightStatsUpdateTrigger') @Watch('onStatsTriggerChanged') statsTrigger: number = 0;
  @State stats: FlightStatsSummary = {
    totalFlights: 0,
    totalMinutes: 0,
    totalDistanceKm: 0,
    uniqueDestinationsCount: 0,
    currentStreakDays: 0,
    shortHaulCount: 0,
    longHaulCount: 0,
    abortedFlightsCount: 0,
    avgDistractedMin: 0
  };

  @State selectedTimeTab: string = 'all';
  @State availableYears: Array<number> = [2026, 2025];

  // 数字滚动动画插值状态
  @State animFlights: number = 0;
  @State animMinutes: number = 0;
  @State animDistance: number = 0;
  @State animDestinations: number = 0;
  @State animStreak: number = 0;
  @State animShortHaul: number = 0;
  @State animLongHaul: number = 0;
  private animTimer: number = -1;

  aboutToAppear(): void {
    FlightRecordRepository.seed2025MockDataIfEmpty().then(() => {
      this.loadDbStats(true);
    });
  }

  aboutToDisappear(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
  }

  private onStatsSheetVisibleChanged(): void {
    if (this.isStatsSheetVisible) {
      this.resetAnimStatesToZero();
      this.loadDbStats(true);
    }
  }

  private resetAnimStatesToZero(): void {
    this.animFlights = 0;
    this.animMinutes = 0;
    this.animDistance = 0;
    this.animDestinations = 0;
    this.animStreak = 0;
    this.animShortHaul = 0;
    this.animLongHaul = 0;
  }

  private onStatsTriggerChanged(): void {
    this.loadDbStats(false);
  }

  private async loadDbStats(fromZero: boolean = false): Promise<void> {
    try {
      await FlightRecordRepository.seed2025MockDataIfEmpty();
      const years = await FlightRecordRepository.getAvailableYears();
      this.availableYears = years;
      const yearFilter = this.selectedTimeTab === 'all' ? undefined : parseInt(this.selectedTimeTab);
      const summary = await FlightRecordRepository.getStatsSummary(yearFilter);
      if (summary) {
        this.stats = summary;
        this.startNumberRollingAnimation(summary, fromZero);
      }
    } catch (e) {
      // ignore
    }
  }

  /**
   * 丝滑数字滚动缓动动画 (Ease-Out Cubic)
   */
  private startNumberRollingAnimation(targetStats: FlightStatsSummary, fromZero: boolean = false): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }

    const startFlights = fromZero ? 0 : this.animFlights;
    const startMinutes = fromZero ? 0 : this.animMinutes;
    const startDistance = fromZero ? 0 : this.animDistance;
    const startDest = fromZero ? 0 : this.animDestinations;
    const startStreak = fromZero ? 0 : this.animStreak;
    const startShort = fromZero ? 0 : this.animShortHaul;
    const startLong = fromZero ? 0 : this.animLongHaul;

    const targetFlights = targetStats.totalFlights;
    const targetMinutes = targetStats.totalMinutes;
    const targetDistance = targetStats.totalDistanceKm;
    const targetDest = targetStats.uniqueDestinationsCount;
    const targetStreak = targetStats.currentStreakDays;
    const targetShort = targetStats.shortHaulCount;
    const targetLong = targetStats.longHaulCount;

    const duration = 500; // 500ms
    const fps = 60;
    const totalFrames = Math.round((duration / 1000) * fps);
    let frame = 0;

    this.animTimer = setInterval(() => {
      frame++;
      const progress = Math.min(1, frame / totalFrames);
      // EaseOutCubic: 1 - Math.pow(1 - progress, 3)
      const ease = 1 - Math.pow(1 - progress, 3);

      this.animFlights = Math.round(startFlights + (targetFlights - startFlights) * ease);
      this.animMinutes = Math.round(startMinutes + (targetMinutes - startMinutes) * ease);
      this.animDistance = Math.round(startDistance + (targetDistance - startDistance) * ease);
      this.animDestinations = Math.round(startDest + (targetDest - startDest) * ease);
      this.animStreak = Math.round(startStreak + (targetStreak - startStreak) * ease);
      this.animShortHaul = Math.round(startShort + (targetShort - startShort) * ease);
      this.animLongHaul = Math.round(startLong + (targetLong - startLong) * ease);

      if (progress >= 1) {
        clearInterval(this.animTimer);
        this.animTimer = -1;
      }
    }, Math.round(1000 / fps));
  }

  private getTabList(): Array<TimeTabItem> {
    const list: Array<TimeTabItem> = [{ id: 'all', label: '总记录' }];
    for (let i = 0; i < this.availableYears.length; i++) {
      list.push({ id: this.availableYears[i].toString(), label: `${this.availableYears[i]}年` });
    }
    return list;
  }

  private getSelectedTabIndex(): number {
    const list = this.getTabList();
    const idx = list.findIndex(t => t.id === this.selectedTimeTab);
    return idx >= 0 ? idx : 0;
  }

  private formatDuration(minutes: number): string {
    const days = Math.floor(minutes / (24 * 60));
    const hours = Math.floor((minutes % (24 * 60)) / 60);
    const mins = minutes % 60;
    if (days > 0) {
      return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
    }
    if (hours > 0) {
      return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
    }
    return `${minutes}m`;
  }

  private getMostUsedModeTitle(): string {
    if (this.stats.totalFlights === 0) {
      return "暂无执飞";
    }
    return this.stats.shortHaulCount >= this.stats.longHaulCount ? "短途番茄钟" : "深度长航";
  }

  private getMostUsedModeCountText(): string {
    if (this.stats.totalFlights === 0) {
      return "0 次完美执行";
    }
    const maxCount = Math.max(this.stats.shortHaulCount, this.stats.longHaulCount);
    return `${maxCount} 次完美执行`;
  }

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

        // 2. Tabs (All-Time / 2026 / 2025 / ...) - 动态多年度滑动高亮胶囊动效
        Stack({ alignContent: Alignment.Start }) {
          // 底槽背景
          Row()
            .width(this.getTabList().length * 68)
            .height(32)
            .backgroundColor("rgba(0, 0, 0, 0.05)")
            .borderRadius(16)

          // 平滑滑动的白色高亮胶囊
          Row()
            .width(68)
            .height(32)
            .backgroundColor("#FFFFFF")
            .borderRadius(16)
            .shadow({ radius: 4, color: "rgba(0,0,0,0.06)", offsetY: 1 })
            .offset({ x: this.getSelectedTabIndex() * 68 })
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })

          // 选项文字层
          Row() {
            ForEach(this.getTabList(), (tabItem: TimeTabItem) => {
              Text(tabItem.label)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.selectedTimeTab === tabItem.id ? "#000000" : "#94A3B8")
                .textAlign(TextAlign.Center)
                .width(68)
                .height(32)
                .onClick(() => {
                  if (this.selectedTimeTab !== tabItem.id) {
                    this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                      this.selectedTimeTab = tabItem.id;
                    });
                    this.loadDbStats();
                  }
                })
            }, (tabItem: TimeTabItem) => tabItem.id)
          }
          .width(this.getTabList().length * 68)
          .height(32)
        }
        .width("100%")

        // 3. Main Card (Dark Blue)
        Column() {
          // Card Header
          Row() {
            Column({ space: 2 }) {
              Text("我的专注飞行记录")
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
              Text(this.animFlights.toString()).fontSize(32).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).height(38)
              Text(`${this.animShortHaul} 次短途 / ${this.animLongHaul} 次长航`).fontSize(12).fontColor("rgba(255,255,255,0.7)")
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text("专注总时长").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text(this.formatDuration(this.animMinutes)).fontSize(26).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).height(38)
              Text(`约合 ${Math.round(this.animMinutes / 25)} 次标准番茄钟`).fontSize(12).fontColor("rgba(255,255,255,0.7)")
            }.alignItems(HorizontalAlign.Start).layoutWeight(1.5)
          }.width("100%").alignItems(VerticalAlign.Top).padding({ left: 20, right: 20, bottom: 20 })

          Row() {
            Column({ space: 4 }) {
              Text("折合小时").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text(`${(this.animMinutes / 60).toFixed(1)} 小时`).fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)

            Column({ space: 4 }) {
              Text("探索目的地").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text(this.animDestinations.toString()).fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            }.alignItems(HorizontalAlign.Start).layoutWeight(0.7)

            Column({ space: 4 }) {
              Text("连续专注(天)").fontSize(10).fontColor("rgba(255,255,255,0.6)").fontWeight(FontWeight.Bold)
              Text(this.animStreak.toString()).fontSize(20).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
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
            Text(this.stats.abortedFlightsCount.toString()).fontSize(56).fontColor("#FFFFFF").fontWeight(FontWeight.Bold).margin({ bottom: -8 })
            Text("次专注被中途打断").fontSize(18).fontColor("#FFFFFF").fontWeight(FontWeight.Bold)
            Text(this.stats.abortedFlightsCount > 0 ? `通常在开始后的第 ${this.stats.avgDistractedMin} 分钟最容易分心` : "保持良好心流，暂无打断记录").fontSize(14).fontColor("rgba(255,255,255,0.7)").margin({ top: 4 })
          }.alignItems(HorizontalAlign.Start).width("100%").padding(20)

          Divider().color("rgba(255,255,255,0.1)").margin({ left: 20, right: 20 })

          Row() {
            Text("查看完整分心记录").fontSize(14).fontColor("#FFFFFF").fontWeight(FontWeight.Medium)
            Blank()
            Image($r("sys.media.ohos_ic_public_arrow_right")).width(16).height(16).fillColor("#FFFFFF")
          }.width("100%").padding(20)
          .onClick(() => {
            if (this.onOpenDistractionReport) {
              this.onOpenDistractionReport(this.selectedTimeTab);
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
              Text(this.getMostUsedModeTitle()).fontSize(32).fontColor("#1E3A8A").fontWeight(FontWeight.Bold)
              Text(this.getMostUsedModeCountText()).fontSize(14).fontColor("#3B82F6").fontWeight(FontWeight.Medium)
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

