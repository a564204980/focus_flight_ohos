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

import { FlightRecordItem } from '../../database/FlightRecordRepository';
import { findAirportByCode } from '../../models/AirportModel';

/**
 * 极简呼吸感横版登机牌卡片组件 (支持 @Reusable 鸿蒙原生复用池)
 * 极致性能优化：Canvas 单节点绘制撕票线与条形码，节点数从 ~100 降至 ~20
 */
@Reusable
@Component
export struct FlightBoardingPassCard {
  @Prop record: FlightRecordItem;
  onCardClick?: (record: FlightRecordItem) => void;

  // 条形码粗细数组 (1为细条，2为粗条)
  private static readonly BARCODE_HEIGHTS: number[] = [
    2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2
  ];

  aboutToReuse(params: Record<string, Object>): void {
    if (params.record) {
      this.record = params.record as FlightRecordItem;
    }
  }

  private formatTimeOnly(ts: number): string {
    if (!ts) {
      return '--:--';
    }
    const date = new Date(ts);
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    return `${hh}:${mm}`;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 完整连贯的机票底板 (钛冷灰对角高光渐变)
      Row()
        .width('100%')
        .height(104)
        .linearGradient({ angle: 140, colors: [['#3B4146', 0], ['#2D3134', 0.45], ['#1F2326', 1]] })
        .borderRadius(10)
        .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.06)' })

      // 2. 拟物世界地图底纹
      Image($r('app.media.bg_real_world_silhouette'))
        .width('110%')
        .height(104)
        .objectFit(ImageFit.Cover)
        .opacity(0.20)
        .borderRadius(10)
        .draggable(false)
        .hitTestBehavior(HitTestMode.None)

      // 3. 机票前景信息层
      Row() {
        // ===== A. 左侧：主联信息区 =====
        Column() {
          // 第 1 行：状态胶囊与时间
          Row() {
            if (this.record.status === 'completed') {
              Text('准点降落')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#34D399')
                .backgroundColor('rgba(16, 185, 129, 0.15)')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
            } else {
              Text('中途迫降')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FBBF24')
                .backgroundColor('rgba(245, 158, 11, 0.18)')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
            }

            Blank()

            Text(`${this.formatTimeOnly(this.record.startTime)} - ${this.formatTimeOnly(this.record.endTime)}`)
              .fontSize(11)
              .fontColor('rgba(255, 255, 255, 0.45)')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 第 2 行：目的地城市大字与航线三字码
          Row() {
            Text(findAirportByCode(this.record.destCode)?.city || this.record.destCode)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()

            Row({ space: 6 }) {
              Text(this.record.originCode)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(255, 255, 255, 0.85)')

              Row()
                .width(16)
                .height(1)
                .backgroundColor('rgba(255, 255, 255, 0.35)')

              Text(this.record.destCode)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('rgba(255, 255, 255, 0.85)')
            }
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 第 3 行：专注主题与专注时长
          Row({ space: 8 }) {
            Text(this.record.taskTitle || '常规专注')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('rgba(255, 255, 255, 0.85)')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Row({ space: 2 }) {
              Text(`${this.record.actualDurationMin}`)
                .fontSize(13.5)
                .fontWeight(FontWeight.Bold)
                .fontColor('#818CF8')
              Text('分钟')
                .fontSize(10.5)
                .fontColor('rgba(255, 255, 255, 0.55)')
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .height(104)
        .padding({ left: 16, right: 12, top: 12, bottom: 12 })
        .justifyContent(FlexAlign.SpaceBetween)

        // ===== B. 中间：打孔撕票线 =====
        Stack() {
          // 撕票线虚线
          Column({ space: 3.5 }) {
            ForEach(Array(14).fill(0), () => {
              Stack() {
                // 亮色光晕层 (模拟打孔厚度)
                Row().width(3.2).height(3.2).borderRadius(1.6).backgroundColor('rgba(255, 255, 255, 0.22)')
                  .position({ x: 0, y: 0.8 })
                // 深色本体层
                Row().width(3.2).height(3.2).borderRadius(1.6).backgroundColor('#1A1B1D')
              }.width(3.2).height(4)
            })
          }
          .width(16)
          .height(104)
          .justifyContent(FlexAlign.Center)

          // 顶部半圆凹槽
          Row().width(18).height(9)
            .backgroundColor('#1D191A')
            .borderRadius({ bottomLeft: 9, bottomRight: 9 })
            .position({ x: -1, y: 0 })

          // 底部半圆凹槽
          Row().width(18).height(9)
            .backgroundColor('#1D191A')
            .borderRadius({ topLeft: 9, topRight: 9 })
            .position({ x: -1, y: 95 })
        }
        .width(16)
        .height(104)

        // ===== C. 右侧：副券存根联条形码 =====
        Column({ space: 0.5 }) {
          ForEach(FlightBoardingPassCard.BARCODE_HEIGHTS, (h: number, idx: number) => {
            Row()
              .width(24) // 固定宽度 24
              .height(h * 0.95) // 粗细（1 或 2）
              .backgroundColor(idx % 2 === 0 ? 'rgba(255, 255, 255, 0.88)' : 'transparent')
          })
        }
        .width(52)
        .height(104)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(104)
      .backgroundColor('transparent')
    }
    .width('100%')
    .height(104)
    .borderRadius(10)
    .renderGroup(true)
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick(this.record);
      }
    })
  }
}
