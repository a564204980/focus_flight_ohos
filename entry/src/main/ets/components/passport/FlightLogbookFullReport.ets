/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { CloseButton } from '../CloseButton';
import {
  FlightRecordDateFilter,
  FlightRecordItem,
  FlightRecordRepository
} from '../../database/FlightRecordRepository';
import { FlightBoardingPassCard } from './FlightBoardingPassCard';
import { FlightDatePickerModal } from './FlightDatePickerModal';

export interface HeatmapDayCell {
  dateStr: string;
  year: number;
  month: number;
  day: number;
  dayOfWeek: number; // 0: 日, 1: 一 ... 6: 六
  minutes: number;
  level: number;     // 0-4
  isToday: boolean;
  isPaddingDay?: boolean;
}

export interface HeatmapPeriod {
  startM: number;
  endM: number;
}

export interface HeatmapWeekColumn {
  weekKey: string;
  cells: HeatmapDayCell[];
  monthLabel: string;
}

export interface HeatmapCellPositionInfo {
  x: number;
  y: number;
  cell: HeatmapDayCell;
}

/**
 * 热力图单页 Canvas 渲染组件
 * 将原来 ~364 个独立 Row 节点（含 shadow/scale/border 三元运算）压缩为一个 Canvas 节点
 * 通过 onTouch 坐标反算识别点击格子，选中态通过局部重绘更新
 */
@Component
struct HeatmapCanvasPage {
  @Prop @Watch('onPageDataChanged') pageData: HeatmapWeekColumn[] = [];
  @Prop @Watch('onSelectionChanged') selectedDateStr: string = '';
  @Prop todayStr: string = '';
  @Prop dataVersion: number = 0;
  onSelectDate?: (cell: HeatmapDayCell) => void;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 布局常量（与父组件 padding 对齐）
  private static readonly CELL = 13;    // 格子尺寸 vp
  private static readonly GAP = 3.5;    // 格子间距 vp
  private static readonly COL_W = 13;   // 列宽 vp（与 CELL 一致，列间距由 FlexAlign.SpaceBetween 撑开）
  private static readonly ROW_H = 16.5; // 行高 = CELL + GAP

  // 颜色查表（避免 switch 重复创建字符串）
  private static readonly COLORS: string[] = [
    '#24282B',                    // Level 0
    'rgba(99, 102, 241, 0.40)',   // Level 1
    'rgba(99, 102, 241, 0.70)',   // Level 2
    '#6366F1',                    // Level 3
    '#38BDF8'                     // Level 4
  ];

  @State canvasWidth: number = 0;
  @State selectedCellInfo: HeatmapCellPositionInfo | null = null;

  onPageDataChanged(): void {
    this.updateSelectedCellInfo();
    this.drawPage();
  }

  onSelectionChanged(): void {
    this.updateSelectedCellInfo();
  }

  aboutToAppear(): void {
    // 数据就绪后由 onReady / onAreaChange 触发绘制
  }

  private getColSpacing(): number {
    const colCount = this.pageData.length;
    return colCount > 1 ? (this.canvasWidth - HeatmapCanvasPage.CELL - 6) / (colCount - 1) : 0;
  }

  private updateSelectedCellInfo(): void {
    if (this.canvasWidth === 0 || !this.pageData || this.pageData.length === 0) {
      this.selectedCellInfo = null;
      return;
    }
    const colSpacing = this.getColSpacing();
    for (let wi = 0; wi < this.pageData.length; wi++) {
      const week = this.pageData[wi];
      if (!week || !week.cells) continue;
      for (let di = 0; di < week.cells.length; di++) {
        const cell = week.cells[di];
        if (cell.dateStr === this.selectedDateStr) {
          const info: HeatmapCellPositionInfo = {
            x: 3 + wi * colSpacing,
            y: 3 + di * HeatmapCanvasPage.ROW_H,
            cell: cell
          };
          this.selectedCellInfo = info;
          return;
        }
      }
    }
    this.selectedCellInfo = null;
  }

  /**
   * 全量绘制整页热力图矩阵的静态底图
   */
  drawPage(): void {
    const ctx = this.ctx;
    if (!ctx || this.canvasWidth === 0 || !this.pageData || this.pageData.length === 0) {
      return;
    }

    const cell = HeatmapCanvasPage.CELL;
    const rowH = HeatmapCanvasPage.ROW_H;
    const canvasW = this.canvasWidth;
    const padX = 3;
    const padY = 3;

    ctx.clearRect(0, 0, canvasW, 118);

    const colCount = this.pageData.length;
    const colSpacing = this.getColSpacing();

    for (let wi = 0; wi < colCount; wi++) {
      const week = this.pageData[wi];
      if (!week || !week.cells) continue;
      const colX = padX + wi * colSpacing;

      for (let di = 0; di < week.cells.length; di++) {
        const cell_obj = week.cells[di];
        const cellY = padY + di * rowH;

        // 底层仅负责绘制静态色块
        if (cell_obj.isPaddingDay) {
          ctx.fillStyle = '#181B1D';
        } else {
          ctx.fillStyle = HeatmapCanvasPage.COLORS[Math.min(cell_obj.level, 4)];
        }
        ctx.beginPath();
        ctx.roundRect(colX, cellY, cell, cell, 3);
        ctx.fill();

        if (cell_obj.isToday && !cell_obj.isPaddingDay) {
          ctx.strokeStyle = '#818CF8';
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.roundRect(colX, cellY, cell, cell, 3);
          ctx.stroke();
        }
      }
    }
  }

