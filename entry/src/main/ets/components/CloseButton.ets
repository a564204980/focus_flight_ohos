/**
 * CloseButton.ets
 * Focus Flight 通用几何绘制关闭按钮
 */
@Component
export struct CloseButton {
  @Prop circleColor: ResourceColor = '#F3F4F6';
  @Prop iconColor: ResourceColor = '#111827';
  buttonSize: number = 32;
  onClickAction?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.buttonSize)
        .height(this.buttonSize)
        .backgroundColor(this.circleColor)
        .borderRadius(this.buttonSize / 2)
      
      Stack({ alignContent: Alignment.Center }) {
        Rect().width(13.5).height(2.2).radius(1).fill(this.iconColor).rotate({ angle: 45 })
        Rect().width(13.5).height(2.2).radius(1).fill(this.iconColor).rotate({ angle: -45 })
      }
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .onClick(() => {
      if (this.onClickAction) {
        this.onClickAction();
      }
    })
  }
}
