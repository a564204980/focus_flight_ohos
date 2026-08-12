import { Airport } from '../../models/AirportModel';
import { RULER_FIVE_MIN_UNITS, RULER_SUB_WIDTH, RULER_STEP_WIDTH, RulerFiveMinUnit } from '../../utils/FlightMapMathHelper';

/**
 * 🎯 底部导航控制面板：
 * - 候选城市横向胶囊滑块
 * - 专注时长高亮展示
 * - 航空仪表级精密刻度尺（含游标飞机、吸附与手势）
 * - 开始专注旅程确认按钮
 */
@Component
export struct FlightMapBottomPanel {
  @Prop currentMinutes: number = 15;
  @Prop currentSelectedCode: string = '';
  @Prop candidateAirports: Airport[] = [];
  @Prop rulerContainerWidth: number = 360;
  rulerScroller: Scroller = new Scroller();
  onSelectCity?: (code: string) => void;
  onSelectMinutes?: (minutes: number, index: number) => void;
  onScrollMinutesChange?: (minutes: number) => void;
  onScrollStop?: () => void;
  onScrollPanUpdate?: (deltaX: number) => void;
  onScrollPanEnd?: () => void;
  onConfirm?: () => void;
  onRulerWidthChange?: (width: number) => void;

  private lastPanOffsetX: number = 0;
  private lastHapticTickIndex: number = -1;