  /**
   * 通过触点坐标反算命中的热力格并返回精确坐标
   */
  private hitTestCellInfo(touchX: number, touchY: number): HeatmapCellPositionInfo | null {
    if (!this.pageData || this.canvasWidth === 0) return null;

    const cell = HeatmapCanvasPage.CELL;
    const rowH = HeatmapCanvasPage.ROW_H;
    const colCount = this.pageData.length;
    const colSpacing = this.getColSpacing();
    const padX = 3;
    const padY = 3;

    if (touchY < 0 || touchY > 118) return null;

    const adjX = touchX - padX;
    const adjY = touchY - padY;

    let bestCol = -1;
    let bestDist = 999;
    for (let wi = 0; wi < colCount; wi++) {
      const colX = wi * colSpacing + cell / 2;
      const dist = Math.abs(adjX - colX);
      if (dist < bestDist) {
        bestDist = dist;
        bestCol = wi;
      }
    }
    if (bestCol < 0 || bestDist > cell) return null;

    const dayIdx = Math.floor(adjY / rowH);
    const week = this.pageData[bestCol];
    if (!week || !week.cells || dayIdx >= week.cells.length) return null;
    
    const result: HeatmapCellPositionInfo = {
      x: padX + bestCol * colSpacing,
      y: padY + dayIdx * rowH,
      cell: week.cells[dayIdx]
    };
    return result;
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 1. 底层：Canvas 仅负责渲染静态方块
        Canvas(this.ctx)
          .width('100%')
          .height(118)
          .backgroundColor(Color.Transparent)
          .onReady(() => {
            if (this.canvasWidth > 0) this.drawPage();
          })
          .onAreaChange((oldVal, newVal) => {
            if (newVal.width !== oldVal.width) {
              this.canvasWidth = newVal.width as number;
              this.updateSelectedCellInfo();
              this.drawPage();
            }
          })
          .onClick((event: ClickEvent) => {
            const hit = this.hitTestCellInfo(event.x, event.y);
            if (hit && this.onSelectDate) {
              this.onSelectDate(hit.cell);
            }
          })

        // 2. 动画层：当前选中的格子 (悬浮高光框)
        if (this.selectedCellInfo) {
          Row()
            .width(HeatmapCanvasPage.CELL)
            .height(HeatmapCanvasPage.CELL)
            .backgroundColor(HeatmapCanvasPage.COLORS[Math.min(this.selectedCellInfo.cell.level, 4)])
            .borderRadius(3)
            .border({ width: 1.5, color: '#FFFFFF' })
            .shadow({
              radius: 6,
              color: 'rgba(99, 102, 241, 0.45)',
              offsetX: 0,
              offsetY: 2
            })
            .scale({ x: 1.22, y: 1.22 })
            .position({ x: this.selectedCellInfo.x, y: this.selectedCellInfo.y })
            .hitTestBehavior(HitTestMode.None)
            .animation({
              duration: 250,
              curve: Curve.Friction
            })
        }
      }
      .width('100%')
      .height(118)
      .clip(false)

      // 月份刻度行
      Row() {
        ForEach(this.pageData, (week: HeatmapWeekColumn) => {
          Row() {
            if (week.monthLabel) {
              Text(week.monthLabel)
                .fontSize(9.5)
                .fontColor('rgba(255, 255, 255, 0.4)')
                .maxLines(1)
                .width(36)
            }
          }
          .layoutWeight(1)
          .clip(false)
          .justifyContent(FlexAlign.Start)
        }, (week: HeatmapWeekColumn) => week.weekKey + '_lbl')
      }
      .width('100%')
      .clip(false)
      .height(16)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(134)
  }
}

/**
 * 航迹热力图独立轻量组件 (Canvas 版 - 消灭1092个GPU合成节点)
 * 3个 Canvas 页面替代 3 × ~364 个独立 Row 节点
 */
@Component
struct FlightHeatmapView {
  @Prop curYear: number = 2026;
  @Prop selectedDateStr: string = '';
  @Link heatmapPages: HeatmapWeekColumn[][];
  @Prop dataVersion: number = 0;
  swiperController: SwiperController = new SwiperController();
  onSelectDate?: (cell: HeatmapDayCell) => void;

  // 每页 Canvas 的独立 Controller，用于选中态局部重绘触发
  private pageRefs: HeatmapCanvasPage[] = [];

