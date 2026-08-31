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

interface MonthData {
  id: string;
  year: number;
  month: number;
  rows: number[][];
}

class MonthDataSource implements IDataSource {
  private dataArray: MonthData[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(data: MonthData[]) {
    this.dataArray = data;
  }

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): MonthData {
    return this.dataArray[index];
  }

  public registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  public unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  public reloadData(data: MonthData[]): void {
    this.dataArray = data;
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
  }
}

@Reusable
@Component
struct MonthItemView {
  @State monthItem: MonthData = { id: '', year: 0, month: 0, rows: [] };
  @Prop @Watch('onSelectedChange') selectedDateStr: string = '';
  onDateSelected?: (y: number, m: number, d: number) => void;

  // Canvas 渲染上下文：每个月份只需 1 个 Canvas 节点，替代原来 ~170 个 UI 节点
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(
    new RenderingContextSettings(true)
  );
  private isReady: boolean = false;
  // 防止 aboutToReuse 内部赋值触发 @Watch 重复绘制
  private isInReuse: boolean = false;

  aboutToReuse(params: Record<string, Object>) {
    this.isInReuse = true;
    this.monthItem = params.monthItem as MonthData;
    this.selectedDateStr = params.selectedDateStr as string;
    this.isInReuse = false;
    if (this.isReady) {
      this.redraw();
    }
  }

  // 响应父组件传入 selectedDateStr 变化（点击"今日"或选中其他日期）
  onSelectedChange(): void {
    if (!this.isInReuse && this.isReady) {
      this.redraw();
    }
  }

  private redraw(): void {
    const ctx = this.ctx;
    const W = ctx.width;
    if (W <= 0) {
      return;
    }

    const cellW = W / 7;
    const cellH = 48;
    ctx.clearRect(0, 0, W, 288);

    const rows = this.monthItem.rows;
    const selStr = this.selectedDateStr;
    const prefix = `${this.monthItem.year}-${this.monthItem.month}-`;

    // 提升至循环外：默认日期数字绘制状态（避免在 42 个循环中反复解析字体与重置对齐）
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = 'normal 400 16vp sans-serif';
    ctx.fillStyle = 'rgba(255,255,255,0.9)';

    for (let rIdx = 0; rIdx < rows.length; rIdx++) {
      const row = rows[rIdx];
      for (let cIdx = 0; cIdx < row.length; cIdx++) {
        const d = row[cIdx];
        if (d === 0) {
          continue;
        }

        const cx = (cIdx + 0.5) * cellW;
        const cy = rIdx * cellH + cellH / 2;
        const isSelected = selStr === prefix + d;

        if (isSelected) {
          // 选中态：先绘制白色实心圆背景
          ctx.fillStyle = '#FFFFFF';
          ctx.beginPath();
          ctx.arc(cx, cy, 17, 0, Math.PI * 2);
          ctx.fill();

          // 选中日期文字
          ctx.fillStyle = '#1A1718';
          ctx.font = 'normal 500 16vp sans-serif';
          ctx.fillText(d.toString(), cx, cy);

          // 还原常规绘制状态
          ctx.fillStyle = 'rgba(255,255,255,0.9)';
          ctx.font = 'normal 400 16vp sans-serif';
        } else {
          ctx.fillText(d.toString(), cx, cy);
        }
      }
    }
  }

  build() {
    Column() {
      // 月份标题
      Text(this.monthItem.year + '年' + this.monthItem.month + '月')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .height(24) // 固化文字高度
        .margin({ top: 24, bottom: 24 }) // 总计占用 24+24+24 = 72vp

      // 单个 Canvas 绘制整个 6×7 日期网格
      Canvas(this.ctx)
        .width('100%')
        .height(288) // 6行 × 48vp
        .backgroundColor('transparent')
        .onReady(() => {
          this.isReady = true;
          this.redraw();
        })
        .onClick((event: ClickEvent) => {
          const cellW = this.ctx.width / 7;
          const col = Math.floor(event.x / cellW);
          const row = Math.floor(event.y / 48);
          if (row >= 0 && row < 6 && col >= 0 && col < 7) {
            const rowData = this.monthItem.rows[row];
            if (rowData && col < rowData.length) {
              const d = rowData[col];
              if (d !== 0 && this.onDateSelected) {
                this.onDateSelected(this.monthItem.year, this.monthItem.month, d);
              }
            }
          }
        })
    }
    .width('100%')
    .height(360) // 精准固化高度，令 List 启动 O(1) 的超高速虚拟布局，彻底消除滑动 Layout 重新测量开销
    .padding({ left: 16, right: 16 })
  }
}

@Component
export struct FlightCalendarView {
  @Link curYear: number;
  @Link curMonth: number;
  @Link selectedDay: number;
  onDateSelected?: () => void;

  private monthsDataSource: MonthDataSource = new MonthDataSource([]);
  private scroller: Scroller = new Scroller();

  @State targetIndex: number = -1;

  aboutToAppear(): void {
    this.generateMonths();
  }

  private generateMonths(): void {
    const list: MonthData[] = [];
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth() + 1;

    const startYear = currentYear - 3;

    for (let y = startYear; y <= currentYear; y++) {
      for (let m = 1; m <= 12; m++) {
        if (y === currentYear && m > currentMonth) {
          break;
        }

        const firstDay = new Date(y, m - 1, 1).getDay();
        const daysInMonth = new Date(y, m, 0).getDate();

        let currentRow: number[] = [];
        const rows: number[][] = [];

        for (let i = 0; i < firstDay; i++) {
          currentRow.push(0);
        }

        for (let d = 1; d <= daysInMonth; d++) {
          currentRow.push(d);
          if (currentRow.length === 7) {
            rows.push(currentRow);
            currentRow = [];
          }
        }

        if (currentRow.length > 0) {
          while (currentRow.length < 7) {
            currentRow.push(0);
          }
          rows.push(currentRow);
        }

        while (rows.length < 6) {
          rows.push([0, 0, 0, 0, 0, 0, 0]);
        }

        list.push({
          id: y + '-' + m,
          year: y,
          month: m,
          rows: rows
        });
      }
    }

    const idx = list.findIndex(m => m.year === this.curYear && m.month === this.curMonth);
    if (idx >= 0) {
      this.targetIndex = idx;
    }
    this.monthsDataSource.reloadData(list);
  }

  private scrollToSelectedMonth(): void {
    if (this.targetIndex >= 0) {
      this.scroller.scrollToIndex(this.targetIndex, false, ScrollAlign.CENTER);
    }
  }

  build() {
    Column() {
      // 固定的星期栏
      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (wk: string) => {
          Text(wk)
            .fontSize(15)
            .fontWeight(FontWeight.Regular)
            .fontColor('rgba(255, 255, 255, 0.4)')
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        }, (wk: string) => wk)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 12 })

      // 垂直滚动的月份列表
      List({ scroller: this.scroller, initialIndex: this.targetIndex >= 0 ? this.targetIndex : 0 }) {
        LazyForEach(this.monthsDataSource, (monthItem: MonthData) => {
          ListItem() {
            MonthItemView({
              monthItem: monthItem,
              selectedDateStr: `${this.curYear}-${this.curMonth}-${this.selectedDay}`,
              onDateSelected: (y: number, m: number, d: number) => {
                this.curYear = y;
                this.curMonth = m;
                this.selectedDay = d;
                if (this.onDateSelected) {
                  this.onDateSelected();
                }
              }
            })
          }
        }, (item: MonthData) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .friction(0.65)
      .cachedCount(4)
    }
    .width('100%')
    .height('100%')
  }
}
