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

import { promptAction } from '@kit.ArkUI';
import { CloseButton } from './CloseButton';
import { Airport, findAirportByCode } from '../models/AirportModel';

export interface QuickTimeOption {
  id: string;
  label: string;
  calcTime: () => Date;
}

export interface FocusTagOption {
  id: string;
  name: string;
}

/**
 * 预订航班计划底部抽屉组件 (FlightBookingSheet)
 * 遵循 Dribbble 航空美学与温馨微光设计规范
 */
@Component
export struct FlightBookingSheet {
  @StorageLink('isBookFlightSheetVisible') isBookFlightSheetVisible: boolean = false;
  @StorageLink('selectedDestinationAirport') selectedDestination?: Airport = undefined;
  @StorageLink('bookedFlightInfo') bookedFlightInfo: string = '';
  onClose?: () => void;
  onBookSuccess?: (flightInfo: string) => void;

  // 1. 起飞时间相关状态
  @State selectedQuickTimeId: string = '30m';
  @State customTimeString: string = '';
  @State selectedDate: Date = new Date();

  // 2. 专注时长相关状态
  @State selectedDurationMinutes: number = 45;
  private readonly durationOptions: number[] = [25, 45, 60, 90];

  // 3. 专注标签相关状态
  @State selectedTagIndex: number = 0;
  private readonly focusTags: FocusTagOption[] = [
    { id: 'deep_work', name: '#深度工作' },
    { id: 'code_refactor', name: '#代码重构' },
    { id: 'reading', name: '#阅读思考' },
    { id: 'study', name: '#课程学习' },
    { id: 'planning', name: '#方案策划' }
  ];

  aboutToAppear(): void {
    // 默认自定义时间为 30 分钟后
    const d = new Date(Date.now() + 30 * 60 * 1000);
    this.selectedDate = d;
    this.customTimeString = this.formatDateTime(d);
  }

  private formatDateTime(d: Date): string {
    const month = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const hours = d.getHours().toString().padStart(2, '0');
    const minutes = d.getMinutes().toString().padStart(2, '0');
    return `${month}月${day}日 ${hours}:${minutes}`;
  }

  private getQuickTimeOptions(): QuickTimeOption[] {
    return [
      {
        id: '30m',
        label: '30分钟后',
        calcTime: () => new Date(Date.now() + 30 * 60 * 1000)
      },
      {
        id: '1h',
        label: '1小时后',
        calcTime: () => new Date(Date.now() + 60 * 60 * 1000)
      },
      {
        id: 'tonight_20',
        label: '今晚 20:00',
        calcTime: () => {
          const t = new Date();
          t.setHours(20, 0, 0, 0);
          if (t.getTime() <= Date.now()) {
            t.setDate(t.getDate() + 1);
          }
          return t;
        }
      },
      {
        id: 'tomorrow_09',
        label: '明早 09:00',
        calcTime: () => {
          const t = new Date();
          t.setDate(t.getDate() + 1);
          t.setHours(9, 0, 0, 0);
          return t;
        }
      }
    ];
  }

  private selectQuickTime(opt: QuickTimeOption): void {
    this.selectedQuickTimeId = opt.id;
    this.selectedDate = opt.calcTime();
    this.customTimeString = this.formatDateTime(this.selectedDate);
  }

  private handleConfirmBooking(): void {
    const destCity = this.selectedDestination ? this.selectedDestination.city : '北京';
    const flightNo = `FF${Math.floor(100 + Math.random() * 900)}`;
    const tag = this.focusTags[this.selectedTagIndex].name;
    const timeStr = this.formatDateTime(this.selectedDate);

    const summary = `${flightNo} 成都 ✈ ${destCity} | ${this.selectedDurationMinutes}m ${tag} | ${timeStr}`;
    this.bookedFlightInfo = summary;
    AppStorage.setOrCreate('bookedFlightInfo', summary);

    try {
      promptAction.showToast({
        message: `🎫 预订成功！航班 ${flightNo} 将在 ${timeStr} 起飞`,
        duration: 2500
      });
    } catch (e) {}

    if (this.onBookSuccess) {
      this.onBookSuccess(summary);
    }
    if (this.onClose) {
      this.onClose();
    }
  }

