/**
 * 🎯 专注航程范围指示层
 * 纯净雅致测距圈：十字准星、内同心刻度圈与珊瑚红虚线范围圈。
 * 硬件加速渲染，完全穿透手势，无任何鬼畜波纹。
 */
@Component
export struct RadarScanOverlay {
  @Prop radius: number = 155;
  @Prop currentMinutes: number = 25;
  @Prop scanAngle: number = 0;
  @Prop scanBeamOpacity: number = 1.0;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 十字准星横纵刻度线 (极淡纯净)
      Row().width(this.radius * 2).height(1).backgroundColor('rgba(255, 255, 255, 0.08)')
      Column().width(1).height(this.radius * 2).backgroundColor('rgba(255, 255, 255, 0.08)')

      // 2. 内层同心距离刻度圈 (1/3 与 2/3)
      Stack()
        .width(this.radius * 2 * 0.36)
        .height(this.radius * 2 * 0.36)
        .borderRadius(this.radius * 0.36)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', style: BorderStyle.Solid })

      Stack()
        .width(this.radius * 2 * 0.70)
        .height(this.radius * 2 * 0.70)
        .borderRadius(this.radius * 0.70)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', style: BorderStyle.Solid })

      // 3. 外层主测距范围圈 (半透明珊瑚红虚线)
      Stack()
        .width(this.radius * 2)
        .height(this.radius * 2)
        .borderRadius(this.radius)
        .border({ width: 1.5, color: 'rgba(240, 101, 83, 0.45)', style: BorderStyle.Dashed })

      // 4. 动态 360° 旋转雷达扫频光束与渐变扇区 (随扫描进度旋转，单圈完成后平滑淡出)
      if (this.scanBeamOpacity > 0.01) {
        Stack({ alignContent: Alignment.TopStart }) {
          // 4a. 90° 余辉衰减渐变扇区
          Row()
            .width(this.radius * 2)
            .height(this.radius * 2)
            .borderRadius(this.radius)
            .sweepGradient({
              center: [this.radius, this.radius],
              start: 0,
              end: 360,
              colors: [
                ['rgba(240, 101, 83, 0.0)', 0.0],
                ['rgba(240, 101, 83, 0.0)', 0.72],
                ['rgba(240, 101, 83, 0.10)', 0.88],
                ['rgba(240, 101, 83, 0.32)', 1.0]
              ]
            })

          // 4b. 前导高亮扫频光束线 (与 sweepGradient 1.0 强边缘 100% 重合对齐)
          Row()
            .width(this.radius)
            .height(2)
            .linearGradient({
              angle: 90,
              colors: [
                ['rgba(240, 101, 83, 0.0)', 0.0],
                ['rgba(255, 255, 255, 0.95)', 0.70],
                ['#F06553', 1.0]
              ]
            })
            .position({ x: this.radius, y: this.radius })
            .markAnchor({ x: 0, y: 1 })
        }
        .width(this.radius * 2)
        .height(this.radius * 2)
        .rotate({ angle: this.scanAngle })
        .opacity(this.scanBeamOpacity)
      }
    }
    .width(this.radius * 2)
    .height(this.radius * 2)
    .hitTestBehavior(HitTestMode.None)
  }
}
