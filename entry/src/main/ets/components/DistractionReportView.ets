import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  FlightRecordRepository,
  DistractionReportSummary,
  WorstDelayRecord,
  PerformanceCategory,
  DistractionBlacklistItem
} from '../database/FlightRecordRepository';

export interface TimeTabItem {
  id: string;
  label: string;
}

@Observed
export class PerformanceBarItem {
  @Track title: string;
  @Track percent: number;
  @Track displayPercent: number;
  @Track ratioPercent: number;
  @Track color: string;

  constructor(title: string, percent: number, color: string, ratioPercent: number = 0, displayPercent: number = 0) {
    this.title = title;
    this.percent = percent;
    this.displayPercent = displayPercent > 0 ? displayPercent : percent;
    this.ratioPercent = ratioPercent > 0 ? ratioPercent : percent;
    this.color = color;
  }
}

@Observed
export class BlacklistChartItem {
  @Track tag: string;
  @Track failRate: number;
  @Track displayPercent: number;
  @Track ratioPercent: number;
  @Track failTextSuffix: string;

  constructor(tag: string, failRate: number, failTextSuffix: string = '失败', ratioPercent: number = 0, displayPercent: number = 0) {
    this.tag = tag;
    this.failRate = failRate;
    this.displayPercent = displayPercent > 0 ? displayPercent : Math.round(failRate * 100);
    this.ratioPercent = ratioPercent > 0 ? ratioPercent : Math.round(failRate * 100);
    this.failTextSuffix = failTextSuffix;
  }
}

@Component
export struct DistractionPerformanceBarComponent {
  @ObjectLink item: PerformanceBarItem;