  private getTodayStr(): string {
    const t = new Date();
    return `${t.getFullYear()}-${(t.getMonth() + 1).toString().padStart(2, '0')}-${t.getDate().toString().padStart(2, '0')}`;
  }

  build() {
    Column({ space: 8 }) {
      // 标题栏与图例（纯文本/颜色块，保持不变）
      Row() {
        Row({ space: 6 }) {
          Text('航迹热力图')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text(`${this.curYear}年`)
            .fontSize(10)
            .fontColor('rgba(255, 255, 255, 0.45)')
            .backgroundColor('rgba(255, 255, 255, 0.08)')
            .padding({ left: 5, right: 5, top: 1.5, bottom: 1.5 })
            .borderRadius(4)
        }
        .alignItems(VerticalAlign.Center)

        Blank()

        Row({ space: 3.5 }) {
          Text('少')
            .fontSize(9.5)
            .fontColor('rgba(255, 255, 255, 0.4)')

          Row()
            .width(8).height(8).borderRadius(1.5)
            .backgroundColor('#24282B')

          Row()
            .width(8).height(8).borderRadius(1.5)
            .backgroundColor('rgba(99, 102, 241, 0.40)')

          Row()
            .width(8).height(8).borderRadius(1.5)
            .backgroundColor('rgba(99, 102, 241, 0.70)')

          Row()
            .width(8).height(8).borderRadius(1.5)
            .backgroundColor('#6366F1')

          Row()
            .width(8).height(8).borderRadius(1.5)
            .backgroundColor('#38BDF8')

          Text('多（时间）')
            .fontSize(9.5)
            .fontColor('rgba(255, 255, 255, 0.4)')
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')

      // 热力图矩阵：Swiper 轮播 + Canvas 整页绘制
      // 每页由单个 HeatmapCanvasPage 渲染，彻底消灭 ~1092 个 Row 节点与 shadow GPU 层
      Swiper(this.swiperController) {
        ForEach(this.heatmapPages, (page: HeatmapWeekColumn[], idx: number) => {
          HeatmapCanvasPage({
            pageData: page,
            selectedDateStr: this.selectedDateStr,
            todayStr: this.getTodayStr(),
            onSelectDate: (cell: HeatmapDayCell) => {
              if (this.onSelectDate) {
                this.onSelectDate(cell);
              }
            }
          })
        }, (page: HeatmapWeekColumn[], idx: number) => this.dataVersion.toString() + '_' + idx.toString())
      }
      .width('100%')
      .height(134)
      .loop(false)
      .indicator(false)
      .itemSpace(24)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 0, bottom: 10 })
  }
}

/**
 * 垂直时间轴节点独立可复用组件 (支持 @Reusable 鸿蒙原生复用池)
/**
 * 垂直时间轴节点独立可复用组件 (支持 @Reusable 鸿蒙原生复用池)
 * 极致优化：所有条件分支改用 .visibility() 控制，节点树结构始终固定，
 * 保证 @Reusable 复用池结构命中，彻底消除滑动时的树重建卡顿
 */
@Component
struct FlightTimelineNode {
  @Prop isTop: boolean = false;
  @Prop isBottom: boolean = false;
  @Prop isCompleted: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 1. 顶部降落箭头 (仅 top 显示)
      Image($r('app.media.ic_arrow_up'))
        .width(16).height(16).fillColor('rgba(255, 255, 255, 0.35)')
        .position({ x: 8, y: 0 })
        .opacity(this.isTop ? 1 : 0)
        .syncLoad(true)

      // 2. 顶部线段
      // 如果是首项，从箭头下方 16 画到 40；否则从顶部 0 画到 40
      Row().width(2).height(this.isTop ? 24 : 40).backgroundColor('#4B5563').borderRadius(1)
        .position({ x: 15, y: this.isTop ? 16 : 0 })

      // 3. 核心节点：小飞机 (绝对居中于 104 高度的卡片)
      // Y = 44 (加上 8 的半径中心点刚好是 52，即 104 的中点)
      Image($r('app.media.ic_plane_topview'))
        .width(16).height(16)
        .fillColor(this.isCompleted ? '#10B981' : '#9CA3AF') // 失败迫降恢复为低调灰色
        .position({ x: 8, y: 44 })
        .syncLoad(true)

      // 4. 底部线段
      // 如果是底项，从 64 画到 82 (高度 18)；否则从 64 画到底部 104 (高度 40)
      Row().width(2).height(this.isBottom ? 18 : 40).backgroundColor('#4B5563').borderRadius(1)
        .position({ x: 15, y: 64 })

