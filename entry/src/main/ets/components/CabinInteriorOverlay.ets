import { vibrator } from '@kit.SensorServiceKit';

/**
 * CabinInteriorOverlay.ets
 * Focus Flight - 全景波音 737 客舱透视图层
 * 铺满空间 3-3 (A B C | D E F) 10 排完整排布 (1~10排) + 加宽中央过道 (36vp) + 前后排舒适间距 + 36x36 战术座椅
 * 支持点击座椅触发 onSeatClick 回调，联动飞机平滑缩小与背后地图展现
 */

@Component
export struct CabinInteriorOverlay {
  @State selectedSeatId: string = '1F';
  onSeatClick: (seatId: string) => void = (_seatId: string) => {};

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
    Stack({ alignContent: Alignment.Center }) {
      // 1. 机舱底座背景 (100% 还原图1酷蓝灰地毯颜色 #5B6B7C)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#5B6B7C') // 100% 还原图1酷蓝灰机舱地毯颜色
        .border({ width: 1.5, color: 'rgba(255, 255, 255, 0.25)', radius: 24 })
        .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.35)', offsetY: 4 })

      // 2. 充实铺满空间的 3-3 客舱排布（共 10 排全景视角）
      Column({ space: 7 }) {
        // 座椅列标题：A B C  |  (加宽过道)  |  D E F
        Row() {
          Row({ space: 4 }) {
            Text('A').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#E2E8F0').width(36).textAlign(TextAlign.Center)
            Text('B').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#E2E8F0').width(36).textAlign(TextAlign.Center)
            Text('C').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#E2E8F0').width(36).textAlign(TextAlign.Center)
          }

          Blank().width(36) // 加宽中央过道宽度

          Row({ space: 4 }) {
            Text('D').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#E2E8F0').width(36).textAlign(TextAlign.Center)
            Text('E').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#E2E8F0').width(36).textAlign(TextAlign.Center)
            Text('F').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#E2E8F0').width(36).textAlign(TextAlign.Center)
          }
        }
        .margin({ top: 12, bottom: 2 })

        // 座椅行 1 ~ 10 排
        ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], (rowNum: number) => {
          Row() {
            // 左侧 3 座 A, B, C
            Row({ space: 4 }) {
              this.IllustrativeSeatTile(`${rowNum}A`)
              this.IllustrativeSeatTile(`${rowNum}B`)
              this.IllustrativeSeatTile(`${rowNum}C`)
            }

            // 中央过道：放排号数字 (1 ~ 10，宽敞 36vp)
            Text(`${rowNum}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#CBD5E1')
              .width(36)
              .textAlign(TextAlign.Center)

            // 右侧 3 座 D, E, F
            Row({ space: 4 }) {
              this.IllustrativeSeatTile(`${rowNum}D`)
              this.IllustrativeSeatTile(`${rowNum}E`)
              this.IllustrativeSeatTile(`${rowNum}F`)
            }
          }
          .alignItems(VerticalAlign.Center)
        })
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  // 单个 36x36 战术座椅组件（支持选中高亮与点击响应）
  @Builder
  IllustrativeSeatTile(seatId: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Stack({ alignContent: Alignment.Bottom }) {
          // 座椅靠背 (选中高亮为 Cyber Cyan #38BDF8，未选为深蓝灰)
          Row() {
            // 左扶手线
            Row()
              .width(3.5)
              .height('84%')
              .backgroundColor(this.selectedSeatId === seatId ? '#FFFFFF' : '#CBD5E1')
              .borderRadius(1.5)

            Blank()

            // 右扶手线
            Row()
              .width(3.5)
              .height('84%')
              .backgroundColor(this.selectedSeatId === seatId ? '#FFFFFF' : '#CBD5E1')
              .borderRadius(1.5)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 2, right: 2 })
          .backgroundColor(this.selectedSeatId === seatId ? '#38BDF8' : '#0F172A')
          .border({
            width: this.selectedSeatId === seatId ? 1.8 : 1.2,
            color: this.selectedSeatId === seatId ? '#38BDF8' : 'rgba(203, 213, 225, 0.4)',
            radius: 6
          })
          .borderRadius(6)

          // 底部浅色座垫横条
          Row()
            .width('100%')
            .height(6)
            .backgroundColor(this.selectedSeatId === seatId ? '#4ADE80' : '#E2E8F0')
            .borderRadius({ bottomLeft: 5, bottomRight: 5 })
        }
        .width(36)
        .height(36)
        .shadow({
          radius: this.selectedSeatId === seatId ? 10 : 5,
          color: this.selectedSeatId === seatId ? 'rgba(56, 189, 248, 0.65)' : 'rgba(0, 0, 0, 0.3)',
          offsetY: 2
        })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(36)
    .height(36)
    .onClick(() => {
      this.selectedSeatId = seatId;
      this.triggerHaptic();
      if (this.onSeatClick) {
        this.onSeatClick(seatId);
      }
    })
  }
}