  build() {
    Column() {
      // 1. 顶栏：标题、副标题与通用关闭按钮
      Row() {
        Column({ space: 4 }) {
          Text('预订航班计划')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E293B')

          Text('制定未来专属飞行时刻，准点起飞积累机长勋章')
            .fontSize(12)
            .fontColor('#64748B')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        CloseButton({
          circleColor: '#FFFFFF',
          iconColor: '#000000',
          buttonSize: 32,
          onClickAction: () => {
            if (this.onClose) {
              this.onClose();
            }
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 4, bottom: 14 })

      // 2. 核心可滚动内容区
      Scroll() {
        Column({ space: 18 }) {
          // 2.1 【起飞时间】板块
          Column({ space: 10 }) {
            Row({ space: 6 }) {
              Text('【起飞时间】')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
            }
            .width('100%')

            // 快捷时间选择药丸网格
            GridRow({ columns: 4, gutter: { x: 8, y: 8 } }) {
              ForEach(this.getQuickTimeOptions(), (opt: QuickTimeOption) => {
                GridCol({ span: 1 }) {
                  Row() {
                    Text(opt.label)
                      .fontSize(12)
                      .fontWeight(this.selectedQuickTimeId === opt.id ? FontWeight.Bold : FontWeight.Medium)
                      .fontColor(this.selectedQuickTimeId === opt.id ? '#FA6B56' : '#475569')
                      .textAlign(TextAlign.Center)
                  }
                  .width('100%')
                  .height(38)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.selectedQuickTimeId === opt.id ? '#FFF2EE' : '#FFFFFF')
                  .border(this.selectedQuickTimeId === opt.id ? 
                    { width: 1.5, color: '#FA6B56', radius: 10 } : 
                    { width: 1, color: '#E2E8F0', radius: 10 })
                  .borderRadius(10)
                  .shadow(this.selectedQuickTimeId === opt.id ? 
                    { radius: 6, color: 'rgba(250, 107, 86, 0.2)', offsetY: 2 } : 
                    { radius: 2, color: 'rgba(0, 0, 0, 0.02)', offsetY: 1 })
                  .animation({ duration: 250, curve: Curve.FastOutSlowIn })
                  .onClick(() => {
                    this.selectQuickTime(opt);
                  })
                }
              })
            }
            .width('100%')

            // 自定义时间展示与选择栏
            Row() {
              Text('预定起飞时间：')
                .fontSize(13)
                .fontColor('#64748B')

              Text(this.customTimeString)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FA6B56')

              Blank()

              // 修改时间按钮
              Row({ space: 4 }) {
                Text('选择时间')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FA6B56')
                
                Image($r('app.media.ic_chevron'))
                  .width(10)
                  .height(10)
                  .fillColor('#FA6B56')
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FFF5F2')
              .borderRadius(6)
              .onClick(() => {
                DatePickerDialog.show({
                  start: new Date(),
                  end: new Date(Date.now() + 30 * 24 * 3600 * 1000),
                  selected: this.selectedDate,
                  onAccept: (value: DatePickerResult) => {
                    if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
                      const newD = new Date(this.selectedDate.getTime());
                      newD.setFullYear(value.year, value.month, value.day);
                      this.selectedDate = newD;
                      this.selectedQuickTimeId = 'custom';
                      this.customTimeString = this.formatDateTime(newD);
                      
                      // 接着弹出时间选择器
                      TimePickerDialog.show({
                        selected: this.selectedDate,
                        useMilitaryTime: true,
                        onAccept: (timeVal: TimePickerResult) => {
                          if (timeVal.hour !== undefined && timeVal.minute !== undefined) {
                            const finalD = new Date(this.selectedDate.getTime());
                            finalD.setHours(timeVal.hour, timeVal.minute, 0, 0);
                            this.selectedDate = finalD;
                            this.customTimeString = this.formatDateTime(finalD);
                          }
                        }
                      });
                    }
                  }
                });
              })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .border({ width: 1, color: '#E2E8F0' })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('rgba(255, 255, 255, 0.75)')
          .borderRadius(16)
          .border({ width: 1, color: '#F1E9E4' })

          // 2.2 【航线与专注时长】板块
          Column({ space: 10 }) {
            Row() {
              Text('【航线与专注时长】')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
            }
            .width('100%')

            // 航线信息卡片
            Row({ space: 8 }) {
              Image($r('app.media.ic_airport'))
                .width(16)
                .height(16)
                .fillColor('#FA6B56')

              Text('成都天府 (CTU)')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1E293B')

              Text('✈')
                .fontSize(12)
                .fontColor('#94A3B8')

              Text(this.selectedDestination ? `${this.selectedDestination.city} (${this.selectedDestination.code})` : '选择目的地')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.selectedDestination ? '#FA6B56' : '#94A3B8')
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .border({ width: 1, color: '#E2E8F0' })

            // 专注时长药丸选项
            Row({ space: 10 }) {
              ForEach(this.durationOptions, (mins: number) => {
                Row() {
                  Text(`${mins} 分钟`)
                    .fontSize(13)
                    .fontWeight(this.selectedDurationMinutes === mins ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.selectedDurationMinutes === mins ? '#FA6B56' : '#475569')
                }
                .layoutWeight(1)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(this.selectedDurationMinutes === mins ? '#FFF2EE' : '#FFFFFF')
                .border(this.selectedDurationMinutes === mins ? 
                  { width: 1.5, color: '#FA6B56', radius: 10 } : 
                  { width: 1, color: '#E2E8F0', radius: 10 })
                .borderRadius(10)
                .animation({ duration: 250, curve: Curve.FastOutSlowIn })
                .onClick(() => {
                  this.selectedDurationMinutes = mins;
                })
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('rgba(255, 255, 255, 0.75)')
          .borderRadius(16)
          .border({ width: 1, color: '#F1E9E4' })

          // 2.3 【专注目标标签】板块
          Column({ space: 10 }) {
            Row() {
              Text('【专注目标标签】')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
            }
            .width('100%')

            // 标签横向滑动/自适应药丸
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.focusTags, (tag: FocusTagOption, idx: number) => {
                Row() {
                  Text(tag.name)
                    .fontSize(13)
                    .fontWeight(this.selectedTagIndex === idx ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.selectedTagIndex === idx ? '#FA6B56' : '#475569')
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.selectedTagIndex === idx ? '#FFF2EE' : '#FFFFFF')
                .border(this.selectedTagIndex === idx ? 
                  { width: 1.5, color: '#FA6B56', radius: 8 } : 
                  { width: 1, color: '#E2E8F0', radius: 8 })
                .borderRadius(8)
                .animation({ duration: 250, curve: Curve.FastOutSlowIn })
                .onClick(() => {
                  this.selectedTagIndex = idx;
                })
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('rgba(255, 255, 255, 0.75)')
          .borderRadius(16)
          .border({ width: 1, color: '#F1E9E4' })
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 3. 底部确认预订机票主操作按钮
      Row() {
        Button('确认预订机票')
          .width('100%')
          .height(48)
          .backgroundColor('#FA6B56')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .borderRadius(24)
          .shadow({ radius: 12, color: 'rgba(250, 107, 86, 0.35)', offsetY: 4 })
          .onClick(() => {
            this.handleConfirmBooking();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 10, bottom: 20 })
    }
    .width('100%')
    .height('100%')
  }
}