      // 5. 终点徽章 (起点圆点)
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 16, height: 16 })
          .fill(this.isCompleted ? '#ECFDF5' : 'rgba(156, 163, 175, 0.15)')
          .stroke(this.isCompleted ? '#10B981' : '#9CA3AF').strokeWidth(2)
        Circle({ width: 6, height: 6 })
          .fill(this.isCompleted ? '#10B981' : '#9CA3AF')
      }
      .position({ x: 8, y: 82 })
      .opacity(this.isBottom ? 1 : 0)
    }
    .width(32)
    .height(104)
    .margin({ right: 8, left: 0 })
    .renderGroup(true) // 强制离屏渲染纹理，彻底杜绝转场期间 SVG 的 fillColor 混合闪烁 Bug
  }
}

/**
 * 航行日志列表项整行复用包装器 (支持 @Reusable)
 * 极致优化：将 ListItem 内部的所有节点包装为单一的可复用实例，彻底解决 List 滑动时重建节点的卡顿
 */
@Reusable
@Component
struct FlightLogbookListItemWrapper {
  @Prop record: FlightRecordItem;
  @Prop isTop: boolean = false;
  @Prop isBottom: boolean = false;
  @Prop isCompleted: boolean = false;
  
  onCardClick?: (record: FlightRecordItem) => void;

  aboutToReuse(params: Record<string, Object>): void {
    if (params.record !== undefined) {
      this.record = params.record as FlightRecordItem;
    }
    if (params.isTop !== undefined) {
      this.isTop = params.isTop as boolean;
    }
    if (params.isBottom !== undefined) {
      this.isBottom = params.isBottom as boolean;
    }
    if (params.isCompleted !== undefined) {
      this.isCompleted = params.isCompleted as boolean;
    }
  }

  build() {
    Row() {
      // 左侧时间轴节点 (支持 @Reusable)
      FlightTimelineNode({
        isTop: this.isTop,
        isBottom: this.isBottom,
        isCompleted: this.isCompleted
      })

      // 右侧：横版登机牌卡片 (支持 @Reusable)
      Column() {
        FlightBoardingPassCard({
          record: this.record,
          onCardClick: this.onCardClick
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 5.5, right: 20 })
    .alignItems(VerticalAlign.Top)
  }
}

/**
 * 航行日志骨架屏项 (带呼吸动画)
 * 用于在错峰渲染期间 (200ms) 填补视觉空白，提供丝滑的加载过渡
 */
@Component
struct FlightLogbookSkeletonItem {
  @Prop isTop: boolean = false;
  @Prop isBottom: boolean = false;

  build() {
    Row() {
      // 骨架：左侧时间轴 (仅保留上下实线，极简占位)
      Stack({ alignContent: Alignment.Top }) {
        // 隐形预加载节点：强制引擎在等待数据的 200ms 内提前解析并缓存 SVG
        Image($r('app.media.ic_plane_topview')).width(1).height(1).opacity(0.01).syncLoad(true)
        Image($r('app.media.ic_arrow_up')).width(1).height(1).opacity(0.01).syncLoad(true)

        // 顶端实线 (如果是首项，从16画到40；否则从0画到40)
        Row().width(2).height(this.isTop ? 24 : 40).backgroundColor('#374151').borderRadius(1)
          .position({ x: 15, y: this.isTop ? 16 : 0 })
          
        // 底端实线 (如果是底项，从64画到82；否则从64画到底部104)
        Row().width(2).height(this.isBottom ? 18 : 40).backgroundColor('#374151').borderRadius(1)
          .position({ x: 15, y: 64 })
      }
      .width(32)
      .height(104)
      .margin({ right: 8, left: 0 })

      // 骨架：右侧卡片主体
      Row()
        .layoutWeight(1)
        .height(104)
        .backgroundColor('rgba(255, 255, 255, 0.04)')
        .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 5.5, right: 20 })
    .alignItems(VerticalAlign.Top)
  }
}

/**
 * 航行日志 · 全新重构版 (Flight Logbook Timeline & Focus Heatmap)
 * 顶部 GitHub 风格航空热力图 + 垂直微光航空时间轴流水
 */
@Component
export struct FlightLogbookFullReport {
  onClose?: () => void;
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop initialYearTab: string = 'all';

  // 热力图状态
  @State private curYear: number = 2026;
  @State private curMonth: number = 8; // 1-12
  @State private selectedDay: number = 27; // 1-31
  @State private selectedDateStr: string = '2026-08-27';
  @State private heatmapPages: HeatmapWeekColumn[][] = [];
  @State private dailyFocusMap: Record<string, number> = {};
  private swiperController: SwiperController = new SwiperController();

  // 当日时间轴数据
  @State private dayRecords: FlightRecordItem[] = [];
  @State private dayTotalMinutes: number = 0;
  @State private dayTotalFlights: number = 0;
  @State private dayOnTimeRate: number = 100;
  @State private isLoading: boolean = true;

  
  // 日历弹窗
  @State private isDatePickerVisible: boolean = false;

  aboutToAppear(): void {
    const today = new Date();
    this.curYear = today.getFullYear();
    this.curMonth = today.getMonth() + 1;
    this.selectedDay = today.getDate();
    const mStr = this.curMonth.toString().padStart(2, '0');
    const dStr = this.selectedDay.toString().padStart(2, '0');
    this.selectedDateStr = `${this.curYear}-${mStr}-${dStr}`;
    this.initData();
  }

