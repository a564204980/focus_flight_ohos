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
import { FlightRecordDateFilter } from '../../database/FlightRecordRepository';

export interface CalendarDayCell {
  dayNumber: number;
  isCurrentMonth: boolean;
  isToday: boolean;
  isSelected: boolean;
  dateKey: string;
}

/**
 * 航行日志 · 年月日灵活时间检索与日历筛选弹窗
 * (Flight Date Picker Modal)
 */
@Component
export struct FlightDatePickerModal {
  @Prop @Watch('onVisibleChange') isVisible: boolean = false;
  @Prop currentFilter: FlightRecordDateFilter = { type: 'all' };
  @Prop availableYears: Array<number> = [2026, 2025];
  onApplyFilter?: (filter: FlightRecordDateFilter) => void;
  onClose?: () => void;

  @State private activeTab: 'day' | 'month' | 'year' = 'day';
  @State private curYear: number = 2026;
  @State private curMonth: number = 8; // 1-12
  @State private selectedDay: number = 26; // 1-31
  @State private selectedMonthOnly: number = 8;
  @State private selectedYearOnly: number = 2026;
  @State private modalOffsetY: number = 600;

  aboutToAppear(): void {
    this.initFromFilter();
    if (this.isVisible) {
      this.modalOffsetY = 0;
    }
  }

  private onVisibleChange(): void {
    if (this.isVisible) {
      this.initFromFilter();
      this.getUIContext().animateTo({ duration: 320, curve: Curve.FastOutSlowIn }, () => {
        this.modalOffsetY = 0;
      });
    } else {
      this.modalOffsetY = 600;
    }
  }

  private initFromFilter(): void {
    const today = new Date();
    this.curYear = this.currentFilter.year || today.getFullYear();
    this.curMonth = this.currentFilter.month || (today.getMonth() + 1);
    this.selectedDay = this.currentFilter.day || today.getDate();
    this.selectedMonthOnly = this.currentFilter.month || (today.getMonth() + 1);
    this.selectedYearOnly = this.currentFilter.year || today.getFullYear();

    if (this.currentFilter.type === 'month') {
      this.activeTab = 'month';
    } else if (this.currentFilter.type === 'year') {
      this.activeTab = 'year';
    } else {
      this.activeTab = 'day';
    }
  }

  private prevMonth(): void {
    if (this.curMonth === 1) {
      this.curYear--;
      this.curMonth = 12;
    } else {
      this.curMonth--;
    }
  }

  private nextMonth(): void {
    if (this.curMonth === 12) {
      this.curYear++;
      this.curMonth = 1;
    } else {
      this.curMonth++;
    }
  }

  private getCalendarDays(): CalendarDayCell[] {
    const cells: CalendarDayCell[] = [];
    const firstDayOfWeek = new Date(this.curYear, this.curMonth - 1, 1).getDay();
    const daysInMonth = new Date(this.curYear, this.curMonth, 0).getDate();
    const daysInPrevMonth = new Date(this.curYear, this.curMonth - 1, 0).getDate();

    const today = new Date();
    const isThisYear = today.getFullYear() === this.curYear;
    const isThisMonth = (today.getMonth() + 1) === this.curMonth;
    const todayDate = today.getDate();

    // 填充上月末尾占位
    for (let i = firstDayOfWeek - 1; i >= 0; i--) {
      const dayNum = daysInPrevMonth - i;
      cells.push({
        dayNumber: dayNum,
        isCurrentMonth: false,
        isToday: false,
        isSelected: false,
        dateKey: `prev_${dayNum}`
      });
    }

    // 填充当月天数
    for (let d = 1; d <= daysInMonth; d++) {
      const isToday = isThisYear && isThisMonth && (d === todayDate);
      const isSelected = (this.selectedDay === d);
      cells.push({
        dayNumber: d,
        isCurrentMonth: true,
        isToday: isToday,
        isSelected: isSelected,
        dateKey: `cur_${d}`
      });
    }

    // 填充下月开头占位至 35 或 42 格
    const remaining = 42 - cells.length;
    for (let n = 1; n <= remaining; n++) {
      cells.push({
        dayNumber: n,
        isCurrentMonth: false,
        isToday: false,
        isSelected: false,
        dateKey: `next_${n}`
      });
    }

    return cells;
  }

  private handleClose(): void {
    this.getUIContext().animateTo({ duration: 260, curve: Curve.EaseInOut }, () => {
      this.modalOffsetY = 600;
    });
    setTimeout(() => {
      if (this.onClose) {
        this.onClose();
      }
    }, 280);
  }

