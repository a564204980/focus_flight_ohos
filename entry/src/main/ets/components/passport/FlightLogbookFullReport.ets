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
  FlightRecordItem,
  FlightRecordRepository
} from '../../database/FlightRecordRepository';
import { FlightRecordDetailModal } from './FlightRecordDetailModal';
import { FlightBoardingPassCard } from './FlightBoardingPassCard';

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

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(
    new RenderingContextSettings(true)
  );

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

  /**
   * selectedDateStr / pageData 变化时触发 Canvas 重绘
   * Canvas 不参与 ArkTS 响应式树，必须通过 @Watch 手动触发
   */
  onSelectionChanged(): void {
    this.drawPage();
  }

  aboutToAppear(): void {
    // 数据就绪后由 onReady 触发绘制
  }

  /**
   * 全量绘制整页热力图矩阵
   * 时间复杂度 O(N) Canvas draw calls，远快于 1092 个节点的 layout/measure
   */
  drawPage(): void {
    const ctx = this.ctx;
    if (!ctx || !this.pageData || this.pageData.length === 0) {
      return;
    }

    const cell = HeatmapCanvasPage.CELL;
    const rowH = HeatmapCanvasPage.ROW_H;
    const canvasW = this.ctx.width;
    const padX = 3; // 左右预留发光溢出空间
    const padY = 3; // 上下预留发光溢出空间

    // Canvas 负责 118vp 高度的区域
    ctx.clearRect(0, 0, canvasW, 118);

    const colCount = this.pageData.length;
    if (colCount === 0) {
      return;
    }

    // 列间距（扣除左右 padding 后计算）
    const colSpacing = colCount > 1 ? (canvasW - cell - padX * 2) / (colCount - 1) : 0;
    
    // 延迟绘制选中态（两遍渲染，确保选中效果始终在最顶层 Z-Order）
    let selectedColX: number = 0;
    let selectedCellY: number = 0;
    let selectedCellObj: HeatmapDayCell | null = null;

    for (let wi = 0; wi < colCount; wi++) {
      const week = this.pageData[wi];
      if (!week || !week.cells) {
        continue;
      }
      const colX = padX + wi * colSpacing;

      for (let di = 0; di < week.cells.length; di++) {
        const cell_obj = week.cells[di];
        const cellY = padY + di * rowH;
        const isSelected = this.selectedDateStr === cell_obj.dateStr;
        const isToday = cell_obj.isToday;

        if (isSelected) {
          // 保存下来，第一遍先不画
          selectedColX = colX;
          selectedCellY = cellY;
          selectedCellObj = cell_obj;
          continue;
        }

        // 第一遍：绘制所有非选中的格子
        ctx.fillStyle = HeatmapCanvasPage.COLORS[Math.min(cell_obj.level, 4)];
        ctx.beginPath();
        ctx.roundRect(colX, cellY, cell, cell, 3);
        ctx.fill();

        if (isToday) {
          ctx.strokeStyle = '#818CF8';
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.roundRect(colX, cellY, cell, cell, 3);
          ctx.stroke();
        }
      }
    }

    // 第二遍：专门在最顶层绘制选中的格子，绝不被右侧和下方的格子覆盖
    if (selectedCellObj) {
      const colX = selectedColX;
      const cellY = selectedCellY;
      const cell_obj = selectedCellObj;
      
      const scale = 1.22;
      const sc = cell * scale;
      const ox = colX - (sc - cell) / 2;
      const oy = cellY - (sc - cell) / 2;

      ctx.save();
      // 使用真实的 Canvas 阴影替代之前生硬的底块，恢复“发光”效果
      ctx.shadowColor = 'rgba(99, 102, 241, 0.45)';
      ctx.shadowBlur = 6;
      ctx.shadowOffsetX = 0;
      ctx.shadowOffsetY = 2;

      ctx.fillStyle = HeatmapCanvasPage.COLORS[Math.min(cell_obj.level, 4)];
      ctx.beginPath();
      ctx.roundRect(ox, oy, sc, sc, 3);
      ctx.fill();
      ctx.restore();

      // 白色描边（无阴影）
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.roundRect(ox, oy, sc, sc, 3);
      ctx.stroke();
    }
  }

  /**
   * 通过触点坐标反算命中的热力格
   */
  private hitTestCell(touchX: number, touchY: number): HeatmapDayCell | undefined {
    if (!this.pageData || this.pageData.length === 0) {
      return undefined;
    }

    const cell = HeatmapCanvasPage.CELL;
    const rowH = HeatmapCanvasPage.ROW_H;
    const canvasW = this.ctx.width;
    const padX = 3;
    const padY = 3;
    
    const colCount = this.pageData.length;
    const colSpacing = colCount > 1 ? (canvasW - cell - padX * 2) / (colCount - 1) : 0;

    if (touchY < 0 || touchY > 118) {
      return undefined;
    }
    
    // 扣除 padding
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
    if (bestCol < 0 || bestDist > cell) {
      return undefined;
    }

    const dayIdx = Math.floor(adjY / rowH);
    const week = this.pageData[bestCol];
    if (!week || !week.cells || dayIdx >= week.cells.length) {
      return undefined;
    }
    return week.cells[dayIdx];
  }

  build() {
    Column({ space: 0 }) {
      // 格子区域 Canvas（高度 118vp，四周各预留 3vp 缓冲避免光晕被切）
      Canvas(this.ctx)
        .width('100%')
        .height(118)
        .backgroundColor(Color.Transparent)
        .onReady(() => {
          this.drawPage();
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Up) {
            const touch = event.changedTouches[0];
            const cell = this.hitTestCell(touch.x, touch.y);
            if (cell && this.onSelectDate) {
              this.onSelectDate(cell);
            }
          }
        })

      // 月份刻度行
      Row() {
        ForEach(this.pageData, (week: HeatmapWeekColumn) => {
          Text(week.monthLabel || '')
            .fontSize(9.5)
            .fontColor(week.monthLabel ? 'rgba(255, 255, 255, 0.4)' : 'transparent')
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
        }, (week: HeatmapWeekColumn) => week.weekKey + '_lbl')
      }
      .width('100%')
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
@Reusable
@Component
struct FlightTimelineNode {
  @Prop isTop: boolean = false;
  @Prop isBottom: boolean = false;
  @Prop isCompleted: boolean = false;

  aboutToReuse(params: Record<string, Object>): void {
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
    Column() {
      // 1. 顶部降落导向箭头（visibility 控制，节点树结构恒定）
      Image($r('app.media.ic_arrow_up'))
        .width(15)
        .height(15)
        .fillColor('rgba(255, 255, 255, 0.35)')
        .visibility(this.isTop ? Visibility.Visible : Visibility.None)

      // 2. 顶端浅色过渡线 / 非顶端承接实线（始终存在，仅切换样式）
      Row()
        .width(this.isTop ? 1.5 : 3)
        .height(this.isTop ? 6 : 16)
        .backgroundColor(this.isTop ? 'rgba(255, 255, 255, 0.18)' : '#4B5563')
        .borderRadius(this.isTop ? 0 : 1.5)

      // 3. 巡航小飞机
      Image($r('app.media.ic_plane_topview'))
        .width(15)
        .height(15)
        .fillColor(this.isCompleted ? 'rgba(255, 255, 255, 0.85)' : '#F59E0B')

      // 4. 粗导轨实线（上段）
      Row()
        .width(3)
        .height(12)
        .backgroundColor('#4B5563')
        .borderRadius(1.5)

      // 5. 登机小圆点
      Circle({ width: 6, height: 6 })
        .fill('#4B5563')

      // 6. 粗导轨实线（下段）
      Row()
        .width(3)
        .height(12)
        .backgroundColor('#4B5563')
        .borderRadius(1.5)

      // 7. 底部同心圆徽章（始终存在，visibility 控制显隐）
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 16, height: 16 })
          .fill(this.isCompleted ? '#ECFDF5' : 'rgba(245, 158, 11, 0.15)')
          .stroke(this.isCompleted ? '#10B981' : '#F59E0B')
          .strokeWidth(2)
        Circle({ width: 6, height: 6 })
          .fill(this.isCompleted ? '#10B981' : '#F59E0B')
      }
      .visibility(this.isBottom ? Visibility.Visible : Visibility.None)

      // 8. 向下延伸贯通实线（始终存在，visibility 控制）
      Row()
        .width(3)
        .height(16)
        .backgroundColor('#4B5563')
        .borderRadius(1.5)
        .visibility(this.isBottom ? Visibility.None : Visibility.Visible)
    }
    .width(32)
    .height(104)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ right: 8, left: 4 })
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
    .padding({ left: 16, right: 16 })
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

      this.dayRecords = paged.records;
      this.dayTotalFlights = paged.records.length;

      let minSum = 0;
      let completedCount = 0;
      for (let i = 0; i < paged.records.length; i++) {
        minSum += paged.records[i].actualDurationMin;
        if (paged.records[i].status === 'completed') {
          completedCount++;
        }
      }
      this.dayTotalMinutes = minSum;
      this.dayOnTimeRate = paged.records.length > 0 ? Math.round((completedCount / paged.records.length) * 100) : 100;
    } catch (e) {
      // ignore
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 点击切换选中的热力图日期
   */
  private async selectHeatmapCell(cell: HeatmapDayCell): Promise<void> {
    if (!cell || !cell.dateStr) {
      return;
    }
    if (this.selectedDateStr === cell.dateStr) {
      return;
    }
    this.selectedDateStr = cell.dateStr;
    this.curYear = cell.year;
    this.curMonth = cell.month;
    this.selectedDay = cell.day;

    await this.loadDayRecords();
  }

  /**
   * 快速回到今天
   */
  private async goToToday(): Promise<void> {
    const today = new Date();
    this.curYear = today.getFullYear();
    this.curMonth = today.getMonth() + 1;
    this.selectedDay = today.getDate();
    const mStr = this.curMonth.toString().padStart(2, '0');
    const dStr = this.selectedDay.toString().padStart(2, '0');
    this.selectedDateStr = `${this.curYear}-${mStr}-${dStr}`;

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
    await this.loadDayRecords();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 1. 顶栏 (固定，不参与滚动)
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

          Text('航行日志')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Row() {
            Text('今日')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#E0E7FF')
          }
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('rgba(255, 255, 255, 0.12)')
          .borderRadius(12)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.2)' })
          .onClick(() => {
            this.goToToday();
          })
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

        // 3. 主内容区：独立纵向 List (仅时间轴滚动，滑动性能与响应极致纯粹)
        List({ space: 14 }) {

          // 2.2 无记录空状态
          if (!this.isLoading && this.dayRecords.length === 0) {
            ListItem() {
              Column({ space: 14 }) {
                Text('🛫')
                  .fontSize(44)
                  .margin({ top: 48 })

                Text('今日航班待起飞')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')

                Text('该日暂无专注飞行记录，前往机舱选择目的地开启新航程吧')
                  .fontSize(12)
                  .fontColor('rgba(255, 255, 255, 0.5)')
                  .textAlign(TextAlign.Center)
                  .padding({ left: 32, right: 32 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .padding({ bottom: 80 })
            }
          }

          // 4.2 垂直时间轴节点流 (@Reusable 复用池加速)
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
          }, (record: FlightRecordItem) => record.id)

          // 列表底座间距
          ListItem() {
            Row().height(40)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 0, right: 0, top: 4 })
        .backgroundColor('transparent')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .friction(0.65) // 舒适稳重的物理阻尼感，跟手顺滑且自然减速
        .cachedCount(4)  // 预加载离屏列表项，消除滑动中途加载掉帧
      }
      .width('100%')
      .height('100%')
      .linearGradient({ angle: 180, colors: [['#262223', 0], ['#1A1718', 1]] })

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
    }
    .width('100%')
    .height('100%')
  }
}
