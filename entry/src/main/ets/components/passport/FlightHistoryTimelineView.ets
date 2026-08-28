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

import { FlightRecordItem, FlightRecordRepository } from '../../database/FlightRecordRepository';
import { findAirportByCode } from '../../models/AirportModel';
import { FlightRecordDetailModal } from './FlightRecordDetailModal';

interface DayGroupItem {
  dateKey: string;
  displayDate: string;
  totalMinutes: number;
  flightsCount: number;
  records: FlightRecordItem[];
}

/**
 * 航程日志与专注历史时间轴组件 (Flight History Timeline View)
 */
@Component
export struct FlightHistoryTimelineView {
  @Prop @Watch('onFilterChanged') yearFilter: number = 0;
  @StorageProp('flightStatsUpdateTrigger') @Watch('onFilterChanged') statsTrigger: number = 0;

  @State private dayGroups: DayGroupItem[] = [];
  @State private totalFlightsCount: number = 0;
  @State private totalMinutesSum: number = 0;
  @State private isLoading: boolean = true;
  @State private selectedRecord: FlightRecordItem | undefined = undefined;
  @State private isDetailModalVisible: boolean = false;

  aboutToAppear(): void {
    this.loadRecords();
  }

  private onFilterChanged(): void {
    this.loadRecords();
  }

  private async loadRecords(): Promise<void> {
    this.isLoading = true;
    try {
      await FlightRecordRepository.seed2025MockDataIfEmpty();
      const records = await FlightRecordRepository.getAllFlightRecords(this.yearFilter > 0 ? this.yearFilter : undefined);
      this.totalFlightsCount = records.length;
      
      let minutesSum = 0;
      const groupMap: Map<string, FlightRecordItem[]> = new Map();

      for (let i = 0; i < records.length; i++) {
        const r = records[i];
        minutesSum += r.actualDurationMin;
        const dateObj = new Date(r.startTime);
        const dateKey = `${dateObj.getFullYear()}-${(dateObj.getMonth() + 1).toString().padStart(2, '0')}-${dateObj.getDate().toString().padStart(2, '0')}`;
        if (!groupMap.has(dateKey)) {
          groupMap.set(dateKey, []);
        }
        groupMap.get(dateKey)!.push(r);
      }

      this.totalMinutesSum = minutesSum;
      const groups: DayGroupItem[] = [];
      const today = new Date();
      const todayKey = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
      
      const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
      const yesterdayKey = `${yesterday.getFullYear()}-${(yesterday.getMonth() + 1).toString().padStart(2, '0')}-${yesterday.getDate().toString().padStart(2, '0')}`;

      groupMap.forEach((items, key) => {
        let display = key;
        if (key === todayKey) {
          const m = today.getMonth() + 1;
          const d = today.getDate();
          display = `今天 · ${m}月${d}日`;
        } else if (key === yesterdayKey) {
          const m = yesterday.getMonth() + 1;
          const d = yesterday.getDate();
          display = `昨天 · ${m}月${d}日`;
        } else {
          const parts = key.split('-');
          display = `${parts[0]}年${parseInt(parts[1])}月${parseInt(parts[2])}日`;
        }

        const dayMin = items.reduce((sum, item) => sum + item.actualDurationMin, 0);
        groups.push({
          dateKey: key,
          displayDate: display,
          totalMinutes: dayMin,
          flightsCount: items.length,
          records: items
        });
      });

      this.dayGroups = groups;
    } catch (e) {
      // ignore
    } finally {
      this.isLoading = false;
    }
  }

  private formatTimeOnly(ts: number): string {
    if (!ts) return '--:--';
    const date = new Date(ts);
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    return `${hh}:${mm}`;
  }

