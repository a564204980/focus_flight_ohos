import { vibrator } from '@kit.SensorServiceKit';

/**
 * SeatSelectionDialog.ets
 * 1:1 还原真机选座值机抽屉 (Interactive Cabin Seat Selection Dialog)
 */

interface SeatInfo {
  id: string;       // 如 "1A", "1F", "5C"
  row: number;      // 排数 1 ~ 10
  col: string;      // "A", "B", "C", "D", "E", "F"
  cabin: string;    // "Business" | "Economy"
  isOccupied: boolean; // 是否已被占用
  isWindow: boolean;   // 是否靠窗
}

@CustomDialog
export struct SeatSelectionDialog {
  controller?: CustomDialogController;
  flightNo: string = 'CA933';
  originCode: string = 'TFU';
  destCode: string = 'CDG';
  onConfirmSeat?: (seatId: string, cabin: string) => void;

  @State selectedSeatId: string = '1F';
  @State selectedCabin: string = 'Business';

  // 初始化机舱座位列表 (商务舱 1-2 排, 经济舱 3-7 排)
  private seatList: SeatInfo[] = [];

  aboutToAppear(): void {
    const cols = ['A', 'B', 'C', 'D', 'E', 'F'];
    
    // 生成 1~2 排商务舱
    for (let r = 1; r <= 2; r++) {
      cols.forEach((col) => {
        const isOcc = (r === 1 && (col === 'A' || col === 'B')) || (r === 2 && col === 'D');
        this.seatList.push({
          id: `${r}${col}`,
          row: r,
          col: col,
          cabin: 'Business',
          isOccupied: isOcc,
          isWindow: col === 'A' || col === 'F'
        });
      });
    }

    // 生成 3~7 排经济舱
    for (let r = 3; r <= 7; r++) {
      cols.forEach((col) => {
        const isOcc = (r === 3 && col === 'C') || (r === 4 && (col === 'A' || col === 'F')) || (r === 6 && col === 'E');
        this.seatList.push({
          id: `${r}${col}`,
          row: r,
          col: col,
          cabin: 'Economy',
          isOccupied: isOcc,
          isWindow: col === 'A' || col === 'F'
        });
      });
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

  build() {
    Column({ space: 14 }) {
      // 1. 顶部 Header (标题与关闭按钮)
      Row() {
        Column({ space: 2 }) {
          Text('在线选座 & 值机')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text(`航班 ${this.flightNo} · ${this.originCode} ➔ ${this.destCode}`)
            .fontSize(12)
            .fontColor('#94A3B8')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 关闭按钮
        Row() {
          Text('✕')
            .fontSize(14)
            .fontColor('#94A3B8')
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.08)')
        .borderRadius(14)
        .onClick(() => {
          this.controller?.close();
        })
      }
      .width('100%')

      Divider().color('rgba(255, 255, 255, 0.1)')

      // 2. 机舱与座位可滚动视图区域 (包含 1:1 弧形机头轮廓)
      Scroll() {
        Column({ space: 16 }) {
          // 2a. 1:1 对标图 1：机头弧形轮廓 & 4 扇驾驶舱风挡玻璃 (Airplane Nose Cockpit)
          Stack({ alignContent: Alignment.Top }) {
            // 机头外壳拱形
            Column()
              .width(240)
              .height(130)
              .backgroundColor('rgba(255, 255, 255, 0.04)')
              .border({ width: 1.5, color: 'rgba(255, 255, 255, 0.15)', radius: { topLeft: 120, topRight: 120 } })
              .borderRadius({ topLeft: 120, topRight: 120 })

            // 驾驶舱风挡玻璃弧形挡板 4 块 (Cockpit Windows)
            Row({ space: 6 }) {
              Row().width(42).height(24).backgroundColor('rgba(2, 6, 23, 0.85)').borderRadius({ topLeft: 12, topRight: 4 })
              Row().width(42).height(24).backgroundColor('rgba(2, 6, 23, 0.85)').borderRadius({ topLeft: 4, topRight: 4 })
              Row().width(42).height(24).backgroundColor('rgba(2, 6, 23, 0.85)').borderRadius({ topLeft: 4, topRight: 4 })
              Row().width(42).height(24).backgroundColor('rgba(2, 6, 23, 0.85)').borderRadius({ topLeft: 4, topRight: 12 })
            }
            .offset({ y: 48 })
          }
          .width('100%')
          .height(110)

          // 2b. 商务舱 Header
          Column({ space: 10 }) {
            Row() {
              Text('Business')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
              Blank()
              Text('2 x 2 豪华宽座')
                .fontSize(11)
                .fontColor('#38BDF8')
            }
            .width('100%')
            .padding({ left: 10, right: 10 })

            // 座位列字母指示 (A B C  D E F)
            Row() {
              Row({ space: 16 }) {
                Text('A').fontSize(11).fontColor('#94A3B8').width(26).textAlign(TextAlign.Center)
                Text('B').fontSize(11).fontColor('#94A3B8').width(26).textAlign(TextAlign.Center)
                Text('C').fontSize(11).fontColor('#94A3B8').width(26).textAlign(TextAlign.Center)
              }
              Blank()
              Text('过道').fontSize(9).fontColor('rgba(148, 163, 184, 0.4)')
              Blank()
              Row({ space: 16 }) {
                Text('D').fontSize(11).fontColor('#94A3B8').width(26).textAlign(TextAlign.Center)
                Text('E').fontSize(11).fontColor('#94A3B8').width(26).textAlign(TextAlign.Center)
                Text('F').fontSize(11).fontColor('#94A3B8').width(26).textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .padding({ left: 24, right: 24 })

            // 渲染商务舱排 1 ~ 2
            ForEach([1, 2], (rowNum: number) => {
              Row() {
                // 左侧排号
                Text(`${rowNum}`)
                  .fontSize(11)
                  .fontColor('#94A3B8')
                  .width(16)

                // 左侧 3 列 A B C
                Row({ space: 12 }) {
                  ForEach(['A', 'B', 'C'], (col: string) => {
                    this.SeatItem(`${rowNum}${col}`, rowNum, col, 'Business')
                  })
                }

                Blank()

                // 右侧 3 列 D E F
                Row({ space: 12 }) {
                  ForEach(['D', 'E', 'F'], (col: string) => {
                    this.SeatItem(`${rowNum}${col}`, rowNum, col, 'Business')
                  })
                }

                // 右侧排号
                Text(`${rowNum}`)
                  .fontSize(11)
                  .fontColor('#94A3B8')
                  .width(16)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ left: 6, right: 6 })
            })
          }
          .width('100%')

          Divider().color('rgba(255, 255, 255, 0.08)')

          // 2c. 经济舱 Header
          Column({ space: 10 }) {
            Row() {
              Text('Economy')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
              Blank()
              Text('3 x 3 舒适座位')
                .fontSize(11)
                .fontColor('#94A3B8')
            }
            .width('100%')
            .padding({ left: 10, right: 10 })

            // 渲染经济舱排 3 ~ 7
            ForEach([3, 4, 5, 6, 7], (rowNum: number) => {
              Row() {
                Text(`${rowNum}`)
                  .fontSize(11)
                  .fontColor('#94A3B8')
                  .width(16)

                Row({ space: 12 }) {
                  ForEach(['A', 'B', 'C'], (col: string) => {
                    this.SeatItem(`${rowNum}${col}`, rowNum, col, 'Economy')
                  })
                }

                Blank()

                Row({ space: 12 }) {
                  ForEach(['D', 'E', 'F'], (col: string) => {
                    this.SeatItem(`${rowNum}${col}`, rowNum, col, 'Economy')
                  })
                }

                Text(`${rowNum}`)
                  .fontSize(11)
                  .fontColor('#94A3B8')
                  .width(16)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding({ left: 6, right: 6 })
            })
          }
          .width('100%')
        }
        .width('100%')
      }
      .height(340)
      .scrollBar(BarState.Off)

      // 3. 底部确认选座并完成值机按钮
      Row() {
        Column({ space: 2 }) {
          Text(`已选座位: ${this.selectedSeatId}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text(this.selectedSeatId.endsWith('A') || this.selectedSeatId.endsWith('F') ? '靠窗 · 视野绝佳' : '靠近过道 · 出入顺畅')
            .fontSize(10)
            .fontColor('#38BDF8')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 确认按钮
        Row({ space: 4 }) {
          Text('确认选座并值机')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#020617')
          Text('➔')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#020617')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#4ADE80')
        .borderRadius(20)
        .shadow({ radius: 12, color: 'rgba(74, 222, 128, 0.4)' })
        .onClick(() => {
          this.triggerHaptic();
          if (this.onConfirmSeat) {
            this.onConfirmSeat(this.selectedSeatId, this.selectedCabin);
          }
          this.controller?.close();
        })
      }
      .width('100%')
      .padding({ top: 6 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('rgba(10, 15, 26, 0.95)')
    .border({ width: 1, color: 'rgba(255, 255, 255, 0.15)', radius: 24 })
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.95)', offsetY: -10 })
  }

  private isSeatSelected(seatId: string): boolean {
    return this.selectedSeatId === seatId;
  }

  private isSeatOccupied(row: number, col: string): boolean {
    return (row === 1 && (col === 'A' || col === 'B')) || (row === 3 && col === 'C') || (row === 4 && col === 'F');
  }

  // 单个座位 1:1 对标图 1 的真实渲染 Item
  @Builder
  SeatItem(seatId: string, row: number, col: string, cabin: string) {
    Column() {
      if (this.isSeatSelected(seatId)) {
        // 当前选中状态：高亮 Cyber Blue #38BDF8 + 白色勾选标志 ✓
        Text('✓')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      } else {
        // 普通可用座 / 已占用座
        Column()
          .width(18)
          .height(10)
          .backgroundColor(this.isSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.15)' : 'rgba(255, 255, 255, 0.25)')
          .borderRadius({ topLeft: 3, topRight: 3 })
      }
    }
    .width(28)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isSeatSelected(seatId) ? '#38BDF8' : (this.isSeatOccupied(row, col) ? 'rgba(15, 23, 42, 0.6)' : 'rgba(255, 255, 255, 0.08)'))
    .border({
      width: this.isSeatSelected(seatId) ? 1.5 : (this.isSeatOccupied(row, col) ? 0.5 : 1),
      color: this.isSeatSelected(seatId) ? '#38BDF8' : (this.isSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.2)' : 'rgba(255, 255, 255, 0.2)'),
      radius: 6
    })
    .borderRadius(6)
    .shadow({ radius: this.isSeatSelected(seatId) ? 8 : 0, color: 'rgba(56, 189, 248, 0.6)' })
    .onClick(() => {
      if (this.isSeatOccupied(row, col)) return;
      this.selectedSeatId = seatId;
      this.selectedCabin = cabin;
      this.triggerHaptic();
    })
  }
}
