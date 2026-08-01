import { router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';

/**
 * SeatSelectionPage.ets
 * 方案 C：全屏战术机舱选座舱 (Full-Screen Tactical Seat Selection Page)
 * 1:1 还原图 1 真实机舱视角与 Cyber HUD 战术图层
 */

interface SeatParams {
  flightNo?: string;
  originCode?: string;
  destCode?: string;
  focusMinutesVal?: number;
  estDistance?: string;
  currentSeat?: string;
}

@Entry
@Component
struct SeatSelectionPage {
  @State flightNo: string = 'CA933';
  @State originCode: string = 'CTU';
  @State destCode: string = 'CDG';
  @State focusMinutesVal: number = 45;
  @State estDistance: string = '8,245 KM';
  @State selectedSeatId: string = '1F';
  @State selectedCabin: string = 'Business';

  aboutToAppear(): void {
    const params = router.getParams() as SeatParams;
    if (params) {
      if (params.flightNo) this.flightNo = params.flightNo;
      if (params.originCode) this.originCode = params.originCode;
      if (params.destCode) this.destCode = params.destCode;
      if (params.focusMinutesVal) this.focusMinutesVal = params.focusMinutesVal;
      if (params.estDistance) this.estDistance = params.estDistance;
      if (params.currentSeat) this.selectedSeatId = params.currentSeat;
    }
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  private isSeatSelected(seatId: string): boolean {
    return this.selectedSeatId === seatId;
  }

  private isSeatOccupied(row: number, col: string): boolean {
    return (row === 1 && (col === 'A' || col === 'B')) || (row === 3 && col === 'C') || (row === 4 && (col === 'E' || col === 'F')) || (row === 6 && col === 'D');
  }

  build() {
    Column() {
      // 1. 全屏顶栏战术 Header (Top Tactical Navigation Bar)
      Row() {
        // 返回按钮
        Row({ space: 6 }) {
          Text('‹')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
          Text('返回')
            .fontSize(14)
            .fontColor('#F8FAFC')
        }
        .padding({ left: 10, right: 14, top: 6, bottom: 6 })
        .backgroundColor('rgba(255, 255, 255, 0.08)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 18 })
        .borderRadius(18)
        .onClick(() => {
          this.triggerHaptic();
          router.back();
        })

        Blank()

        // 标题
        Column({ space: 2 }) {
          Text('全景选座 · 战术机舱')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text(`航班 ${this.flightNo} · B787-9 宽体机`)
            .fontSize(11)
            .fontColor('#38BDF8')
        }

        Blank()

        // 机型 Badge
        Text('FOCUS FIRST')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4ADE80')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('rgba(74, 222, 128, 0.12)')
          .border({ width: 1, color: 'rgba(74, 222, 128, 0.3)', radius: 10 })
          .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 40, bottom: 12 })
      .backgroundColor('rgba(10, 15, 26, 0.95)')
      .border({ width: { bottom: 1 }, color: 'rgba(255, 255, 255, 0.1)' })

      // 2. 航班摘要战术 Banner (Flight Info Summary Strip)
      Row() {
        Row({ space: 8 }) {
          Text(this.originCode)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text('✈')
            .fontSize(12)
            .fontColor('#38BDF8')
          Text(this.destCode)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4ADE80')
        }

        Blank()

        Row({ space: 12 }) {
          Text(`航程: ${this.estDistance}`)
            .fontSize(11)
            .fontColor('#94A3B8')
          Text(`专注: ${this.focusMinutesVal} 分钟`)
            .fontSize(11)
            .fontColor('#38BDF8')
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .backgroundColor('rgba(15, 23, 42, 0.6)')

      // 3. 全屏主体：1:1 弧形机头 & 机舱选座网格 (Scrollable Aircraft Cabin Area)
      Scroll() {
        Column({ space: 20 }) {
          // 3a. 1:1 对标图 1：拱形机头轮廓 & 4 扇驾驶舱风挡玻璃 (Airplane Nose Cockpit)
          Stack({ alignContent: Alignment.Top }) {
            // 机头拱形外壳
            Column()
              .width(280)
              .height(160)
              .backgroundColor('rgba(255, 255, 255, 0.03)')
              .border({ width: 2, color: 'rgba(255, 255, 255, 0.15)', radius: { topLeft: 140, topRight: 140 } })
              .borderRadius({ topLeft: 140, topRight: 140 })

            // 驾驶舱 4 扇风挡玻璃 (Cockpit Arc Windows)
            Row({ space: 8 }) {
              Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 16, topRight: 4 })
              Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 4, topRight: 4 })
              Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 4, topRight: 4 })
              Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 4, topRight: 16 })
            }
            .offset({ y: 58 })
          }
          .width('100%')
          .height(140)

          // 3b. 图例说明 Bar (Seat Status Legend Bar)
          Row({ space: 16 }) {
            Row({ space: 6 }) {
              Row().width(12).height(12).backgroundColor('rgba(255, 255, 255, 0.15)').border({ width: 1, color: 'rgba(255, 255, 255, 0.3)', radius: 3 }).borderRadius(3)
              Text('可选空座').fontSize(10).fontColor('#94A3B8')
            }

            Row({ space: 6 }) {
              Row().width(12).height(12).backgroundColor('#38BDF8').borderRadius(3)
              Text('已选择').fontSize(10).fontColor('#38BDF8')
            }

            Row({ space: 6 }) {
              Row().width(12).height(12).backgroundColor('rgba(15, 23, 42, 0.8)').border({ width: 0.5, color: 'rgba(148, 163, 184, 0.2)', radius: 3 }).borderRadius(3)
              Text('已被占用').fontSize(10).fontColor('rgba(148, 163, 184, 0.5)')
            }
          }

          // 3c. 商务舱 Business Section
          Column({ space: 14 }) {
            Row() {
              Text('Business')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
              Blank()
              Text('2 x 2 豪华宽座舱')
                .fontSize(12)
                .fontColor('#38BDF8')
            }
            .width('100%')
            .padding({ left: 16, right: 16 })

            // 列字母 (A B C   D E F)
            Row() {
              Row({ space: 20 }) {
                Text('A').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                Text('B').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                Text('C').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
              }
              Blank()
              Text('过道').fontSize(10).fontColor('rgba(148, 163, 184, 0.35)')
              Blank()
              Row({ space: 20 }) {
                Text('D').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                Text('E').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                Text('F').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .padding({ left: 32, right: 32 })

            // 排 1 ~ 2
            ForEach([1, 2], (rowNum: number) => {
              Row() {
                Text(`${rowNum}`)
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .width(20)

                Row({ space: 16 }) {
                  ForEach(['A', 'B', 'C'], (col: string) => {
                    this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Business')
                  })
                }

                Blank()

                Row({ space: 16 }) {
                  ForEach(['D', 'E', 'F'], (col: string) => {
                    this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Business')
                  })
                }

                Text(`${rowNum}`)
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .width(20)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ left: 10, right: 10 })
            })
          }
          .width('100%')

          Divider().color('rgba(255, 255, 255, 0.08)')

          // 3d. 经济舱 Economy Section
          Column({ space: 14 }) {
            Row() {
              Text('Economy')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
              Blank()
              Text('3 x 3 舒适标准座')
                .fontSize(12)
                .fontColor('#94A3B8')
            }
            .width('100%')
            .padding({ left: 16, right: 16 })

            // 排 3 ~ 10
            ForEach([3, 4, 5, 6, 7, 8, 9, 10], (rowNum: number) => {
              Row() {
                Text(`${rowNum}`)
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .width(20)

                Row({ space: 16 }) {
                  ForEach(['A', 'B', 'C'], (col: string) => {
                    this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Economy')
                  })
                }

                Blank()

                Row({ space: 16 }) {
                  ForEach(['D', 'E', 'F'], (col: string) => {
                    this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Economy')
                  })
                }

                Text(`${rowNum}`)
                  .fontSize(12)
                  .fontColor('#94A3B8')
                  .width(20)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ left: 10, right: 10 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 120 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 4. 底部固定战术确认栏 (Sticky Tactical Bottom Bar)
      Row() {
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text('已选座位:')
              .fontSize(12)
              .fontColor('#94A3B8')
            Text(this.selectedSeatId)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')
          }

          Text(this.selectedSeatId.endsWith('A') || this.selectedSeatId.endsWith('F') ? '靠窗 Seat · 视野极佳' : '靠近过道 · 出入顺畅')
            .fontSize(11)
            .fontColor('rgba(248, 250, 252, 0.7)')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 确认选座生成登机牌主 Action 按钮
        Row({ space: 6 }) {
          Text('确认选座并完成值机')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#020617')
          Text('➔')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#020617')
        }
        .padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .backgroundColor('#4ADE80')
        .borderRadius(24)
        .shadow({ radius: 16, color: 'rgba(74, 222, 128, 0.45)', offsetY: 4 })
        .onClick(() => {
          this.triggerHaptic();
          // 返回主页并把选座结果传回！
          router.back({
            url: 'pages/Index',
            params: {
              completedSeat: this.selectedSeatId,
              isCheckInConfirmed: true
            }
          });
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 24 })
      .backgroundColor('rgba(10, 15, 26, 0.95)')
      .border({ width: { top: 1 }, color: 'rgba(255, 255, 255, 0.12)' })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.9)', offsetY: -6 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
  }

  // 1:1 对标图 1 的单个 SeatTile 组件
  @Builder
  SeatTile(seatId: string, row: number, col: string, cabin: string) {
    Column() {
      if (this.isSeatSelected(seatId)) {
        // 当前选中：Cyber 亮蓝 #38BDF8 + 白色勾选 Icon ✓
        Text('✓')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      } else {
        // 普通座位轮廓
        Column()
          .width(22)
          .height(12)
          .backgroundColor(this.isSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.15)' : 'rgba(255, 255, 255, 0.25)')
          .borderRadius({ topLeft: 4, topRight: 4 })
      }
    }
    .width(34)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isSeatSelected(seatId) ? '#38BDF8' : (this.isSeatOccupied(row, col) ? 'rgba(15, 23, 42, 0.8)' : 'rgba(255, 255, 255, 0.08)'))
    .border({
      width: this.isSeatSelected(seatId) ? 1.5 : (this.isSeatOccupied(row, col) ? 0.5 : 1),
      color: this.isSeatSelected(seatId) ? '#38BDF8' : (this.isSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.2)' : 'rgba(255, 255, 255, 0.2)'),
      radius: 8
    })
    .borderRadius(8)
    .shadow({ radius: this.isSeatSelected(seatId) ? 10 : 0, color: 'rgba(56, 189, 248, 0.65)' })
    .onClick(() => {
      if (this.isSeatOccupied(row, col)) return;
      this.selectedSeatId = seatId;
      this.selectedCabin = cabin;
      this.triggerHaptic();
    })
  }
}