  build() {
    Column({ space: 12 }) {
      // (1) 目的地分区标题
      Text('目的地')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(255, 255, 255, 0.75)')
        .width('100%')
        .textAlign(TextAlign.Start)

      // (2) 候选城市名牌横向滑块 (微磨砂透光胶囊)
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.candidateAirports, (apt: Airport) => {
            Row({ space: 6 }) {
              Text(apt.city || apt.name)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.currentSelectedCode === apt.code ? '#FFFFFF' : '#F1F5F9')
              Text(apt.code)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentSelectedCode === apt.code ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.6)')
            }
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.currentSelectedCode === apt.code ? '#F06553' : 'rgba(15, 23, 42, 0.48)')
            .borderRadius(18)
            .border({
              width: 1,
              color: this.currentSelectedCode === apt.code ? 'transparent' : 'rgba(255, 255, 255, 0.22)'
            })
            .onClick(() => {
              if (this.onSelectCity) this.onSelectCity(apt.code);
            })
          })
        }
        .padding({ left: 2, right: 2 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      // (3) 专注时长与高亮数字行
      Row() {
        Text('专注时长')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255, 255, 255, 0.75)')

        Blank()

        Row({ space: 2 }) {
          if (this.currentMinutes < 60) {
            Text(`${this.currentMinutes}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F06553')
            Text('分钟')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('rgba(255, 255, 255, 0.85)')
          } else {
            Text(`${Math.floor(this.currentMinutes / 60)}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F06553')
            Text('小时')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('rgba(255, 255, 255, 0.85)')
            if (this.currentMinutes % 60 > 0) {
              Text(`${this.currentMinutes % 60}`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F06553')
              Text('分钟')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255, 255, 255, 0.85)')
            }
          }
        }
      }
      .width('100%')
      .margin({ top: 4 })

      // (4) 精密航空仪表级横向刻度尺
      Column({ space: 2 }) {
        Scroll(this.rulerScroller) {
          Row({ space: 0 }) {
            Blank()
              .width(Math.max(0, this.rulerContainerWidth / 2.0 - (RULER_SUB_WIDTH / 2.0) - 18))

            ForEach(RULER_FIVE_MIN_UNITS, (unit: RulerFiveMinUnit, index: number) => {
              Row({ space: 0 }) {
                // 5分钟主刻度单元
                Column({ space: 4 }) {
                  // (A) 顶部游标飞机
                  if (unit.minutes === this.currentMinutes) {
                    Image($r('app.media.ic_ruler_plane_pointer'))
                      .width(14)
                      .height(14)
                  } else {
                    Row()
                      .width(1)
                      .height(14)
                  }

                  // (B) 刻度数字
                  if (unit.minutes === this.currentMinutes) {
                    Text(`${unit.minutes}`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#F06553')
                      .textAlign(TextAlign.Center)
                      .width(48)
                      .height(16)
                      .margin({ left: -20, right: -20 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.None })
                  } else if (unit.isMajor) {
                    Text(`${unit.minutes}`)
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('rgba(255, 255, 255, 0.85)')
                      .textAlign(TextAlign.Center)
                      .width(48)
                      .height(16)
                      .margin({ left: -20, right: -20 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.None })
                  } else {
                    Row()
                      .width(1)
                      .height(16)
                  }

                  // (C) 底部刻度线
                  Column()
                    .width(unit.minutes === this.currentMinutes ? 2.5 : (unit.isMajor ? 1.8 : 1.4))
                    .height(unit.minutes === this.currentMinutes ? 18 : (unit.isMajor ? 14 : 9.5))
                    .backgroundColor(
                      unit.minutes === this.currentMinutes
                        ? '#F06553'
                        : (unit.isMajor ? '#FFFFFF' : 'rgba(255, 255, 255, 0.75)')
                    )
                    .borderRadius(unit.minutes === this.currentMinutes ? 1.5 : (unit.isMajor ? 1.0 : 0.7))
                }
                .width(RULER_SUB_WIDTH)
                .height(56)
                .clip(false)
                .alignItems(HorizontalAlign.Center)
                .justifyContent(FlexAlign.End)
                .onClick(() => {
                  if (this.onSelectMinutes) this.onSelectMinutes(unit.minutes, index);
                })

                // 5分钟之间的 3 个紧凑小刻度
                if (unit.minutes < 240) {
                  ForEach([1, 2, 3], (_subIdx: number) => {
                    Column({ space: 4 }) {
                      Row()
                        .width(1)
                        .height(14)
                      Row()
                        .width(1)
                        .height(16)
                      Column()
                        .width(1.0)
                        .height(5.5)
                        .backgroundColor('rgba(255, 255, 255, 0.40)')
                        .borderRadius(0.5)
                    }
                    .width(RULER_SUB_WIDTH)
                    .height(56)
                    .alignItems(HorizontalAlign.Center)
                    .justifyContent(FlexAlign.End)
                    .hitTestBehavior(HitTestMode.None)
                  }, (subIdx: number) => `${unit.minutes}_sub_${subIdx}`)
                }
              }
            }, (unit: RulerFiveMinUnit) => `${unit.minutes}`)

            Blank()
              .width(Math.max(0, this.rulerContainerWidth / 2.0 - (RULER_SUB_WIDTH / 2.0) - 18))
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .onAreaChange((_oldArea, newArea) => {
          if (this.onRulerWidthChange) this.onRulerWidthChange(Number(newArea.width));
        })
        .onScroll(() => {
          const xOffset = this.rulerScroller.currentOffset().xOffset;
          const tickIdx = Math.round(xOffset / RULER_STEP_WIDTH);
          if (tickIdx >= 0 && tickIdx < RULER_FIVE_MIN_UNITS.length) {
            const targetMin = RULER_FIVE_MIN_UNITS[tickIdx].minutes;
            if (this.onScrollMinutesChange) this.onScrollMinutesChange(targetMin);
          }
        })
        .onScrollStop(() => {
          if (this.onScrollStop) this.onScrollStop();
        })
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionStart(() => {
            this.lastPanOffsetX = 0;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (!event) return;
            const deltaX = event.offsetX - this.lastPanOffsetX;
            this.lastPanOffsetX = event.offsetX;
            const currentScrollX = this.rulerScroller.currentOffset().xOffset;
            const targetScrollX = Math.max(0, currentScrollX - deltaX * 0.85);
            this.rulerScroller.scrollTo({ xOffset: targetScrollX, yOffset: 0 });
          })
          .onActionEnd(() => {
            if (this.onScrollStop) this.onScrollStop();
          })
      )

      // (5) 底部主操作按钮
      Button() {
        Row({ space: 6 }) {
          Text('开始专注旅程')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
      .width('100%')
      .height(48)
      .backgroundColor('#F06553')
      .borderRadius(24)
      .shadow({ radius: 12, color: 'rgba(240, 101, 83, 0.45)', offsetY: 4 })
      .margin({ top: 6 })
      .onClick(() => {
        if (this.onConfirm) this.onConfirm();
      })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 32, bottom: 28 })
    .linearGradient({
      angle: 180,
      colors: [
        ['rgba(10, 15, 26, 0.0)', 0.0],
        ['rgba(10, 15, 26, 0.28)', 0.22],
        ['rgba(10, 15, 26, 0.62)', 0.58],
        ['rgba(10, 15, 26, 0.86)', 1.0]
      ]
    })
  }
}
