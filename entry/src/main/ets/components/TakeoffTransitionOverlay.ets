import { vibrator } from '@kit.SensorServiceKit';

/**
 * TakeoffTransitionOverlay.ets
 * 登机/起飞沉浸式过场过渡动画 (Takeoff & Cloud Piercing Transition)
 * 阶段 1：引擎推力拉满 + 动态仪表 (高度 0 -> 10,800m, 速度 0 -> 880km/h) + 纵向速度拉丝
 * 阶段 2：穿透高空云层 + 弥散雾气散开
 * 阶段 3：无缝入轨进入地图巡航视界
 */
@Component
export struct TakeoffTransitionOverlay {
  @Prop isVisible: boolean = false;
  @Prop originCode: string = 'TFU';
  @Prop destCode: string = 'CDG';
  @Prop flightNo: string = 'CA933';
  onFinish?: () => void;

  @State private animStep: number = 0; // 0: 点火起飞, 1: 穿透云层, 2: 完成
  @State private altitude: number = 0; // 0 ~ 10800 m
  @State private speed: number = 0; // 0 ~ 880 km/h
  @State private progressPercent: number = 0; // 0 ~ 100%
  
  @State private backdropOpacity: number = 0;
  @State private hudContentOpacity: number = 0;
  @State private hudScale: number = 0.9;
  @State private cloudScale: number = 0.6;
  @State private cloudOpacity: number = 0;
  @State private speedLineOffsetY: number = 0;