  private onVisibleChange(): void {
    if (this.isVisible) {
      this.initData();
    }
  }

  @State private dataVersion: number = 0;

  private async initData(): Promise<void> {
    this.isLoading = true;
    try {
      await FlightRecordRepository.seed2025MockDataIfEmpty();
      await this.refreshHeatmapData();
      await this.loadDayRecords();
    } catch (e) {
      // ignore
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 刷新当前自然年（按 4 个月精准分段：1-4月、5-8月、9-12月，确保各分段所有自然日完整呈现在对应页中）
   */
  private async refreshHeatmapData(): Promise<void> {
    const today = new Date();
    const todayYear = today.getFullYear();
    const todayMonth = today.getMonth() + 1;
    const todayDate = today.getDate();
    const todayStr = `${todayYear}-${todayMonth.toString().padStart(2, '0')}-${todayDate.toString().padStart(2, '0')}`;

    const targetYear = this.curYear || todayYear;

    const jan1 = new Date(targetYear, 0, 1, 0, 0, 0, 0);
    const dec31 = new Date(targetYear, 11, 31, 23, 59, 59, 999);

    // 获取数据库中全年的专注统计
    const statsMap = await FlightRecordRepository.getDailyFocusStatsMap(jan1.getTime(), dec31.getTime());
    this.dailyFocusMap = statsMap;

    // 3 个精准分段：[1-4月], [5-8月], [9-12月]
    const periods: HeatmapPeriod[] = [
      { startM: 1, endM: 4 },
      { startM: 5, endM: 8 },
      { startM: 9, endM: 12 }
    ];

    const pages: HeatmapWeekColumn[][] = [[], [], []];

    for (let p = 0; p < periods.length; p++) {
      const startMonth = periods[p].startM;
      const endMonth = periods[p].endM;

      // 分段首日（如 5月1日）对齐到周一
      const pStartDate = new Date(targetYear, startMonth - 1, 1, 0, 0, 0, 0);
      const pStartDay = pStartDate.getDay();
      const daysFromMonday = (pStartDay === 0 ? 6 : pStartDay - 1);
      const pStartMonday = new Date(pStartDate.getTime() - daysFromMonday * 86400000);
      pStartMonday.setHours(0, 0, 0, 0);

      // 分段末日（如 8月31日）对齐到周日
      const pEndDate = new Date(targetYear, endMonth, 0, 23, 59, 59, 999);
      const pEndDay = pEndDate.getDay();
      const daysToSunday = (pEndDay === 0 ? 0 : 7 - pEndDay);
      const pEndSunday = new Date(pEndDate.getTime() + daysToSunday * 86400000);
      pEndSunday.setHours(23, 59, 59, 999);

      const totalDays = Math.round((pEndSunday.getTime() - pStartMonday.getTime()) / 86400000);
      const totalWeeks = Math.ceil(totalDays / 7);

      let currentDayTime = pStartMonday.getTime();
      const pageCols: HeatmapWeekColumn[] = [];
      const labeledMonths = new Set<number>();

      for (let w = 0; w < totalWeeks; w++) {
        const colDays: HeatmapDayCell[] = [];
        let colLabel = '';

        for (let d = 0; d < 7; d++) {
          const dObj = new Date(currentDayTime);
          const y = dObj.getFullYear();
          const m = dObj.getMonth() + 1;
          const dt = dObj.getDate();
          const dateKey = `${y}-${m.toString().padStart(2, '0')}-${dt.toString().padStart(2, '0')}`;

          const isCurrentYearDay = (y === targetYear);
          const isCurrentPeriodMonth = (m >= startMonth && m <= endMonth);
          const isPadding = !isCurrentPeriodMonth;
          const minutes = (isCurrentYearDay && isCurrentPeriodMonth) ? (statsMap[dateKey] || 0) : 0;
          const level = (isCurrentYearDay && isCurrentPeriodMonth) ? this.getHeatmapLevel(minutes) : 0;
          const isTd = dateKey === todayStr;

          // 标注该分段内的月份标签 (在包含各月1号的周或分段首周打标)
          if (isCurrentPeriodMonth && !labeledMonths.has(m)) {
            if (dt === 1 || w === 0 || dt <= 7) {
              colLabel = `${m}月`;
              labeledMonths.add(m);
            }
          }

          colDays.push({
            dateStr: dateKey,
            year: y,
            month: m,
            day: dt,
            dayOfWeek: dObj.getDay(),
            minutes: minutes,
            level: level,
            isToday: isTd,
            isPaddingDay: isPadding
          });

          currentDayTime += 86400000;
        }

        pageCols.push({
          weekKey: `p${p}_w${w}`,
          cells: colDays,
          monthLabel: colLabel
        });
      }

      pages[p] = pageCols;
    }

    this.heatmapPages = pages;
    this.dataVersion++;

    setTimeout(() => {
      if (this.heatmapPages.length > 0) {
        const targetM = this.curMonth || (new Date().getMonth() + 1);
        let targetPage = 0;
        if (targetM >= 5 && targetM <= 8) {
          targetPage = 1;
        }
        if (targetM >= 9 && targetM <= 12) {
          targetPage = 2;
        }
        this.swiperController.changeIndex(targetPage, true);
      }
    }, 150);
  }

  private getHeatmapLevel(minutes: number): number {
    if (minutes <= 0) {
      return 0;
    }
    if (minutes <= 25) {
      return 1;
    }
    if (minutes <= 60) {
      return 2;
    }
    if (minutes <= 120) {
      return 3;
    }
    return 4;
  }

  /**
   * 加载当前选定日期的所有航行记录并计算当日统计
   */
  private async loadDayRecords(): Promise<void> {
    try {
      const paged = await FlightRecordRepository.getPagedFlightRecords({
        type: 'day',
        year: this.curYear,
        month: this.curMonth,
        day: this.selectedDay
      }, 1, 50);

      let minSum = 0;
      let completedCount = 0;
      for (let i = 0; i < paged.records.length; i++) {
        minSum += paged.records[i].actualDurationMin;
        if (paged.records[i].status === 'completed') {
          completedCount++;
        }
      }
      const newRate = paged.records.length > 0 ? Math.round((completedCount / paged.records.length) * 100) : 100;

      // 提前将数据更新到内存（此时真实列表尚未挂载，因此不会触发 ListItem 乱序插入动画）
      this.dayRecords = paged.records;
      this.dayTotalFlights = paged.records.length;
      this.dayTotalMinutes = minSum;
      this.dayOnTimeRate = newRate;

      // 瞬间切换状态，移除所有隐式动画以达到 Instant Swap
      this.isLoading = false;
    } catch (e) {
      // ignore
      this.isLoading = false;
    }
  }

  /**
   * 点击切换选中的热力图日期（支持跨段暗色格智能翻页联动）
   */
  private selectHeatmapCell(cell: HeatmapDayCell): void {
    if (!cell || !cell.dateStr) {
      return;
    }
    if (this.selectedDateStr === cell.dateStr) {
      return;
    }

    // 智能翻页联动：若点击的日期属于上一页或下一页，自动平滑翻页到对应分段
    let targetPage = 0;
    if (cell.month >= 5 && cell.month <= 8) {
      targetPage = 1;
    } else if (cell.month >= 9 && cell.month <= 12) {
      targetPage = 2;
    }
    this.swiperController.changeIndex(targetPage, true);
    
    // 1. 立即更新状态，触发高光框的平滑飞行滑动动画
    this.selectedDateStr = cell.dateStr;
    this.curYear = cell.year;
    this.curMonth = cell.month;
    this.selectedDay = cell.day;

    // 2. 极速响应优化：如果该日期明确没有数据 (level === 0)
    // 直接瞬间切到空状态，跳过骨架屏和 200ms 的错峰等待，带来“零延迟”的畅快体感
    if (cell.level === 0) {
      this.dayRecords = [];
      this.dayTotalFlights = 0;
      this.dayTotalMinutes = 0;
      this.dayOnTimeRate = 100;
      this.isLoading = false;
      return;
    }

    // 3. 有数据的日期：标记加载中，渲染极简骨架屏
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
      this.isLoading = true;
    });

    // 4. 核心性能优化：错峰渲染 (Perception Optimization)
    // 列表的 `FlightBoardingPassCard` 包含数百个 DOM 节点，如果跟随点击同步查询并重建，
    // 将会严重阻塞 UI 主线程，导致高光滑动动画掉帧、点击有“卡顿感”。
    // 延迟 200ms 执行加载，把主线程算力全部让给 250ms 的高光滑动动画，确保极致流畅！
    setTimeout(() => {
      this.loadDayRecords();
    }, 200);
  }

