/**
 * TimeRulerPicker.ets
 * Focus Flight 专注时间交互刻度尺组件
 * 大数字原位融入刻度盘 + 选中的刻度数字加粗放大 + 零像素精准中轴对齐
 */

@Component
export struct TimeRulerPicker {
  @Prop timerMinutes: number = 45; // 当前选择的专注时长
  onTimeChange?: (minutes: number) => void; // 选定时间变更回调

  private scroller: Scroller = new Scroller();

  private readonly minMinutes: number = 15;
  private readonly maxMinutes: number = 180;
  private readonly stepMinutes: number = 5;
  private readonly stepWidth: number = 22; // 每个 5分钟 刻度的间距 (vp)
  
  // 34个刻度索引 [0..33]
  @State private stepIndices: number[] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33
  ];

  // 根据索引获取分钟数
  private getMinutesByIndex(index: number): number {
    const val = this.minMinutes + index * this.stepMinutes;
    if (isNaN(val)) {
      return 45;
    }
    return Math.min(this.maxMinutes, Math.max(this.minMinutes, val));
  }

  // 根据分钟数获取索引
  private getIndexByMinutes(min: number): number {
    const safeMin = isNaN(min) ? 45 : min;
    const clamped = Math.min(this.maxMinutes, Math.max(this.minMinutes, safeMin));
    return Math.round((clamped - this.minMinutes) / this.stepMinutes);
  }

  // 安全设置 timerMinutes 防止 NaN
  private safeUpdateMinutes(min: number) {
    if (!isNaN(min) && min >= this.minMinutes && min <= this.maxMinutes) {
      const rounded = Math.round(min);
      if (this.timerMinutes !== rounded) {
        this.timerMinutes = rounded;
        if (this.onTimeChange) {
          this.onTimeChange(this.timerMinutes);
        }
      }
    }
  }

  // 点击或磁吸滚动到目标索引
  private scrollToIndex(index: number, smooth: boolean = true) {
    const validIndex = Math.max(0, Math.min(this.stepIndices.length - 1, index));
    const targetOffset = validIndex * this.stepWidth;
    const finalMin = this.getMinutesByIndex(validIndex);
    this.safeUpdateMinutes(finalMin);

    this.scroller.scrollTo({
      xOffset: targetOffset,
      yOffset: 0,
      animation: smooth ? { duration: 250, curve: Curve.EaseOut } : undefined
    });
  }

  aboutToAppear() {
    // 组件加载完成后延时滚动到初始 45 分钟位置
    setTimeout(() => {
      const initialMin = isNaN(this.timerMinutes) ? 45 : this.timerMinutes;
      const idx = this.getIndexByMinutes(initialMin);
      this.scrollToIndex(idx, false);
    }, 50);
  }

  @Builder
  RulerItem(index: number) {
    Column() {
      // 1. 刻度数值：选中项用 64vp 居中 Row 展开大字，配合 clip(false) 确保 85/120 完整显示不被裁切
      if (this.timerMinutes === this.getMinutesByIndex(index)) {
        Row() {
          Text(`${this.getMinutesByIndex(index)}`)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FA6B56')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.None })
        }
        .width(64)
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 2 })
      } else if (this.getMinutesByIndex(index) % 15 === 0) {
        Text(`${this.getMinutesByIndex(index)}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#64748B')
          .maxLines(1)
          .margin({ bottom: 4 })
      } else {
        Row().height(16) // 占位保持高度对齐
      }

      // 2. 刻度线 (选中刻度为暖珊瑚红高亮线)
      Column()
        .width(this.timerMinutes === this.getMinutesByIndex(index) ? 2.5 : 1.5)
        .height(this.timerMinutes === this.getMinutesByIndex(index) ? 16 : (this.getMinutesByIndex(index) % 15 === 0 ? 14 : 8))
        .backgroundColor(
          this.timerMinutes === this.getMinutesByIndex(index) ? '#FA6B56' : 
          (this.getMinutesByIndex(index) % 15 === 0 ? '#94A3B8' : 'rgba(148, 163, 184, 0.45)')
        )
        .borderRadius(1)
    }
    .width(this.stepWidth)
    .height(56)
    .clip(false) // 允许选中的 64vp 大字向两侧自然展开，防止被 22vp 容器裁切
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.scrollToIndex(index, true);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 鸿蒙原生水平 Scroll 组件
      Scroll(this.scroller) {
        Row() {
          // 头部占位：50% 减去 11vp 偏移，确保选中的刻度线 100% 居中在屏幕正中央中轴线上
          Row().width('50%').margin({ right: -11 })

          ForEach(this.stepIndices, (index: number) => {
            this.RulerItem(index)
          }, (index: number) => `${index}`)

          // 尾部占位
          Row().width('50%').margin({ left: -11 })
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height(56)
      .onDidScroll(() => {
        // 实时获取滚动偏移量计算当前刻度
        const currentX = this.scroller.currentOffset().xOffset;
        if (!isNaN(currentX)) {
          const nearestIndex = Math.round(currentX / this.stepWidth);
          const validIndex = Math.max(0, Math.min(this.stepIndices.length - 1, nearestIndex));
          const newMin = this.getMinutesByIndex(validIndex);
          this.safeUpdateMinutes(newMin);
        }
      })
      .onScrollStop(() => {
        // 滚动停止时平滑磁吸停靠至最近刻度
        const currentX = this.scroller.currentOffset().xOffset;
        if (!isNaN(currentX)) {
          const nearestIndex = Math.round(currentX / this.stepWidth);
          this.scrollToIndex(nearestIndex, true);
        }
      })
    }
    .width('100%')
    .height(56)
    .clip(false)
    .margin({ top: 2, bottom: 6 })
  }
}
