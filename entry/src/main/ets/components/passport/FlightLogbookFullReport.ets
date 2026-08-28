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
import { FlightRecordDetailModal } from './FlightRecordDetailModal';
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
  @Prop @Watch('onSelectionChanged') pageData: HeatmapWeekColumn[] = [];
  @Prop @Watch('onSelectionChanged') selectedDateStr: string = '';
  @Prop todayStr: string = '';
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
  @State pressedCellInfo: HeatmapCellPositionInfo | null = null;

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
        ctx.fillStyle = HeatmapCanvasPage.COLORS[Math.min(cell_obj.level, 4)];
        ctx.beginPath();
        ctx.roundRect(colX, cellY, cell, cell, 3);
        ctx.fill();

        if (cell_obj.isToday) {
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
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              const touch = event.touches[0];
              this.pressedCellInfo = this.hitTestCellInfo(touch.x, touch.y);
            } else if (event.type === TouchType.Up) {
              if (this.pressedCellInfo && this.onSelectDate) {
                this.onSelectDate(this.pressedCellInfo.cell);
              }
              this.pressedCellInfo = null;
            } else if (event.type === TouchType.Cancel) {
              this.pressedCellInfo = null;
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

        // 3. 动画层：手指按下反馈层
        if (this.pressedCellInfo) {
          Row()
            .width(HeatmapCanvasPage.CELL)
            .height(HeatmapCanvasPage.CELL)
            .backgroundColor('#000000')
            .opacity(0.3)
            .borderRadius(3)
            .position({ x: this.pressedCellInfo.x, y: this.pressedCellInfo.y })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
      .height(118)
      .clip(false)

      // 月份刻度行
      Row() {
        ForEach(this.pageData, (week: HeatmapWeekColumn) => {
          Row() {
            Text(week.monthLabel || '')
              .fontSize(9.5)
              .fontColor(week.monthLabel ? 'rgba(255, 255, 255, 0.4)' : 'transparent')
              .maxLines(1)
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

          Text('多')
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
        }, (page: HeatmapWeekColumn[], idx: number) => idx.toString())
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

  // 详情弹窗
  @State private selectedRecord: FlightRecordItem | undefined = undefined;
  @State private isDetailModalVisible: boolean = false;
  
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
   * 刷新当前自然年（1月1日 - 12月31日，包括整年所有天数与未来月份）的全年热力图数据矩阵
   */
  private async refreshHeatmapData(): Promise<void> {
    const today = new Date();
    const todayYear = today.getFullYear();
    const todayMonth = today.getMonth() + 1;
    const todayDate = today.getDate();
    const todayStr = `${todayYear}-${todayMonth.toString().padStart(2, '0')}-${todayDate.toString().padStart(2, '0')}`;

    const targetYear = this.curYear || todayYear;

    // 1. 当年 1 月 1 日对齐到周一
    const jan1 = new Date(targetYear, 0, 1, 0, 0, 0, 0);
    const jan1Day = jan1.getDay();
    const daysFromMonday = (jan1Day === 0 ? 6 : jan1Day - 1);
    const startMonday = new Date(jan1.getTime() - daysFromMonday * 86400000);
    startMonday.setHours(0, 0, 0, 0);

    // 2. 当年 12 月 31 日对齐到周日
    const dec31 = new Date(targetYear, 11, 31, 23, 59, 59, 999);
    const dec31Day = dec31.getDay();
    const daysToSunday = (dec31Day === 0 ? 0 : 7 - dec31Day);
    const endSunday = new Date(dec31.getTime() + daysToSunday * 86400000);
    endSunday.setHours(23, 59, 59, 999);

    // 计算总周数 (通常为 52 或 53 周)
    const totalDays = Math.round((endSunday.getTime() - startMonday.getTime()) / 86400000);
    const totalWeeks = Math.ceil(totalDays / 7);

    // 获取数据库中全年的专注统计
    const statsMap = await FlightRecordRepository.getDailyFocusStatsMap(jan1.getTime(), dec31.getTime());
    this.dailyFocusMap = statsMap;

    const weeks: HeatmapDayCell[][] = [];
    let currentDayTime = startMonday.getTime();

    for (let w = 0; w < totalWeeks; w++) {
      const colDays: HeatmapDayCell[] = [];
      for (let d = 0; d < 7; d++) {
        const dObj = new Date(currentDayTime);
        const y = dObj.getFullYear();
        const m = dObj.getMonth() + 1;
        const dt = dObj.getDate();
        const dateKey = `${y}-${m.toString().padStart(2, '0')}-${dt.toString().padStart(2, '0')}`;

        const isCurrentYearDay = (y === targetYear);
        const minutes = isCurrentYearDay ? (statsMap[dateKey] || 0) : 0;
        const level = isCurrentYearDay ? this.getHeatmapLevel(minutes) : 0;
        const isTd = dateKey === todayStr;

        colDays.push({
          dateStr: dateKey,
          year: y,
          month: m,
          day: dt,
          dayOfWeek: dObj.getDay(),
          minutes: minutes,
          level: level,
          isToday: isTd
        });

        currentDayTime += 86400000;
      }
      weeks.push(colDays);
    }

    // 精确按 4 个月分页 (1-4月, 5-8月, 9-12月)
    const rawPages: HeatmapDayCell[][][] = [[], [], []];
    for (let w = 0; w < weeks.length; w++) {
      let week = weeks[w];
      if (!week || week.length === 0) {
        continue;
      }

      let m = week[3]?.month || 1; // 默认防空

      // 修正跨年首尾周的归属问题
      if (w === 0 && m === 12) {
        m = 1;
      }
      if (w === weeks.length - 1 && m === 1) {
        m = 12;
      }

      if (m >= 1 && m <= 4) {
        rawPages[0].push(week);
      } else if (m >= 5 && m <= 8) {
        rawPages[1].push(week);
      } else {
        rawPages[2].push(week);
      }
    }

    // 补齐各页长度，并精确预计算每一周的 monthLabel (O(1) 读取)
    const maxLen = Math.max(rawPages[0].length, rawPages[1].length, rawPages[2].length);
    const pages: HeatmapWeekColumn[][] = [[], [], []];

    let lastMonth = -1;
    for (let p = 0; p < 3; p++) {
      const pageList: HeatmapWeekColumn[] = [];
      for (let i = 0; i < maxLen; i++) {
        const weekCells = rawPages[p][i] || [];
        let label = '';
        if (weekCells.length > 0) {
          const curM = weekCells[3]?.month;
          if (curM !== undefined && curM !== lastMonth) {
            label = `${curM}月`;
            lastMonth = curM;
          }
        }
        pageList.push({
          weekKey: `p${p}_w${i}`,
          cells: weekCells,
          monthLabel: label
        });
      }
      pages[p] = pageList;
    }
    this.heatmapPages = pages;

    setTimeout(() => {
      if (this.heatmapPages.length > 0) {
        const todayMonth = new Date().getMonth() + 1;
        let targetPage = 0;
        if (todayMonth >= 5 && todayMonth <= 8) {
          targetPage = 1;
        }
        if (todayMonth >= 9 && todayMonth <= 12) {
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
   * 点击切换选中的热力图日期
   */
  private selectHeatmapCell(cell: HeatmapDayCell): void {
    if (!cell || !cell.dateStr) {
      return;
    }
    if (this.selectedDateStr === cell.dateStr) {
      return;
    }
    
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
    this.isLoading = true;

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

    this.isLoading = true;

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
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 48, bottom: 12 })
        .backgroundColor('transparent')

        // 2. 航迹热力图 (独立轻量组件，支持横向分段轮播，不随下方时间轴上下滚动)
        FlightHeatmapView({
          curYear: this.curYear,
          selectedDateStr: this.selectedDateStr,
          heatmapPages: $heatmapPages,
          swiperController: this.swiperController,
          onSelectDate: (cell: HeatmapDayCell) => {
            this.selectHeatmapCell(cell);
          }
        })

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

                    Text('塔台暂未收到起飞申请')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('rgba(255, 255, 255, 0.7)')
                      .letterSpacing(1)

                    Text('雷达屏幕空空如也\n前往机舱设定目的地，开启一段全新专注之旅吧')
                      .fontSize(12)
                      .fontColor('rgba(255, 255, 255, 0.35)')
                      .textAlign(TextAlign.Center)
                      .lineHeight(20)
                      .padding({ left: 40, right: 40 })
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
                      isCompleted: record.status === 'completed',
                      onCardClick: (rec: FlightRecordItem) => {
                        this.selectedRecord = rec;
                        this.isDetailModalVisible = true;
                      }
                    })
                  }
                  // [核心修复]：覆盖 ArkUI 默认的 ListItem 插入滑动动画。
                  // 设置 opacity: 1 意味着插入时没有任何视觉位移，只跟随外层 List 的 transition。
                  // 这彻底解决了“圆点从顶部一下子滑到底部”的灵异现象！
                  .transition({ type: TransitionType.All, opacity: 1 })
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
      // 日历/详情弹窗打开时，将底层内容从渲染树摘除，避免每帧 overdraw 181 个节点导致的卡顿
      .visibility(this.isDatePickerVisible || this.isDetailModalVisible ? Visibility.Hidden : Visibility.Visible)


      // 5. 单次航班复盘登机牌弹窗
      if (this.isDetailModalVisible && this.selectedRecord) {
        FlightRecordDetailModal({
          isVisible: this.isDetailModalVisible,
          record: this.selectedRecord,
          onClose: () => {
            this.isDetailModalVisible = false;
          }
        })
      }

      // 6. 日历筛选弹窗
      if (this.isDatePickerVisible) {
        Stack() {
          // 蒙版
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.4)')
            .onClick(() => {
              this.isDatePickerVisible = false;
            })
            
          FlightDatePickerModal({
            isVisible: this.isDatePickerVisible,
            currentFilter: { type: 'day', year: this.curYear, month: this.curMonth, day: this.selectedDay },
            availableYears: [2026, 2025, 2024],
            onClose: () => {
              this.isDatePickerVisible = false;
            },
            onApplyFilter: (filter: FlightRecordDateFilter) => {
              this.isDatePickerVisible = false;
              if (filter.type === 'day' && filter.year && filter.month && filter.day) {
                this.curYear = filter.year;
                this.curMonth = filter.month;
                this.selectedDay = filter.day;
                const mStr = this.curMonth.toString().padStart(2, '0');
                const dStr = this.selectedDay.toString().padStart(2, '0');
                this.selectedDateStr = `${this.curYear}-${mStr}-${dStr}`;
                
                this.isLoading = true;
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
        }
        .width('100%')
        .height('100%')
        .zIndex(10)
      }
    }
    .width('100%')
    .height('100%')
  }
}
