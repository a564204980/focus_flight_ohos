import { vibrator } from '@kit.SensorServiceKit';

/**
 * BackButton.ets
 * Focus Flight 通用 HUD 纯透玻璃质感返回按钮公共组件
 */
@Component
export struct BackButton {
  @Prop opacityValue: number = 1.0;
  buttonSize: number = 38;
  topOffset: number = 52;
  leftOffset: number = 16;
  btnBorderColor: ResourceColor = 'rgba(255, 255, 255, 0.35)';
  btnBorderWidth: number = 1.5;
  onClickAction?: () => void;

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
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.ic_back_btn'))
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .backgroundColor('transparent')
    .border({ width: this.btnBorderWidth, color: this.btnBorderColor, radius: this.buttonSize / 2 })
    .borderRadius(this.buttonSize / 2)
    .backdropBlur(16)
    .position({ x: this.leftOffset, y: this.topOffset })
    .opacity(this.opacityValue)
    .scale({
      x: 0.7 + 0.3 * this.opacityValue,
      y: 0.7 + 0.3 * this.opacityValue
    })
    .translate({ y: (1 - this.opacityValue) * -12 })
    .zIndex(10000)
    .onClick(() => {
      this.triggerHaptic();
      if (this.onClickAction) {
        this.onClickAction();
      }
    })
  }
}