  private timerId: number = -1;
  private animationInterval: number = -1;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.startTakeoffSequence();
    }
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) clearTimeout(this.timerId);
    if (this.animationInterval !== -1) clearInterval(this.animationInterval);
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 35
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  private startTakeoffSequence(): void {
    this.triggerHaptic();
    this.animStep = 0;
    this.altitude = 0;
    this.speed = 0;
    this.progressPercent = 0;
    this.backdropOpacity = 0;
    this.hudContentOpacity = 0;
    this.cloudOpacity = 0;

    // 1. 全屏 HUD 淡入
    this.getUIContext()?.animateTo({
      duration: 300,
      curve: Curve.EaseOut
    }, () => {
      this.backdropOpacity = 1;
      this.hudContentOpacity = 1;
      this.hudScale = 1.0;
    });

    // 2. 模拟仪表数值加速飙升 (0 ~ 750ms)
    const totalSteps = 25;
    let stepCount = 0;
    this.animationInterval = setInterval(() => {
      stepCount++;
      const ratio = stepCount / totalSteps;
      // 缓增曲线
      const easedRatio = Math.pow(ratio, 1.8);
      this.altitude = Math.floor(easedRatio * 10800);
      this.speed = Math.floor(easedRatio * 880);
      this.progressPercent = Math.floor(ratio * 100);
      this.speedLineOffsetY = (stepCount * 18) % 100;

      if (stepCount >= totalSteps) {
        if (this.animationInterval !== -1) {
          clearInterval(this.animationInterval);
          this.animationInterval = -1;
        }
        this.enterCloudPiercingPhase();
      }
    }, 30);
  }

  private enterCloudPiercingPhase(): void {
    this.animStep = 1;
    this.triggerHaptic();

    // 云层爆炸式从中心向外散开淡出 (800 ~ 1300ms)
    this.getUIContext()?.animateTo({
      duration: 500,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.cloudScale = 2.4;
      this.cloudOpacity = 0.9;
      this.hudContentOpacity = 0;
      this.hudScale = 1.15;
    });

    // 随后全屏渐隐揭开地图
    this.timerId = setTimeout(() => {
      this.getUIContext()?.animateTo({
        duration: 400,
        curve: Curve.EaseInOut,
        onFinish: () => {
          this.animStep = 2;
          if (this.onFinish) {
            this.onFinish();
          }
        }
      }, () => {
        this.backdropOpacity = 0;
        this.cloudOpacity = 0;
      });
    }, 450);
  }

  build() {
    if (this.isVisible && this.animStep < 2) {
      Stack({ alignContent: Alignment.Center }) {
        // 1. 深邃暗夜背景 + 赛博蓝高斯模糊
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(2, 6, 23, 0.92)')
          .backdropBlur(25)
          .opacity(this.backdropOpacity)

        // 2. 纵向速度光丝 (Speed Lines)
        Stack({ alignContent: Alignment.Top }) {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (idx: number) => {
            Row()
              .width(2)
              .height(120 + idx * 25)
              .backgroundColor('rgba(56, 189, 248, 0.25)')
              .position({
                x: `${12 + idx * 11}%`,
                y: `${(this.speedLineOffsetY + idx * 15) % 100}%`
              })
              .borderRadius(1)
          })
        }
        .width('100%')
        .height('100%')
        .opacity(this.hudContentOpacity * 0.7)
        .hitTestBehavior(HitTestMode.None)

        // 3. 中央战术起飞 HUD 核心挂件
        Column({ space: 24 }) {
          // A. 顶部战术指令标识
          Row({ space: 8 }) {
            Text('⚡')
              .fontSize(16)
            Text('CLEARED FOR TAKEOFF · 推力升空')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')
              .letterSpacing(1.5)
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('rgba(56, 189, 248, 0.12)')
          .border({ width: 1, color: 'rgba(56, 189, 248, 0.4)', radius: 20 })
          .borderRadius(20)
          .shadow({ radius: 12, color: 'rgba(56, 189, 248, 0.3)' })

          // B. 机体飞行起飞 Icon + 能量环
          Stack({ alignContent: Alignment.Center }) {
            // 外围能量圆环
            Column()
              .width(130)
              .height(130)
              .borderRadius(65)
              .border({ width: 2, color: 'rgba(56, 189, 248, 0.35)', style: BorderStyle.Dashed })

            // 内侧核心亮圈
            Column()
              .width(100)
              .height(100)
              .borderRadius(50)
              .backgroundColor('rgba(14, 165, 233, 0.15)')
              .border({ width: 1, color: '#38BDF8' })
              .shadow({ radius: 20, color: 'rgba(56, 189, 248, 0.5)' })

            // 飞向天空图标
            Text('✈️')
              .fontSize(48)
              .rotate({ angle: -45 }) // 战机仰角向上起飞姿态
          }

          // C. 航线起终点与航班号
          Row({ space: 12 }) {
            Text(this.originCode)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
            
            Text('➔')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')

            Text(this.destCode)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
          }

          // D. 仪表盘双数据 (高度 & 速度)
          Row({ space: 24 }) {
            // 高度仪表
            Column({ space: 4 }) {
              Text('ALTITUDE / 高度')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#94A3B8')
              Row({ space: 2 }) {
                Text(`${this.altitude}`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4ADE80')
                Text('m')
                  .fontSize(12)
                  .fontColor('#4ADE80')
                  .margin({ bottom: 3 })
              }
              .alignItems(VerticalAlign.Bottom)
            }
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('rgba(15, 23, 42, 0.85)')
            .border({ width: 1, color: 'rgba(74, 222, 128, 0.3)' })
            .borderRadius(12)

            // 速度仪表
            Column({ space: 4 }) {
              Text('SPEED / 时速')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('#94A3B8')
              Row({ space: 2 }) {
                Text(`${this.speed}`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#38BDF8')
                Text('km/h')
                  .fontSize(12)
                  .fontColor('#38BDF8')
                  .margin({ bottom: 3 })
              }
              .alignItems(VerticalAlign.Bottom)
            }
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('rgba(15, 23, 42, 0.85)')
            .border({ width: 1, color: 'rgba(56, 189, 248, 0.3)' })
            .borderRadius(12)
          }

          // E. 进度条
          Column({ space: 6 }) {
            Row() {
              Text('INTO CRUISE ORBIT / 正在穿透云层...')
                .fontSize(11)
                .fontColor('#94A3B8')
              Blank()
              Text(`${this.progressPercent}%`)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#38BDF8')
            }
            .width(260)

            // 自定义胶囊进度条
            Stack({ alignContent: Alignment.Start }) {
              Column()
                .width('100%')
                .height(6)
                .backgroundColor('rgba(255, 255, 255, 0.12)')
                .borderRadius(3)

              Column()
                .width(`${this.progressPercent}%`)
                .height(6)
                .backgroundColor('#38BDF8')
                .borderRadius(3)
                .shadow({ radius: 8, color: '#38BDF8' })
            }
            .width(260)
          }
        }
        .scale({ x: this.hudScale, y: this.hudScale })
        .opacity(this.hudContentOpacity)

        // 4. 云破天开 / 云雾弥散炸裂效果 (Cloud Piercing)
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(240)
            .height(240)
            .borderRadius(120)
            .backgroundColor('rgba(248, 250, 252, 0.85)')
            .backdropBlur(30)
            .scale({ x: this.cloudScale, y: this.cloudScale })
            .opacity(this.cloudOpacity)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .height('100%')
      .zIndex(10000)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