  /**
   * 快速回到今天
   */
  private goToToday(): void {
    const today = new Date();
    this.curYear = today.getFullYear();
    this.curMonth = today.getMonth() + 1;
    this.selectedDay = today.getDate();
    const mStr = this.curMonth.toString().padStart(2, '0');
    const dStr = this.selectedDay.toString().padStart(2, '0');
    this.selectedDateStr = `${this.curYear}-${mStr}-${dStr}`;

    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
      this.isLoading = true;
    });

    setTimeout(() => {
      if (this.heatmapPages.length > 0) {
        let targetPage = 0;
        if (this.curMonth >= 5 && this.curMonth <= 8) {
          targetPage = 1;
        }
        if (this.curMonth >= 9 && this.curMonth <= 12) {
          targetPage = 2;
        }
        this.swiperController.changeIndex(targetPage, true);
      }
    }, 100);

    setTimeout(() => {
      this.loadDayRecords();
    }, 200);
  }

  private getSelectedDateDisplay(): string {
    if (!this.selectedDateStr) {
      return '';
    }
    const parts = this.selectedDateStr.split('-');
    if (parts.length === 3) {
      const m = parseInt(parts[1], 10);
      const d = parseInt(parts[2], 10);
      return `${m}月${d}日`;
    }
    return `${this.curMonth}月${this.selectedDay}日`;
  }

  private getSelectedWeekdayDisplay(): string {
    if (!this.selectedDateStr) {
      return '';
    }
    const parts = this.selectedDateStr.split('-');
    if (parts.length === 3) {
      const y = parseInt(parts[0], 10);
      const m = parseInt(parts[1], 10) - 1;
      const d = parseInt(parts[2], 10);
      const date = new Date(y, m, d);
      const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      return days[date.getDay()];
    }
    return '';
  }

  private isSelectedDateToday(): boolean {
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    return this.selectedDateStr === todayStr;
  }

  private formatDayDuration(mins: number): string {
    if (!mins || mins <= 0) {
      return '0分钟';
    }
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    if (h > 0 && m > 0) {
      return `${h}小时 ${m}分钟`;
    } else if (h > 0) {
      return `${h}小时`;
    }
    return `${m}分钟`;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 1. 顶栏 (固定，不参与滚动，Stack 保证标题绝对居中)
        Stack({ alignContent: Alignment.Center }) {
          
          // 左侧返回按钮
          Row() {
            CloseButton({
              circleColor: 'rgba(255, 255, 255, 0.1)',
              iconColor: '#FFFFFF',
              buttonSize: 32,
              onClickAction: () => {
                if (this.onClose) {
                  this.onClose();
                }
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .hitTestBehavior(HitTestMode.Transparent) // 关键：允许点击穿透其透明部分，防止兄弟节点遮挡

          // 居中标题
          Text('航行日志')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          // 右侧日历回到今日按钮
          Row() {
            Row() {
              Image($r('app.media.ic_set_calendar'))
                .width(16)
                .height(16)
                .fillColor('#E0E7FF')
            }
            .width(32)
            .height(32)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .backgroundColor('rgba(255, 255, 255, 0.12)')
            .borderRadius(16)
            .border({ width: 1, color: 'rgba(255, 255, 255, 0.2)' })
            .onClick(() => {
              this.isDatePickerVisible = true;
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .hitTestBehavior(HitTestMode.Transparent) // 关键：防止此层遮挡左侧的关闭按钮
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 48, bottom: 12 })
        .backgroundColor('transparent')

        // 2. 航迹热力图 (独立轻量组件，支持横向分段轮播，不随下方时间轴上下滚动)
        FlightHeatmapView({
          curYear: this.curYear,
          dataVersion: this.dataVersion,
          selectedDateStr: this.selectedDateStr,
          heatmapPages: $heatmapPages,
          swiperController: this.swiperController,
          onSelectDate: (cell: HeatmapDayCell) => {
            this.selectHeatmapCell(cell);
          }
        })

        // 2.5 当日飞行概览栏 (日期 + 星期 + 今日徽章 + 当日飞行统计)
        Row() {
          // 左侧：日期与星期（含今日徽章）
          Row({ space: 8 }) {
            Text(this.getSelectedDateDisplay())
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')

            Text(this.getSelectedWeekdayDisplay())
              .fontSize(12)
              .fontColor('rgba(255, 255, 255, 0.45)')

            if (this.isSelectedDateToday()) {
              Text('今日')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#818CF8')
                .backgroundColor('rgba(99, 102, 241, 0.15)')
                .padding({ left: 6, right: 6, top: 1.5, bottom: 1.5 })
                .borderRadius(4)
                .border({ width: 0.5, color: 'rgba(99, 102, 241, 0.3)' })
            }
          }
          .alignItems(VerticalAlign.Center)

          Blank()

          // 右侧：当日起降次数与专注总时长
          Row({ space: 6 }) {
            if (this.dayTotalFlights > 0) {
              Row({ space: 3.5 }) {
                Image($r('app.media.ic_plane_topview'))
                  .width(12)
                  .height(12)
                  .fillColor('rgba(255, 255, 255, 0.45)')
                Text(`${this.dayTotalFlights}架次`)
                  .fontSize(11.5)
                  .fontColor('rgba(255, 255, 255, 0.65)')
              }

              Text('·')
                .fontSize(11.5)
                .fontColor('rgba(255, 255, 255, 0.25)')

              Text(this.formatDayDuration(this.dayTotalMinutes))
                .fontSize(11.5)
                .fontColor('rgba(255, 255, 255, 0.65)')
            } else {
              Text('暂无航程')
                .fontSize(11.5)
                .fontColor('rgba(255, 255, 255, 0.3)')
            }
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 6, bottom: 8 })

        // 3. 主内容区：Stack 分层独立列表 (彻底杜绝骨架和真实数据在一个流里互相挤压发生位移跳变)
        Stack({ alignContent: Alignment.Top }) {
          
          // 3.1 骨架屏专用列表 (绝对浮层在上方，安全卸载退场)
          if (this.isLoading) {
            List({ space: 14 }) {
              ForEach([0, 1, 2], (item: number, index: number) => {
                ListItem() {
                  FlightLogbookSkeletonItem({
                    isTop: index === 0,
                    isBottom: index === 2
                  })
                }
              }, (item: number) => item.toString())
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .zIndex(2)
          }

          // 3.2 真实数据与空状态专用列表 (退出时原地淡出，进入时滑入)
          if (!this.isLoading) {
            List({ space: 14 }) {
              
              // 3.2.1 空状态
              if (this.dayRecords.length === 0) {
                ListItem() {
                  Column({ space: 16 }) {
                    // 雷达图隐喻
                    Stack({ alignContent: Alignment.Center }) {
                      // 世界地图暗纹背景
                      Image($r('app.media.bg_real_world_silhouette'))
                        .width(240).height(160)
                        .opacity(0.12)
                        .objectFit(ImageFit.Contain)

                      // 虚线雷达扫描圈
                      Circle({ width: 120, height: 120 })
                        .fill('transparent')
                        .stroke('rgba(255, 255, 255, 0.08)')
                        .strokeWidth(1)
                        .strokeDashArray([4, 6])
                        
                      Circle({ width: 60, height: 60 })
                        .fill('transparent')
                        .stroke('rgba(255, 255, 255, 0.05)')
                        .strokeWidth(1)
                        .strokeDashArray([4, 6])

                      // 停机坪上黯淡的小飞机
                      Image($r('app.media.ic_plane_topview'))
                        .width(28).height(28)
                        .fillColor('rgba(255, 255, 255, 0.15)')
                    }
                    .width('100%')
                    .height(180)
                    .margin({ top: 32 })

                    Text('暂无航行记录，开启一段专注飞行吧')
                      .fontSize(13.5)
                      .fontColor('rgba(255, 255, 255, 0.45)')
                      .textAlign(TextAlign.Center)
                      .letterSpacing(0.5)
                      .margin({ top: 8 })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)
                  .padding({ bottom: 80 })
                }
              } 
              // 3.2.2 垂直时间轴真实节点流
              else {
                ForEach(this.dayRecords, (record: FlightRecordItem, idx: number) => {
                  ListItem() {
                    FlightLogbookListItemWrapper({
                      record: record,
                      isTop: idx === 0,
                      isBottom: idx === this.dayRecords.length - 1,
                      isCompleted: record.status === 'completed'
                    })
                  }
                  .transition({ type: TransitionType.Insert, opacity: 0, translate: { y: 20 } })
                }, (record: FlightRecordItem) => record.id)
              }

              // 列表底座间距
              ListItem() {
                Row().height(40)
              }
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .friction(0.65) // 舒适稳重的物理阻尼感，跟手顺滑且自然减速
            .cachedCount(4) // 预加载离屏列表项，消除滑动中途加载掉帧
            .zIndex(1)
          }

        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 0, right: 0, top: 4 })
        .backgroundColor('transparent')
      }
      .width('100%')
      .height('100%')
      .linearGradient({ angle: 180, colors: [['#262223', 0], ['#1A1718', 1]] })
      .renderGroup(this.isDatePickerVisible)


      // 6. 日历筛选弹窗
      if (this.isDatePickerVisible) {
        FlightDatePickerModal({
          isVisible: this.isDatePickerVisible,
          currentFilter: { type: 'day', year: this.curYear, month: this.curMonth, day: this.selectedDay },
          availableYears: [2026, 2025, 2024],
          onClose: () => {
            this.isDatePickerVisible = false;
          },
          onApplyFilter: async (filter: FlightRecordDateFilter) => {
            if (filter.type === 'day' && filter.year && filter.month && filter.day) {
              const yearChanged = this.curYear !== filter.year;
              this.curYear = filter.year;
              this.curMonth = filter.month;
              this.selectedDay = filter.day;
              const mStr = this.curMonth.toString().padStart(2, '0');
              const dStr = this.selectedDay.toString().padStart(2, '0');
              this.selectedDateStr = `${this.curYear}-${mStr}-${dStr}`;
              
              this.isLoading = true;
              
              if (yearChanged) {
                await this.refreshHeatmapData();
              }

              setTimeout(() => {
                if (this.heatmapPages.length > 0) {
                  let targetPage = 0;
                  if (this.curMonth >= 5 && this.curMonth <= 8) {
                    targetPage = 1;
                  }
                  if (this.curMonth >= 9 && this.curMonth <= 12) {
                    targetPage = 2;
                  }
                  this.swiperController.changeIndex(targetPage, true);
                }
              }, 100);

              setTimeout(() => {
                this.loadDayRecords();
              }, 200);
            }
          }
        })
        .zIndex(10)
      }
    }
    .width('100%')
    .height('100%')
  }
}