  private applyAll(): void {
    if (this.onApplyFilter) {
      this.onApplyFilter({ type: 'all' });
    }
    this.handleClose();
  }

  private applyCurrentSelection(): void {
    let result: FlightRecordDateFilter;
    if (this.activeTab === 'day') {
      result = {
        type: 'day',
        year: this.curYear,
        month: this.curMonth,
        day: this.selectedDay
      };
    } else if (this.activeTab === 'month') {
      result = {
        type: 'month',
        year: this.selectedYearOnly,
        month: this.selectedMonthOnly
      };
    } else {
      result = {
        type: 'year',
        year: this.selectedYearOnly
      };
    }

    if (this.onApplyFilter) {
      this.onApplyFilter(result);
    }
    this.handleClose();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 半透明暗色背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(10, 8, 28, 0.75)')
        .onClick(() => {
          this.handleClose();
        })

      // 2. 弹窗面板主体 (深色夜空微光质感)
      Column({ space: 16 }) {
        // 顶部小抓手
        Row()
          .width(36)
          .height(4)
          .backgroundColor('rgba(255, 255, 255, 0.2)')
          .borderRadius(2)
          .margin({ top: 12, bottom: 4 })

        // 弹窗头部
        Row() {
          Text('筛选航行日期')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Blank()

          CloseButton({
            circleColor: 'rgba(255, 255, 255, 0.1)',
            iconColor: '#FFFFFF',
            buttonSize: 30,
            onClickAction: () => {
              this.handleClose();
            }
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        // 维度切换 Tab 胶囊 [ 按天 (日历) | 按月 | 按年 ]
        Row() {
          Row() {
            Text('按日检索')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.activeTab === 'day' ? '#FFFFFF' : 'rgba(255, 255, 255, 0.5)')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.activeTab === 'day' ? 'rgba(99, 102, 241, 0.35)' : 'transparent')
              .borderRadius(12)
              .onClick(() => {
                this.activeTab = 'day';
              })

            Text('按月检索')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.activeTab === 'month' ? '#FFFFFF' : 'rgba(255, 255, 255, 0.5)')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.activeTab === 'month' ? 'rgba(99, 102, 241, 0.35)' : 'transparent')
              .borderRadius(12)
              .onClick(() => {
                this.activeTab = 'month';
              })

            Text('按年检索')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.activeTab === 'year' ? '#FFFFFF' : 'rgba(255, 255, 255, 0.5)')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(this.activeTab === 'year' ? 'rgba(99, 102, 241, 0.35)' : 'transparent')
              .borderRadius(12)
              .onClick(() => {
                this.activeTab = 'year';
              })
          }
          .backgroundColor('rgba(255, 255, 255, 0.08)')
          .padding(4)
          .borderRadius(16)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        // 3. 内容切换区域
        if (this.activeTab === 'day') {
          // --- 按日：日历模式 ---
          Column({ space: 12 }) {
            // 年月切换头
            Row() {
              Image($r('sys.media.ohos_ic_public_arrow_left'))
                .width(16)
                .height(16)
                .fillColor('#A5B4FC')
                .padding(4)
                .onClick(() => {
                  this.prevMonth();
                })

              Text(`${this.curYear}年 ${this.curMonth}月`)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')

              Image($r('sys.media.ohos_ic_public_arrow_right'))
                .width(16)
                .height(16)
                .fillColor('#A5B4FC')
                .padding(4)
                .onClick(() => {
                  this.nextMonth();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({ left: 24, right: 24 })

            // 星期栏
            Row() {
              ForEach(['日', '一', '二', '三', '四', '五', '六'], (wk: string) => {
                Text(wk)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('rgba(255, 255, 255, 0.4)')
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
              }, (wk: string) => wk)
            }
            .width('100%')
            .padding({ left: 12, right: 12 })

            // 42格日历网格
            Grid() {
              ForEach(this.getCalendarDays(), (cell: CalendarDayCell) => {
                GridItem() {
                  Stack({ alignContent: Alignment.Center }) {
                    if (cell.isSelected && cell.isCurrentMonth) {
                      Circle({ width: 32, height: 32 })
                        .fill('#6366F1')
                        .shadow({ radius: 8, color: 'rgba(99, 102, 241, 0.4)' })
                    } else if (cell.isToday && cell.isCurrentMonth) {
                      Circle({ width: 32, height: 32 })
                        .stroke('rgba(99, 102, 241, 0.8)')
                        .strokeWidth(1.5)
                        .fill('transparent')
                    }

                    Text(cell.dayNumber.toString())
                      .fontSize(13)
                      .fontWeight(cell.isSelected || cell.isToday ? FontWeight.Bold : FontWeight.Normal)
                      .fontColor(
                        !cell.isCurrentMonth
                          ? 'rgba(255, 255, 255, 0.15)'
                          : cell.isSelected
                          ? '#FFFFFF'
                          : cell.isToday
                          ? '#818CF8'
                          : '#E2E8F0'
                      )
                  }
                  .width('100%')
                  .height(36)
                  .onClick(() => {
                    if (cell.isCurrentMonth) {
                      this.selectedDay = cell.dayNumber;
                    }
                  })
                }
              }, (cell: CalendarDayCell) => cell.dateKey)
            }
            .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
            .rowsGap(4)
            .width('100%')
            .height(220)
            .padding({ left: 12, right: 12 })
          }
          .width('100%')
        } else if (this.activeTab === 'month') {
          // --- 按月：月份矩阵 ---
          Column({ space: 14 }) {
            // 年份切换
            Row({ space: 12 }) {
              Image($r('sys.media.ohos_ic_public_arrow_left'))
                .width(16)
                .height(16)
                .fillColor('#A5B4FC')
                .onClick(() => {
                  this.selectedYearOnly--;
                })

              Text(`${this.selectedYearOnly} 年`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')

              Image($r('sys.media.ohos_ic_public_arrow_right'))
                .width(16)
                .height(16)
                .fillColor('#A5B4FC')
                .onClick(() => {
                  this.selectedYearOnly++;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 6 })

            // 1~12月 网格
            Grid() {
              ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], (m: number) => {
                GridItem() {
                  Text(`${m}月`)
                    .fontSize(14)
                    .fontWeight(this.selectedMonthOnly === m ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.selectedMonthOnly === m ? '#FFFFFF' : 'rgba(255, 255, 255, 0.75)')
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .height(44)
                    .backgroundColor(this.selectedMonthOnly === m ? '#6366F1' : 'rgba(255, 255, 255, 0.06)')
                    .borderRadius(12)
                    .border({ width: 1, color: this.selectedMonthOnly === m ? 'rgba(99, 102, 241, 0.5)' : 'rgba(255, 255, 255, 0.08)' })
                    .onClick(() => {
                      this.selectedMonthOnly = m;
                    })
                }
              }, (m: number) => m.toString())
            }
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .rowsGap(10)
            .columnsGap(10)
            .width('100%')
            .height(160)
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
        } else {
          // --- 按年：年份选项 ---
          Column({ space: 12 }) {
            ForEach(this.availableYears, (yr: number) => {
              Row() {
                Text(`${yr} 年度航行记录`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedYearOnly === yr ? '#FFFFFF' : 'rgba(255, 255, 255, 0.75)')

                Blank()

                if (this.selectedYearOnly === yr) {
                  Image($r('sys.media.ohos_ic_public_arrow_right'))
                    .width(14)
                    .height(14)
                    .fillColor('#818CF8')
                }
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 14, bottom: 14 })
              .backgroundColor(this.selectedYearOnly === yr ? 'rgba(99, 102, 241, 0.25)' : 'rgba(255, 255, 255, 0.06)')
              .borderRadius(14)
              .border({ width: 1, color: this.selectedYearOnly === yr ? 'rgba(99, 102, 241, 0.5)' : 'rgba(255, 255, 255, 0.08)' })
              .onClick(() => {
                this.selectedYearOnly = yr;
              })
            }, (yr: number) => yr.toString())
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }

        // 4. 底部操作按钮
        Row({ space: 12 }) {
          Button('全部航行 (清除筛选)')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255, 255, 255, 0.7)')
            .backgroundColor('rgba(255, 255, 255, 0.1)')
            .borderRadius(16)
            .layoutWeight(1)
            .height(44)
            .onClick(() => {
              this.applyAll();
            })

          Button('确认筛选')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .linearGradient({ angle: 90, colors: [['#6366F1', 0], ['#8B5CF6', 1]] })
            .borderRadius(16)
            .layoutWeight(1.2)
            .height(44)
            .onClick(() => {
              this.applyCurrentSelection();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 28 })
      }
      .width('100%')
      .backgroundColor('#1A1339')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)' })
      .offset({ y: this.modalOffsetY })
      .animation({ duration: 320, curve: Curve.FastOutSlowIn })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.isVisible ? HitTestMode.Default : HitTestMode.None)
  }
}
