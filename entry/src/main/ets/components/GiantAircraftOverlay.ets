import { vibrator } from '@kit.SensorServiceKit';
import { BackButton } from './BackButton';
import { SeatSelectBoardingDialog } from './SeatSelectBoardingDialog';

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
  @State selectedSeatId: string = '';
  onConfirmSeat?: (seatId: string, taskTitle: string, durationMin: number) => void;
  onClose?: () => void;

  private scroller: Scroller = new Scroller();
  private dialogController: CustomDialogController | null = null;

  // 所有座位均开放选择 (无占用限制)
  private occupiedSeats: Array<string> = [];

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

  private openBoardingDialog(seatId: string): void {
    this.selectedSeatId = seatId;
    this.dialogController = new CustomDialogController({
      builder: SeatSelectBoardingDialog({
        seatId: seatId,
        flightNo: this.flightNo,
        originCode: this.originCode,
        destCode: this.destCode,
        onConfirmSeat: (sId: string, taskTitle: string, dur: number) => {
          if (this.dialogController) {
            this.dialogController.close();
          }
          if (this.onConfirmSeat) {
            this.onConfirmSeat(sId, taskTitle, dur);
          }
          if (this.onClose) {
            this.onClose();
          }
        }
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      offset: { dx: 0, dy: 0 }
    });
    this.dialogController.open();
  }

  // 渲染图 1 风格的精细矢量座椅组件 (全舱座位开放点选)
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
              this.selectedSeatId === seatId ? '#0EA5E9' : 'rgba(255, 255, 255, 0.45)'
            )
            .borderRadius(1.5)

          // 靠背主体
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(
                this.selectedSeatId === seatId ? '#0EA5E9' : 'rgba(255, 255, 255, 0.28)'
              )
              .borderRadius(3)

            if (this.selectedSeatId === seatId) {
              Text('✓')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
            }
          }
          .width(23)
          .height(26)

          // 右扶手
          Column()
            .width(3.5)
            .height(24)
            .backgroundColor(
              this.selectedSeatId === seatId ? '#0EA5E9' : 'rgba(255, 255, 255, 0.45)'
            )
            .borderRadius(1.5)
        }
        .alignItems(VerticalAlign.Center)

        // 2. 座椅底部坐垫横条
        Column()
          .width(36)
          .height(5)
          .backgroundColor(
            this.selectedSeatId === seatId ? '#0EA5E9' : 'rgba(255, 255, 255, 0.45)'
          )
          .borderRadius(1.5)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(38)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.triggerHaptic();
      this.openBoardingDialog(seatId);
    })
  }

  // 渲染单排 2x2 座椅行组件 (AB列与EF列围绕中心轴绝对对称，左右两侧边距完全一致)
  @Builder
  renderSeatRow(rowNum: number) {
    Row() {
      // 左侧 AB 座椅组 (总宽 84vp)
      Row({ space: 8 }) {
        this.renderFig1Seat(`${rowNum}A`)
        this.renderFig1Seat(`${rowNum}B`)
      }

      // 中间过道排号标识 (总宽 48vp，精准居中)
      Text(`${rowNum}`)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(148, 163, 184, 0.6)')
        .width(48)
        .textAlign(TextAlign.Center)

      // 右侧 EF 座椅组 (总宽 84vp)
      Row({ space: 8 }) {
        this.renderFig1Seat(`${rowNum}E`)
        this.renderFig1Seat(`${rowNum}F`)
      }
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
            // 2a. SVG 飞机底图 (保持 8.8 倍放大，向下适当平移 1260vp，确保顶部机头尖角完整可见)
            Image($r('app.media.aircraft_top_view'))
              .width('100%')
              .aspectRatio(1)
              .objectFit(ImageFit.Contain)
              .scale({ x: 8.8, y: 8.8 })
              .offset({ y: 1260 })

            // 2b. 可滑动多排战术 Seats 布局 (向下平移 520vp 精准对齐机舱，包含 26 排 Seats)
            Column({ space: 8 }) {
              // 顶部列字母标识 (A  B   |过道|   E  F，对称居中对齐)
              Row() {
                Row({ space: 8 }) {
                  Text('A').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                  Text('B').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                }

                Text('过道').fontSize(9).fontColor('rgba(148, 163, 184, 0.4)').width(48).textAlign(TextAlign.Center)

                Row({ space: 8 }) {
                  Text('E').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                  Text('F').fontSize(11).fontColor('#94A3B8').width(38).textAlign(TextAlign.Center)
                }
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
            .offset({ y: 520 })
          }
          .width('100%')
          .height(1760)
          .margin({ top: 30 })
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .translate({ y: this.bodyOffsetY })
      .hitTestBehavior(HitTestMode.Default)

      // 3. 左上角复用 HUD 纯透玻璃质感 BackButton 公共组件
      BackButton({
        opacityValue: this.backdropOpacity,
        onClickAction: () => {
          if (this.onClose) {
            this.onClose();
          }
        }
      })
    }
    .width('100%')
    .height('100%')
    .zIndex(9999)
    .position({ x: 0, y: 0 })
  }
}