  @Builder
  private buildFlightCard(record: FlightRecordItem) {
    Row() {
      // 左侧状态指示条
      Column()
        .width(4)
        .height(72)
        .backgroundColor(record.status === 'completed' ? '#10B981' : '#EF4444')
        .borderRadius(2)
        .margin({ right: 14 })

      // 中间信息
      Column({ space: 6 }) {
        // 航线与航班号
        Row({ space: 6 }) {
          Text(record.flightNo)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3B82F6')
            .backgroundColor('rgba(59, 130, 246, 0.08)')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)

          Text(`${record.originCode} ${findAirportByCode(record.originCode)?.city || ''} ➔ ${record.destCode} ${findAirportByCode(record.destCode)?.city || ''}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        // 任务与起止时间
        Row() {
          Text(record.taskTitle || '自由专注')
            .fontSize(12)
            .fontColor('#64748B')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`${this.formatTimeOnly(record.startTime)} - ${this.formatTimeOnly(record.endTime)}`)
            .fontSize(11)
            .fontColor('#94A3B8')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 右侧时长与状态胶囊
      Column({ space: 4 }) {
        Row({ space: 2 }) {
          Text(`${record.actualDurationMin}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(record.status === 'completed' ? '#0F172A' : '#EF4444')
          Text('分')
            .fontSize(11)
            .fontColor('#94A3B8')
        }

        Text(record.status === 'completed' ? '准点' : '迫降')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(record.status === 'completed' ? '#10B981' : '#EF4444')
          .backgroundColor(record.status === 'completed' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(239, 68, 68, 0.1)')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
      }
      .alignItems(HorizontalAlign.End)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 14, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
    .onClick(() => {
      this.selectedRecord = record;
      this.isDetailModalVisible = true;
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 20 }) {
          // 1. 顶部总览小结卡片
          Row() {
            Column({ space: 4 }) {
              Text('航程总计')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#64748B')
                .letterSpacing(0.5)

              Row({ space: 4 }) {
                Text(`${this.totalFlightsCount}`)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F172A')
                Text('趟航班')
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .margin({ bottom: 2 })
              }
              .alignItems(VerticalAlign.Bottom)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Divider()
              .vertical(true)
              .height(32)
              .color('#E2E8F0')

            Column({ space: 4 }) {
              Text('累计专注')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#64748B')
                .letterSpacing(0.5)

              Row({ space: 4 }) {
                Text(`${(this.totalMinutesSum / 60).toFixed(1)}`)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#3B82F6')
                Text(`小时 (${this.totalMinutesSum}分)`)
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .margin({ bottom: 2 })
              }
              .alignItems(VerticalAlign.Bottom)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1.5)
            .margin({ left: 16 })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })

          // 2. 空状态展示
          if (!this.isLoading && this.dayGroups.length === 0) {
            Column({ space: 12 }) {
              Text('✈️')
                .fontSize(44)
                .margin({ top: 40 })

              Text('暂无专注飞行记录')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#334155')

              Text('开启你的第一趟专注航班，点亮属于你的飞行航迹吧')
                .fontSize(12)
                .fontColor('#94A3B8')
                .textAlign(TextAlign.Center)
                .padding({ left: 32, right: 32 })
            }
            .width('100%')
            .padding({ bottom: 80 })
            .alignItems(HorizontalAlign.Center)
          }

          // 3. 时间轴流水列表
          ForEach(this.dayGroups, (group: DayGroupItem) => {
            Column({ space: 10 }) {
              // 日期分组 Header
              Row() {
                Row({ space: 6 }) {
                  Circle({ width: 6, height: 6 })
                    .fill('#3B82F6')

                  Text(group.displayDate)
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1E293B')
                }

                Blank()

                Text(`${group.flightsCount} 趟 · ${group.totalMinutes} 分钟`)
                  .fontSize(11)
                  .fontColor('#94A3B8')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ left: 4, right: 4 })

              // 当日航班卡片列表
              ForEach(group.records, (record: FlightRecordItem) => {
                this.buildFlightCard(record)
              }, (record: FlightRecordItem) => record.id)
            }
            .width('100%')
          }, (group: DayGroupItem) => group.dateKey)

          // 底部垫高，避让悬浮胶囊底栏
          Row().height(100)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 4. 单次航班复盘详情弹窗
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
