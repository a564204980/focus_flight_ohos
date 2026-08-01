import { vibrator } from '@kit.SensorServiceKit';

/**
 * GiantAircraftOverlay.ets
 * 战术机体准备遮罩层，使用本地图片素材展示机体
 */

@Component
export struct GiantAircraftOverlay {
  @Prop isVisible: boolean = false;
  @Prop flightNo: string = 'CA933';
  @Prop originCode: string = 'TFU';
  @Prop destCode: string = 'CDG';
  @Prop backdropOpacity: number = 0;
  @Prop bodyOffsetY: string = '100%';
  @State selectedSeatId: string = '1F';
  onConfirmSeat?: (seatId: string) => void;
  onClose?: () => void;

  private scroller: Scroller = new Scroller();

  // 模拟已占用座位 (不可选)
  private occupiedSeats: Array<string> = ['1B', '2E', '4A', '5F', '6B', '8C', '9E', '12B', '14F'];

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

  // 渲染图 1 风格的精细矢量座椅组件 (无论是否选中均保持双侧扶手结构完整)
  @Builder
  renderFig1Seat(seatId: string) {
    Row() {
      Column({ space: 3 }) {
        // 1. 座椅靠背与双侧扶手主体
        Row({ space: 2 }) {
          // 左扶手
          Column()
            .width(3.5)
            .height(24)
            .backgroundColor(
              this.selectedSeatId === seatId ? '#007AFF' :
              (this.occupiedSeats.includes(seatId) ? 'rgba(255, 255, 255, 0.12)' : 'rgba(255, 255, 255, 0.45)')
            )
            .borderRadius(1.5)

          // 靠背主体
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(
                this.selectedSeatId === seatId ? '#007AFF' :
                (this.occupiedSeats.includes(seatId) ? 'rgba(255, 255, 255, 0.08)' : 'rgba(255, 255, 255, 0.28)')
              )
              .borderRadius(3)

            if (this.selectedSeatId === seatId) {
              Text('✓')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
          }
          .width(23)
          .height(26)

          // 右扶手
          Column()
            .width(3.5)
            .height(24)
            .backgroundColor(
              this.selectedSeatId === seatId ? '#007AFF' :
              (this.occupiedSeats.includes(seatId) ? 'rgba(255, 255, 255, 0.12)' : 'rgba(255, 255, 255, 0.45)')
            )
            .borderRadius(1.5)
        }
        .alignItems(VerticalAlign.Center)

        // 2. 座椅底部坐垫横条
        Column()
          .width(36)
          .height(5)
          .backgroundColor(
            this.selectedSeatId === seatId ? '#007AFF' :
            (this.occupiedSeats.includes(seatId) ? 'rgba(255, 255, 255, 0.12)' : 'rgba(255, 255, 255, 0.45)')
          )
          .borderRadius(1.5)
      }
    }
    .width(38)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.occupiedSeats.includes(seatId)) {
        return;
      }
      this.triggerHaptic();
      this.selectedSeatId = seatId;
      if (this.onConfirmSeat) {
        this.onConfirmSeat(seatId);
      }
    })
  }

  // 渲染单排 2x2 座椅行组件
  @Builder
  renderSeatRow(rowNum: number) {
    Row() {
      Text('').width(20) // 左侧镜像平衡占位 (保证距离左侧壁绝对对称)
      Row({ space: 8 }) {
        this.renderFig1Seat(`${rowNum}A`)
        this.renderFig1Seat(`${rowNum}B`)
      }
      .margin({ right: 38 }) // 加宽过道 (38vp)

      Row({ space: 8 }) {
        this.renderFig1Seat(`${rowNum}E`)
        this.renderFig1Seat(`${rowNum}F`)
      }
      .margin({ right: 6 }) // 排号往左靠拢 (紧贴 F 座)

      Text(`${rowNum}`).fontSize(11).fontColor('#94A3B8').width(16).textAlign(TextAlign.Center)
      Text('').width(14) // 右侧镜像平衡补齐
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 全屏固定静止高斯模糊背景层 (屏蔽空白区域点击收起)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(2, 6, 23, 0.45)')
        .backdropBlur(20)
        .opacity(this.backdropOpacity)

      // 2. 可长距离上下手势滑动的战术机体与机舱选座区
      Scroll(this.scroller) {
        Column() {
          Stack({ alignContent: Alignment.Top }) {
            // 2a. SVG 飞机底图 (加大延伸尺寸，向下微调平移 980vp)
            Image($r('app.media.aircraft_top_view'))
              .width('100%')
              .aspectRatio(1)
              .objectFit(ImageFit.Contain)
              .scale({ x: 8.8, y: 8.8 })
              .offset({ y: 980 })

            // 2b. 可滑动多排战术 Seats 布局 (初始向下偏移 240vp，包含 26 排 Seats)
            Column({ space: 8 }) {
              // 顶部列字母标识 (A  B   |过道|   E  F)
              Row() {
                Text('').width(20)
                Row({ space: 8 }) {
                  Text('A').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                  Text('B').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                }
                .margin({ right: 38 })

                Row({ space: 8 }) {
                  Text('E').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                  Text('F').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                }
                .margin({ right: 6 })

                Text('').width(16)
                Text('').width(14)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)

              // 1 ~ 26 排座椅网格，随时滑动阅览
              this.renderSeatRow(1)
              this.renderSeatRow(2)
              this.renderSeatRow(3)
              this.renderSeatRow(4)
              this.renderSeatRow(5)
              this.renderSeatRow(6)
              this.renderSeatRow(7)
              this.renderSeatRow(8)
              this.renderSeatRow(9)
              this.renderSeatRow(10)
              this.renderSeatRow(11)
              this.renderSeatRow(12)
              this.renderSeatRow(13)
              this.renderSeatRow(14)
              this.renderSeatRow(15)
              this.renderSeatRow(16)
              this.renderSeatRow(17)
              this.renderSeatRow(18)
              this.renderSeatRow(19)
              this.renderSeatRow(20)
              this.renderSeatRow(21)
              this.renderSeatRow(22)
              this.renderSeatRow(23)
              this.renderSeatRow(24)
              this.renderSeatRow(25)
              this.renderSeatRow(26)
            }
            .width('100%')
            .padding({ top: 10, bottom: 50 })
            .offset({ y: 240 })
          }
          .width('100%')
          .height(1480)
          .margin({ top: 50 })
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .translate({ y: this.bodyOffsetY })
      .hitTestBehavior(HitTestMode.Default)
    }
    .width('100%')
    .height('100%')
    .zIndex(9999)
    .position({ x: 0, y: 0 })
  }
}