  build() {
    Row() {
      Text(this.item.title)
        .fontSize(14)
        .fontColor("#FFFFFF")
        .fontWeight(FontWeight.Medium)
        .width(80)

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(16)
          .backgroundColor("rgba(0,0,0,0.3)")
          .borderRadius(4)

        Row()
          .height(16)
          .width(`${Math.min(100, Math.max(6, this.item.ratioPercent))}%`)
          .backgroundColor(this.item.color)
          .borderRadius(4)
          .animation({ duration: 450, curve: Curve.FastOutSlowIn })
      }
      .layoutWeight(1)
      .margin({ left: 12, right: 12 })

      Text(`${this.item.displayPercent}%`)
        .fontSize(14)
        .fontColor("rgba(255,255,255,0.6)")
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@Component
export struct DistractionBlacklistComponent {
  @ObjectLink item: BlacklistChartItem;

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.item.tag)
          .fontSize(15)
          .fontColor("#FFFFFF")
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${this.item.displayPercent}% ${this.item.failTextSuffix}`)
          .fontSize(14)
          .fontColor("#FFFFFF")
          .fontWeight(FontWeight.Bold)
          .margin({ left: 8 })
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(12)
          .backgroundColor("rgba(0,0,0,0.3)")
          .borderRadius(4)

        Row()
          .height(12)
          .width(`${Math.min(100, Math.max(6, this.item.ratioPercent))}%`)
          .backgroundColor("#EF4444")
          .borderRadius(4)
          .animation({ duration: 450, curve: Curve.FastOutSlowIn })
      }
      .width('100%')
    }
    .width('100%')
  }
}

@Component
export struct DistractionReportView {
  onClose?: () => void;
  @Prop @Watch('onSelectedYearPropChanged') selectedYear: string = 'all';
  @StorageProp('flightStatsUpdateTrigger') @Watch('onStatsTriggerChanged') statsTrigger: number = 0;

  @State selectedTimeTab: string = 'all';
  @State availableYears: Array<number> = [2026, 2025];

  // 丝滑滚动插值数字与进度状态 (60 FPS Ease-Out Cubic)
  @State animInterruptedPercent: number = 0;
  @State animTotalCount: number = 0;
  @State animInterruptedCount: number = 0;
  @State animTotalLostMinutes: number = 0;
  @State animAvgLostMinutes: number = 0;
  @State animWorstDurationMin: number = 0;
  private animTimer: number = -1;

  @State performanceBarItems: Array<PerformanceBarItem> = [
    new PerformanceBarItem("完美心流", 58, "#4ADE80", 58, 58),
    new PerformanceBarItem("极度投入", 20, "#86EFAC", 20, 20),
    new PerformanceBarItem("轻度走神", 11, "#FBBF24", 11, 11),
    new PerformanceBarItem("中度摸鱼", 6, "#F97316", 6, 6),
    new PerformanceBarItem("中途放弃", 5, "#EF4444", 5, 5)
  ];

  @State blacklistItems: Array<BlacklistChartItem> = [
    new BlacklistChartItem("深度学习 (切出后台)", 1.0, "失败", 100, 100),
    new BlacklistChartItem("需求梳理 (紧急会议中断)", 0.8, "失败", 80, 80),
    new BlacklistChartItem("交互体验与设计打磨", 0.35, "走神", 35, 35)
  ];

  @State reportData: DistractionReportSummary = {
    totalCount: 37,
    interruptedCount: 2,
    interruptedPercent: 5,
    totalLostMinutes: 12,
    avgLostMinutes: 6,
    worstRecord: {
      durationMin: 45,
      taskTitle: '深度学习 (切出后台)',
      reason: '切出后台'
    },
    performanceList: [
      { title: "完美心流", percentText: "58%", color: "#4ADE80", progress: 0.58 },
      { title: "极度投入", percentText: "20%", color: "#86EFAC", progress: 0.20 },
      { title: "轻度走神", percentText: "11%", color: "#FBBF24", progress: 0.11 },
      { title: "中度摸鱼", percentText: "6%", color: "#F97316", progress: 0.06 },
      { title: "中途放弃", percentText: "5%", color: "#EF4444", progress: 0.05 }
    ],
    blacklist: [
      { tag: "深度学习 (切出后台)", failText: "100% 失败", failRate: 1.0 },
      { tag: "交互体验与设计打磨", failText: "15% 走神", failRate: 0.15 },
      { tag: "系统架构演进", failText: "10% 摸鱼", failRate: 0.1 }
    ]
  };

  aboutToAppear(): void {
    if (this.selectedYear) {
      this.selectedTimeTab = this.selectedYear;
    }
    this.loadDistractionStats();
  }

  aboutToDisappear(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
  }

  private onSelectedYearPropChanged(): void {
    if (this.selectedYear && this.selectedYear !== this.selectedTimeTab) {
      this.selectedTimeTab = this.selectedYear;
      this.loadDistractionStats();
    }
  }

  private onStatsTriggerChanged(): void {
    this.loadDistractionStats();
  }

  private async loadDistractionStats(): Promise<void> {
    try {
      await FlightRecordRepository.seed2025MockDataIfEmpty();
      const years = await FlightRecordRepository.getAvailableYears();
      if (years && years.length > 0) {
        this.availableYears = years;
      }
      const yearFilter = this.selectedTimeTab === 'all' ? undefined : parseInt(this.selectedTimeTab);
      const summary = await FlightRecordRepository.getDistractionReportSummary(yearFilter);
      if (summary) {
        this.reportData = summary;
        this.startNumberRollingAnimation(summary);
      }
    } catch (e) {
      hilog.error(0x0000, 'DistractionReportView', 'Failed to load distraction stats: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 丝滑数字与进度条滚动缓动动画 (Ease-Out Cubic)
   */
  private startNumberRollingAnimation(targetSummary: DistractionReportSummary): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }

    const startPercent = this.animInterruptedPercent;
    const startTotal = this.animTotalCount;
    const startInterrupted = this.animInterruptedCount;
    const startLostMin = this.animTotalLostMinutes;
    const startAvgLost = this.animAvgLostMinutes;
    const startWorstMin = this.animWorstDurationMin;

    const targetPercent = targetSummary.interruptedPercent;
    const targetTotal = targetSummary.totalCount;
    const targetInterrupted = targetSummary.interruptedCount;
    const targetLostMin = targetSummary.totalLostMinutes;
    const targetAvgLost = targetSummary.avgLostMinutes;
    const targetWorstMin = targetSummary.worstRecord.durationMin;

    const targetPercents: Array<number> = [
      Math.round((targetSummary.performanceList[0]?.progress || 0) * 100),
      Math.round((targetSummary.performanceList[1]?.progress || 0) * 100),
      Math.round((targetSummary.performanceList[2]?.progress || 0) * 100),
      Math.round((targetSummary.performanceList[3]?.progress || 0) * 100),
      Math.round((targetSummary.performanceList[4]?.progress || 0) * 100)
    ];

    const startPercents: Array<number> = this.performanceBarItems.map(item => item.displayPercent);

    // 触发进度条硬件加速动画
    for (let i = 0; i < this.performanceBarItems.length && i < targetPercents.length; i++) {
      this.performanceBarItems[i].percent = targetPercents[i];
      this.performanceBarItems[i].ratioPercent = targetPercents[i];
    }

    // 黑榜数据同步与动画初始化（原地复用对象，确保 ArkTS 不会重建组件，从而完美触发属性插值与宽度变形动画）
    const defaultBlacklist: Array<DistractionBlacklistItem> = [
      { tag: "深度学习 (切出后台)", failText: "100% 失败", failRate: 1.0 },
      { tag: "需求梳理 (紧急会议中断)", failText: "65% 打断", failRate: 0.65 },
      { tag: "交互体验与设计打磨", failText: "30% 走神", failRate: 0.30 }
    ];
    const newBlacklist: Array<DistractionBlacklistItem> = (targetSummary.blacklist && targetSummary.blacklist.length > 0)
      ? targetSummary.blacklist
      : defaultBlacklist;

    const startBlacklistPercents: Array<number> = this.blacklistItems.map(it => it.displayPercent);
    const targetBlacklistPercents: Array<number> = newBlacklist.map(it => Math.round((it.failRate !== undefined ? it.failRate : 0.5) * 100));

    for (let i = 0; i < newBlacklist.length; i++) {
      const b = newBlacklist[i];
      const targetRate = b.failRate !== undefined ? b.failRate : 0.5;
      const targetP = Math.round(targetRate * 100);
      const suffix = b.failText ? b.failText.replace(/^[0-9]+%\s*/, '') || '失败' : '失败';

      if (i < this.blacklistItems.length) {
        this.blacklistItems[i].tag = b.tag;
        this.blacklistItems[i].failRate = targetRate;
        this.blacklistItems[i].failTextSuffix = suffix;
        this.blacklistItems[i].ratioPercent = targetP; // 立即触发硬件加速形变动画
      } else {
        this.blacklistItems.push(new BlacklistChartItem(b.tag, targetRate, suffix, targetP, targetP));
      }
    }
    if (this.blacklistItems.length > newBlacklist.length) {
      this.blacklistItems = this.blacklistItems.slice(0, newBlacklist.length);
    }

    const duration = 500; // 500ms
    const fps = 60;
    const totalFrames = Math.round((duration / 1000) * fps);
    let frame = 0;

    this.animTimer = setInterval(() => {
      frame++;
      const progress = Math.min(1, frame / totalFrames);
      const ease = 1 - Math.pow(1 - progress, 3);

      this.animInterruptedPercent = Math.round(startPercent + (targetPercent - startPercent) * ease);
      this.animTotalCount = Math.round(startTotal + (targetTotal - startTotal) * ease);
      this.animInterruptedCount = Math.round(startInterrupted + (targetInterrupted - startInterrupted) * ease);
      this.animTotalLostMinutes = Math.round(startLostMin + (targetLostMin - startLostMin) * ease);
      this.animAvgLostMinutes = Math.round(startAvgLost + (targetAvgLost - startAvgLost) * ease);
      this.animWorstDurationMin = Math.round(startWorstMin + (targetWorstMin - startWorstMin) * ease);

      for (let i = 0; i < this.performanceBarItems.length && i < targetPercents.length; i++) {
        const sP = startPercents[i];
        const tP = targetPercents[i];
        this.performanceBarItems[i].displayPercent = Math.round(sP + (tP - sP) * ease);
      }

      for (let i = 0; i < this.blacklistItems.length && i < targetBlacklistPercents.length; i++) {
        const sP = startBlacklistPercents[i] !== undefined ? startBlacklistPercents[i] : 0;
        const tP = targetBlacklistPercents[i] !== undefined ? targetBlacklistPercents[i] : 0;
        this.blacklistItems[i].displayPercent = Math.round(sP + (tP - sP) * ease);
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

  private getFlipChars(): Array<string> {
    const mins = this.animTotalLostMinutes;
    if (mins >= 60) {
      const h = Math.floor(mins / 60);
      const m = mins % 60;
      return [`${h}`, "h", `${m}`, "m"];
    }
    const str = mins.toString().padStart(2, '0');
    return [str.charAt(0), str.charAt(1), "分", "钟"];
  }

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
      .padding({ left: 20, right: 20, top: 48, bottom: 12 })

      // 年份选择器胶囊 Tab (左对齐，动态联动)
      Row() {
        Stack({ alignContent: Alignment.Start }) {
          // 滑动胶囊背景
          Row()
            .width(68)
            .height(32)
            .backgroundColor("rgba(255,255,255,0.2)")
            .borderRadius(16)
            .offset({ x: this.getSelectedTabIndex() * 68 })
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })

          Row() {
            ForEach(this.getTabList(), (tab: TimeTabItem) => {
              Text(tab.label)
                .fontSize(13)
                .fontWeight(this.selectedTimeTab === tab.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.selectedTimeTab === tab.id ? "#FFFFFF" : "rgba(255,255,255,0.5)")
                .textAlign(TextAlign.Center)
                .width(68)
                .height(32)
                .onClick(() => {
                  this.selectedTimeTab = tab.id;
                  this.loadDistractionStats();
                })
            }, (tab: TimeTabItem) => tab.id)
          }
        }
        .height(32)
        .backgroundColor("rgba(0,0,0,0.3)")
        .borderRadius(16)
        .padding(2)
      }
      .width("100%")
      .justifyContent(FlexAlign.Start)
      .padding({ left: 20, bottom: 16 })

      Scroll() {
        Column({ space: 30 }) {
          
          // 1. 核心概览 (Summary)
          Column({ space: 8 }) {
            Text(`${this.animInterruptedPercent}%`)
              .fontSize(64)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: -10 })
            
            Text("的专注被中途打断")
              .fontSize(22)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Text(`在你最近的 ${this.animTotalCount} 次专注中，有 ${this.animInterruptedCount} 次未能完美达成`)
              .fontSize(14)
              .fontColor("rgba(255,255,255,0.6)")
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          
          // 2. 翻页钟 (Lost to Delays)
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              ForEach(this.getFlipChars(), (char: string, index: number) => {
                this.FlipCard(char)
              }, (char: string, index: number) => `${char}_${index}_${this.animTotalLostMinutes}`)
            }
            
            Text("因分心流失的总时长")
              .fontSize(18)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Text(`平均每次打断耗费 ${this.animAvgLostMinutes} 分钟`)
              .fontSize(14)
              .fontColor("rgba(255,255,255,0.6)")
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          
          // 3. 最惨痛打断 (Worst Delay)
          Column({ space: 10 }) {
            Text("最惨痛的摸鱼记录")
              .fontSize(18)
              .fontColor("#FFFFFF")
              .fontWeight(FontWeight.Bold)
              
            Column({ space: 10 }) {
              // 第一行：航线任务标题 + 右侧异常原因 Badge
              Row() {
                Row({ space: 6 }) {
                  Text("航线")
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor("rgba(255,255,255,0.7)")
                    .backgroundColor("rgba(255,255,255,0.12)")
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(4)

                  Text(this.reportData.worstRecord.taskTitle)
                    .fontSize(14)
                    .fontColor("#FFFFFF")
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)
                }
                .layoutWeight(1)
                .alignItems(VerticalAlign.Center)

                // 迫降原因 Badge 胶囊
                Text(this.reportData.worstRecord.reason)
                  .fontSize(12)
                  .fontColor("#FCA5A5")
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor("rgba(239, 68, 68, 0.2)")
                  .border({ width: 1, color: "rgba(239, 68, 68, 0.3)" })
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(10)
                  .margin({ left: 10 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Divider().color("rgba(255,255,255,0.08)")

              // 第二行：原定计划专注目标
              Row() {
                Text("原定专注目标")
                  .fontSize(13)
                  .fontColor("rgba(255,255,255,0.5)")
                Blank()
                Text(`${this.animWorstDurationMin} 分钟`)
                  .fontSize(16)
                  .fontColor("#FCA5A5")
                  .fontFamily("HarmonyOS Sans")
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(14)
            .backgroundColor("rgba(0,0,0,0.4)")
            .borderRadius(12)
            .border({ width: 1, color: "rgba(255,255,255,0.08)" })
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
              ForEach(this.performanceBarItems, (item: PerformanceBarItem) => {
                DistractionPerformanceBarComponent({ item: item })
              }, (item: PerformanceBarItem) => item.title)
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
              ForEach(this.blacklistItems, (item: BlacklistChartItem, index: number) => {
                DistractionBlacklistComponent({ item: item })
              }, (item: BlacklistChartItem, index: number) => index.toString())
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
          .width(`${Math.min(100, Math.max(6, Math.round(ratio * 100)))}%`)
          .backgroundColor(barColor)
          .borderRadius(4)
          .animation({ duration: 400, curve: Curve.FastOutSlowIn })
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
          .width(`${Math.max(4, Math.round(ratio * 100))}%`)
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
