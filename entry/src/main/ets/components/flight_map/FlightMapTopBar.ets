import { vibrator } from '@kit.SensorServiceKit';

/**
 * 🎯 顶部航线状态条：左上角纯透水晶返回按钮（完全对齐精修机场地图 HUD 标准）
 */
@Component
export struct FlightMapTopBar {
  @Prop selectedCode: string = '';
  @Prop currentMinutes: number = 15;
  @Prop routeDistanceKm: number = 0;
  @Prop ctuScreenX: number = 0;
  @Prop ctuScreenY: number = 0;
  @Prop currentZoomLevel: number = 5.5;
  @Prop currentMapType: number = 2; // 默认 mapCommon.MapType.TERRAIN
  onClose?: () => void;
  onToggleMapType?: () => void;

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 15
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  build() {
    Row() {
      // 左侧：返回按钮 (完全对齐精修机场地图 HUD 水晶圆钮样式)
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_hw_back_white'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('rgba(15, 23, 42, 0.45)')
      .backdropBlur(25)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.16)', radius: 19 })
      .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        this.triggerHaptic();
        if (this.onClose) {
          this.onClose();
        }
      })

      Blank()

      // 右侧：图层切换按钮 (立体地形 / 标准矢量 / 卫星遥感)
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_map_layers_white'))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('rgba(15, 23, 42, 0.45)')
      .backdropBlur(25)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.16)', radius: 19 })
      .shadow({ radius: 10, color: 'rgba(0, 0, 0, 0.25)', offsetY: 2 })
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        this.triggerHaptic();
        if (this.onToggleMapType) {
          this.onToggleMapType();
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
