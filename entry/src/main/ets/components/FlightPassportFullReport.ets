import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { CloseButton } from './CloseButton';
import { LocationService } from '../services/LocationService';
import { Airport } from '../models/AirportModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  FlightRecordRepository,
  FlightStatsSummary,
  TopTagItem,
  TrendChartItem
} from '../database/FlightRecordRepository';

export interface TimeTabItem {
  id: string;
  label: string;
}

@Observed
export class ChartItem {
  @Track label: string;
  @Track value: number;
  constructor(label: string, value: number) {
    this.label = label;
    this.value = value;
  }
}

@Observed
export class TagChartItem {
  @Track tag: string;
  @Track count: number;
  @Track displayCount: number;
  @Track ratioPercent: number;
  constructor(tag: string, count: number, ratioPercent: number = 15, displayCount: number = 0) {
    this.tag = tag;
    this.count = count;
    this.displayCount = displayCount > 0 ? displayCount : count;
    this.ratioPercent = ratioPercent;
  }
}

@Component
export struct FlightPassportFullReport {
  onClose?: () => void;
  @Prop @Watch('onVisibleChanged') isVisible: boolean = false;
  @State earthAngle: number = 0;
  @State currentChartMode: string = 'week';
  @StorageProp('nearestAirport') nearestAirport: Airport | undefined = undefined;
  @StorageProp('flightStatsUpdateTrigger') @Watch('onStatsTriggerChanged') statsTrigger: number = 0;
  @State isLocating: boolean = false;
  @State selectedTimeTab: string = 'all';
  @State availableYears: Array<number> = [2026, 2025];
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
  @State allTimeStats: FlightStatsSummary = {
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

  // 数字滚动动画插值状态
  @State animFlights: number = 0;
  @State animMinutes: number = 0;
  @State animDistance: number = 0;
  @State animDestinations: number = 0;
  @State animStreak: number = 0;
  @State animShortHaul: number = 0;
  @State animLongHaul: number = 0;
  @State animTotalTags: number = 0;
  @State animTagProgress: number = 0;
  private animTimer: number = -1;

  @State chartData: Array<ChartItem> = [
    new ChartItem("周日", 0),
    new ChartItem("周一", 0),
    new ChartItem("周二", 0),
    new ChartItem("周三", 0),
    new ChartItem("周四", 0),
    new ChartItem("周五", 0),
    new ChartItem("周六", 0)
  ];
  @State topTags: Array<TagChartItem> = [];
  @State barGrowthProgress: number = 0;
  controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const cached = AppStorage.get<Airport>('nearestAirport');
    if (cached) {
      this.nearestAirport = cached;
    }
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

  private onVisibleChanged(): void {
    if (this.isVisible) {
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
    this.animTotalTags = 0;
    this.animTagProgress = 0;
    this.barGrowthProgress = 0;
  }

  private onStatsTriggerChanged(): void {
    this.loadDbStats(false);
  }

  private async loadDbStats(fromZero: boolean = false): Promise<void> {
    try {
      const years = await FlightRecordRepository.getAvailableYears();
      this.availableYears = years;
      const yearFilter = this.selectedTimeTab === 'all' ? undefined : parseInt(this.selectedTimeTab);
      const summary = await FlightRecordRepository.getStatsSummary(yearFilter);
      const allTimeSummary = await FlightRecordRepository.getStatsSummary(undefined);
      if (allTimeSummary) {
        this.allTimeStats = allTimeSummary;
      }
      await this.loadTopTags();
      if (summary) {
        this.stats = summary;
        this.startNumberRollingAnimation(summary, fromZero);
      }
      await this.loadTrendChartData();
      await this.syncHistoricalRoutesToEarth();
    } catch (e) {
      hilog.error(0x0000, 'FlightPassportFullReport', 'Failed to load stats: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 同步数据库历史航线网络至 3D 互动地球 (以用户定位点为正中心直接对齐)
   */
  private async syncHistoricalRoutesToEarth(): Promise<void> {
    try {
      const yearFilter = this.selectedTimeTab === 'all' ? undefined : parseInt(this.selectedTimeTab);
      const routes = await FlightRecordRepository.getHistoricalRouteSegments(yearFilter);
      const userLoc: Record<string, string | number> = this.nearestAirport ? {
        'lat': this.nearestAirport.lat,
        'lon': this.nearestAirport.lon,
        'code': this.nearestAirport.code,
        'city': this.nearestAirport.city
      } : { 'lat': 34, 'lon': 104, 'code': 'CTU', 'city': '成都' };

      const jsCode = `if (window.renderAllHistoricalRoutes) { window.renderAllHistoricalRoutes(${JSON.stringify(routes)}, ${JSON.stringify(userLoc)}); }`;
      this.controller.runJavaScript(jsCode);
    } catch (e) {
      hilog.error(0x0000, 'FlightPassportFullReport', 'Failed to sync routes to earth: %{public}s', JSON.stringify(e));
    }
  }

  private async loadTrendChartData(): Promise<void> {
    try {
      const yearFilter = this.selectedTimeTab === 'all' ? undefined : parseInt(this.selectedTimeTab);
      const items = await FlightRecordRepository.getTrendChartData(this.currentChartMode as 'week' | 'month', yearFilter);
      if (items && items.length > 0) {
        this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseInOut }, () => {
          const minLen = Math.min(this.chartData.length, items.length);
          for (let i = 0; i < minLen; i++) {
            this.chartData[i].label = items[i].label;
            this.chartData[i].value = items[i].value;
          }
          if (items.length > this.chartData.length) {
            // 从星期(7)切到月份(12): 从右侧推入新的月份柱子 (8月~12月)
            for (let i = this.chartData.length; i < items.length; i++) {
              this.chartData.push(new ChartItem(items[i].label, items[i].value));
            }
          } else if (this.chartData.length > items.length) {
            // 从月份(12)切到星期(7): 把多出的柱子向右推出去
            this.chartData.splice(items.length, this.chartData.length - items.length);
          }
        });
      }
    } catch (e) {
      hilog.error(0x0000, 'FlightPassportFullReport', 'Failed to load trend chart: %{public}s', JSON.stringify(e));
    }
  }

  private async loadTopTags(): Promise<void> {
    try {
      const yearFilter = this.selectedTimeTab === 'all' ? undefined : parseInt(this.selectedTimeTab);
      const tags = await FlightRecordRepository.getTopTaskTags(yearFilter);
      if (tags && tags.length > 0) {
        this.getUIContext().animateTo({ duration: 400, curve: Curve.FastOutSlowIn }, () => {
          const minLen = Math.min(this.topTags.length, tags.length);
          for (let i = 0; i < minLen; i++) {
            this.topTags[i].tag = tags[i].tag;
            this.topTags[i].count = tags[i].count;
            this.topTags[i].ratioPercent = tags[i].ratioPercent;
          }
          if (tags.length > this.topTags.length) {
            for (let i = this.topTags.length; i < tags.length; i++) {
              this.topTags.push(new TagChartItem(tags[i].tag, tags[i].count, tags[i].ratioPercent));
            }
          } else if (this.topTags.length > tags.length) {
            this.topTags.splice(tags.length, this.topTags.length - tags.length);
          }
        });
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
    const startTags = fromZero ? 0 : this.animTotalTags;
    const targetTags = this.topTags.length;
    const startTagCounts: Array<number> = this.topTags.map((t: TagChartItem) => fromZero ? 0 : t.displayCount);

    const targetFlights = targetStats.totalFlights;
    const targetMinutes = targetStats.totalMinutes;
    const targetDistance = targetStats.totalDistanceKm;
    const targetDest = targetStats.uniqueDestinationsCount;
    const targetStreak = targetStats.currentStreakDays;
    const targetShort = targetStats.shortHaulCount;
    const targetLong = targetStats.longHaulCount;

    const duration = 350; // 350ms 顺滑过渡
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
      this.animTotalTags = Math.round(startTags + (targetTags - startTags) * ease);

      for (let i = 0; i < this.topTags.length; i++) {
        const startVal = i < startTagCounts.length ? startTagCounts[i] : 0;
        const targetVal = this.topTags[i].count;
        this.topTags[i].displayCount = Math.round(startVal + (targetVal - startVal) * ease);
      }

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

  private getAirportCodeText(): string {
    if (this.isLocating) {
      return '定位中...';
    }
    if (this.nearestAirport && this.nearestAirport.code) {
      return this.nearestAirport.code;
    }
    return 'FOCUS';
  }

  private async requestUserLocation(): Promise<void> {
    if (this.isLocating) {
      return;
    }
    this.isLocating = true;
    try {
      const airport = await LocationService.requestLocationAndGetNearestAirport();
      if (airport) {
        this.nearestAirport = airport;
        promptAction.showToast({
          message: `📍 已匹配您附近的基地机场：${airport.name} (${airport.code})`,
          duration: 2500
        });
      } else {
        promptAction.showToast({
          message: '未获取到位置，可开启系统定位权限后重试',
          duration: 2000
        });
      }
    } catch (e) {
      promptAction.showToast({
        message: '定位请求失败，请稍后重试',
        duration: 2000
      });
    } finally {
      this.isLocating = false;
    }
  }

  build() {
    Column() {
      // 沉浸式深紫色头部导航
      Column() {
        Row() {
          // 自定义几何绘制关闭按钮 (遵循 UI Skill)
          CloseButton({
            circleColor: "rgba(255,255,255,0.1)",
            iconColor: "#FFFFFF",
            onClickAction: () => {
              if (this.onClose) {
                this.onClose();
              }
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
        
        // ALL-TIME / 2026 / 2025 Tabs - 动态多年度滑动高亮胶囊动效 (靠左对齐)
        Row() {
          Stack({ alignContent: Alignment.Start }) {
            // 底槽背景
            Row()
              .width(this.getTabList().length * 68)
              .height(30)
              .backgroundColor("rgba(255, 255, 255, 0.08)")
              .borderRadius(15)

            // 平滑滑动的半透高亮胶囊
            Row()
              .width(68)
              .height(30)
              .backgroundColor("rgba(255, 255, 255, 0.22)")
              .borderRadius(15)
              .offset({ x: this.getSelectedTabIndex() * 68 })
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })

            // 选项文字层
            Row() {
              ForEach(this.getTabList(), (tabItem: TimeTabItem) => {
                Text(tabItem.label)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedTimeTab === tabItem.id ? "#FFFFFF" : "rgba(255,255,255,0.5)")
                  .textAlign(TextAlign.Center)
                  .width(68)
                  .height(30)
                  .onClick(() => {
                    if (this.selectedTimeTab !== tabItem.id) {
                      this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
                        this.selectedTimeTab = tabItem.id;
                      });
                      this.loadDbStats(false);
                    }
                  })
              }, (tabItem: TimeTabItem) => tabItem.id)
            }
            .width(this.getTabList().length * 68)
            .height(30)
          }
        }
        .width("100%")
        .padding({ left: 20, right: 20, bottom: 16 })
        .justifyContent(FlexAlign.Start)
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
            // 3D 地图与上下半透明装饰带容器 (真对称浮动架构)
            Stack({ alignContent: Alignment.TopStart }) {
              // 1. 3D WebGL 地球 (视口高度与容器严格一致为 300)
              Web({ src: $rawfile("earth.html"), controller: this.controller })
                .width("100%")
                .height(300)
                .backgroundColor(Color.Transparent)
                .onPageEnd(() => {
                  this.syncHistoricalRoutesToEarth();
                })

              // 2. 顶部飞机与动态机场定位带
              Row({ space: 16 }) {
                ForEach([
                  'plane', 'plane', 'plane', 'plane', 'plane', 
                  'dot', 'AIRPORT_CODE', 'dot', 
                  'plane', 'plane', 'plane', 'plane', 'plane'
                ], (item: string, index: number) => {
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
                      // 纯展示文案：定位后显示三字码，未定位显示 FOCUS，无点击态
                      Text(this.getAirportCodeText())
                        .fontSize(14)
                        .fontColor(this.getGradientColor(index, 13))
                        .fontWeight(FontWeight.Bold)
                        .letterSpacing(2)
                    }
                  }
                }, (item: string, index: number) => index.toString())
              }
              .width("100%")
              .height(38)
              .backgroundColor("rgba(30, 16, 69, 0.6)")
              .borderRadius({ topLeft: 24, topRight: 24 })
              .clip(true)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .position({ x: 0, y: 0 })
              .zIndex(2)

              // 3. 底部国旗装饰带 (对称磨砂横幅，横跨浮动于地球底缘，上下微光边线 + 绝对几何居中)
              Row() {
                ForEach(['🇨🇳', '🇯🇵', '🇰🇷', '🇸🇬', '🇦🇪', '🇬🇧', '🇫🇷', '🇩🇪', '🇺🇸', '🇦🇺', '🇨🇦'], (flag: string, index: number) => {
                  Stack({ alignContent: Alignment.Center }) {
                    Text(flag)
                      .fontSize(16)
                      .textAlign(TextAlign.Center)
                  }
                  .height(38)
                  .layoutWeight(1)
                }, (flag: string, index: number) => flag + index)
              }
              .width("100%")
              .height(38)
              .padding({ left: 16, right: 16 })
              .backgroundColor("rgba(30, 16, 69, 0.75)")
              .borderWidth({ top: 1, bottom: 1 })
              .borderColor("rgba(255, 255, 255, 0.08)")
              .position({ x: 0, y: 262 })
              .zIndex(2)
            }
            .width("100%")
            .height(300)
            .borderRadius({ topLeft: 24, topRight: 24 })
            .clip(true)

            Divider().color("rgba(255,255,255,0.05)")

            // 护照标题区
            Row() {
              Column({ space: 4 }) {
                Text("我的专注飞行记录").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#FFFFFF").letterSpacing(1)
                Text("Focus Flight · 终身专注里程碑").fontSize(10).fontColor("rgba(255,255,255,0.5)").fontWeight(FontWeight.Medium)
              }.alignItems(HorizontalAlign.Start)
              
              Blank()
            }.width("100%").padding({ left: 24, right: 24, top: 24, bottom: 24 }).alignItems(VerticalAlign.Top)

            // 数据网格
            Grid() {
              GridItem() {
                Column({ space: 4 }) {
                  Text("完成专注 (次)").fontSize(10).fontColor("rgba(255,255,255,0.5)").letterSpacing(1)
                  Text(this.animFlights.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor("#FFFFFF")
                }.alignItems(HorizontalAlign.Start).width("100%")
              }
              GridItem() {
                Column({ space: 4 }) {
                  Text("累计航程 (km)").fontSize(10).fontColor("rgba(255,255,255,0.5)").letterSpacing(1)
                  Text(this.animDistance.toLocaleString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor("#FFFFFF")
                }.alignItems(HorizontalAlign.Start).width("100%")
              }
              GridItem() {
                Column({ space: 4 }) {
                  Text("总专注时长").fontSize(10).fontColor("rgba(255,255,255,0.5)").letterSpacing(1)
                  Text(this.formatDuration(this.animMinutes)).fontSize(28).fontWeight(FontWeight.Bold).fontColor("#FFFFFF")
                }.alignItems(HorizontalAlign.Start).width("100%")
              }
              GridItem() {
                Column({ space: 4 }) {
                  Text("探索目的地 (个)").fontSize(10).fontColor("rgba(255,255,255,0.5)").letterSpacing(1)
                  Text(this.animDestinations.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor("#FFFFFF")
                }.alignItems(HorizontalAlign.Start).width("100%")
              }
              GridItem() {
                Column({ space: 4 }) {
                  Text("连续专注 (天)").fontSize(10).fontColor("rgba(255,255,255,0.5)").letterSpacing(1)
                  Text(this.animStreak.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor("#FFFFFF")
                }.alignItems(HorizontalAlign.Start).width("100%")
              }
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
          .backgroundColor("#1E1045") // 护照卡的底色
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
                Text(this.animFlights.toString()).fontSize(48).fontWeight(FontWeight.Bold).fontColor("#000000")
                Text(`${this.animShortHaul} 次短途番茄钟 / ${this.animLongHaul} 次深空长航`).fontSize(14).fontColor("#94A3B8").margin({ top: 4 })
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
                
                Stack({ alignContent: Alignment.Start }) {
                  // 滑动高亮背景
                  Row()
                    .width(56)
                    .height(24)
                    .backgroundColor("#F1F5F9")
                    .borderRadius(12)
                    .offset({ x: this.currentChartMode === 'month' ? 0 : 56 })
                    .animation({ duration: 300, curve: Curve.FastOutSlowIn })

                  Row() {
                    // 按月份 Tab
                    Text("按月份")
                      .fontSize(12)
                      .fontColor(this.currentChartMode === 'month' ? "#000000" : "#94A3B8")
                      .textAlign(TextAlign.Center)
                      .width(56)
                      .height(24)
                      .onClick(() => {
                        this.currentChartMode = 'month';
                        this.loadTrendChartData();
                      })

                    // 按星期 Tab
                    Text("按星期")
                      .fontSize(12)
                      .fontColor(this.currentChartMode === 'week' ? "#000000" : "#94A3B8")
                      .textAlign(TextAlign.Center)
                      .width(56)
                      .height(24)
                      .onClick(() => {
                        this.currentChartMode = 'week';
                        this.loadTrendChartData();
                      })
                  }
                }
              }.width("100%").padding({ left: 20, right: 20, bottom: 16 })

              Scroll() {
                Row() {
                  ForEach(this.chartData, (item: ChartItem, index: number) => {
                    DayBarComponent({ item: item })
                      .transition({ type: TransitionType.Insert, translate: { x: 200 }, opacity: 0 })
                      .transition({ type: TransitionType.Delete, translate: { x: 200 }, opacity: 0 })
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

            // 3. 专注总时长 (合并原里程)
            Column({ space: 4 }) {
              Text("专注总时长").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000")
              Row() {
                Text(this.animMinutes.toLocaleString()).fontSize(48).fontWeight(FontWeight.Bold).fontColor("#000000")
                Text("分钟").fontSize(24).fontWeight(FontWeight.Medium).fontColor("#94A3B8").margin({ left: 4, bottom: 6 })
              }.alignItems(VerticalAlign.Bottom)
              Text(`约合 ${(this.animMinutes / 60).toFixed(1)} 小时 · ${Math.round(this.animMinutes / 25)} 次标准番茄钟`).fontSize(14).fontColor("#94A3B8").margin({ top: 4 })
            }.width("100%").alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, bottom: 20 })

            // 里程碑进度条 1: 环球探索 (始终展示终身累计图鉴)
            Column({ space: 8 }) {
              Row() {
                Row({ space: 6 }) {
                  Text("🗺️").fontSize(14)
                  Text("环球探索").fontSize(13).fontWeight(FontWeight.Bold).fontColor("#1E293B")
                  Text("终身里程碑")
                    .fontSize(10)
                    .fontColor("#6366F1")
                    .backgroundColor("rgba(99, 102, 241, 0.08)")
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .fontWeight(FontWeight.Medium)
                }
                Blank()
                Text(`${this.allTimeStats.uniqueDestinationsCount} / 250+ 座机场`).fontSize(12).fontColor("#64748B").fontWeight(FontWeight.Medium)
              }.width("100%")

              Stack({ alignContent: Alignment.Start }) {
                Row().width("100%").height(12).backgroundColor("#F1F5F9").borderRadius(6)
                Row()
                  .width(`${Math.min(100, Math.max(4, Math.round((this.allTimeStats.uniqueDestinationsCount / 250) * 100)))}%`)
                  .height(12)
                  .linearGradient({ angle: 90, colors: [["#6366F1", 0], ["#4F46E5", 1]] })
                  .borderRadius(6)
                  .animation({ duration: 350, curve: Curve.FastOutSlowIn })
              }.width("100%")
            }.width("100%").padding({ left: 20, right: 20, bottom: 16 })

            // 里程碑进度条 2: 大师之路 (始终展示终身累计总进度)
            Column({ space: 8 }) {
              Row() {
                Row({ space: 6 }) {
                  Text("🎓").fontSize(14)
                  Text("大师之路 (一万小时定律)").fontSize(13).fontWeight(FontWeight.Bold).fontColor("#1E293B")
                  Text("终身成就")
                    .fontSize(10)
                    .fontColor("#8B5CF6")
                    .backgroundColor("rgba(139, 92, 246, 0.08)")
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)
                    .fontWeight(FontWeight.Medium)
                }
                Blank()
                Text(`${((this.allTimeStats.totalMinutes / 60) / 10000 * 100).toFixed(2)}%`).fontSize(12).fontColor("#64748B").fontWeight(FontWeight.Medium)
              }.width("100%")

              Stack({ alignContent: Alignment.Start }) {
                Row().width("100%").height(12).backgroundColor("#F1F5F9").borderRadius(6)
                Row()
                  .width(`${Math.min(100, Math.max(4, Math.round(((this.allTimeStats.totalMinutes / 60) / 10000 * 100))))}%`)
                  .height(12)
                  .linearGradient({ angle: 90, colors: [["#8B5CF6", 0], ["#7C3AED", 1]] })
                  .borderRadius(6)
                  .animation({ duration: 350, curve: Curve.FastOutSlowIn })
              }.width("100%")
            }.width("100%").padding({ left: 20, right: 20, bottom: 24 })

            Divider().color("#F1F5F9").margin({ left: 20, right: 20, bottom: 20 })

            // 5. 排行榜 (Top Visited Airports) -> 最常专注任务 (动态从数据库读取)
            Column({ space: 16 }) {
              Text("最常执行任务 (Top Tags)").fontSize(18).fontWeight(FontWeight.Bold).fontColor("#000000")
              Text(`${this.topTags.length} 个总标签`).fontSize(14).fontColor("#94A3B8").margin({ top: -8 })
              
              ForEach(this.topTags, (tagItem: TagChartItem) => {
                TopTagBarComponent({ item: tagItem })
              })
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
    if (t < 0.5) {
      const t2 = t * 2;
      const r = Math.round(0xF6 + (0xC0 - 0xF6) * t2);
      const g = Math.round(0xC4 + (0x74 - 0xC4) * t2);
      const b = Math.round(0x92 + (0xE1 - 0x92) * t2);
      return `rgb(${r},${g},${b})`;
    } else {
      const t2 = (t - 0.5) * 2;
      const r = Math.round(0xC0 + (0x81 - 0xC0) * t2);
      const g = Math.round(0x74 + (0xE8 - 0x74) * t2);
      const b = Math.round(0xE1 + (0xE6 - 0xE1) * t2);
      return `rgb(${r},${g},${b})`;
    }
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
export struct TopTagBarComponent {
  @ObjectLink item: TagChartItem;

  private getBarWidthPercent(): string {
    return `${Math.min(100, Math.max(12, this.item.ratioPercent))}%`;
  }

  build() {
    Row({ space: 12 }) {
      Text(this.item.tag)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor("#1E293B")
        .width(108)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width("100%")
          .height(12)
          .backgroundColor("#F1F5F9")
          .borderRadius(6)

        Row()
          .width(this.getBarWidthPercent())
          .height(12)
          .linearGradient({ angle: 90, colors: [["#8B5CF6", 0], ["#6366F1", 1]] })
          .borderRadius(6)
          .animation({ duration: 400, curve: Curve.FastOutSlowIn })
      }
      .layoutWeight(1)

      Text(`${this.item.displayCount} 次`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor("#64748B")
        .width(36)
        .textAlign(TextAlign.End)
    }
    .width("100%")
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct DayBarComponent {
  @ObjectLink item: ChartItem;

  private getBarHeight(): number {
    if (this.item.value <= 0) {
      return 6;
    }
    return Math.min(88, Math.max(14, this.item.value * 18));
  }

  build() {
    Column({ space: 8 }) {
      // Bar
      Stack({ alignContent: Alignment.Bottom }) {
        Row().width(24).height(96).backgroundColor("transparent")
        Row()
          .width(22)
          .height(this.getBarHeight())
          .backgroundColor(this.item.value > 0 ? "#6366F1" : "#E2E8F0")
          .borderRadius(4)
          .animation({ duration: 400, curve: Curve.EaseInOut })
      }
      Text(this.item.label).fontSize(12).fontColor(this.item.value > 0 ? "#334155" : "#94A3B8").fontWeight(FontWeight.Medium)
    }
  }
}
