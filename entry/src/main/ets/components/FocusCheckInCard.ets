import { common } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';
import { LocationService } from '../services/LocationService';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { AirportSelectDialog } from './AirportSelectDialog';
import { FlightSearchDialog } from './FlightSearchDialog';
import { FlightInfo } from '../services/FlightService';

/**
 * FocusCheckInCard.ets
 * 专注航班值机卡片 (Focus Check-in Card)
 * 纯净默认未选择目的地，用户自主挑选或搜索真实航班后开启专注航线
 */

@Component
export struct FocusCheckInCard {
  onOriginAirportChanged?: (airport: Airport) => void;
  onRouteChanged?: (origin: Airport, dest: Airport | null) => void;

  @State originCode: string = 'CTU';
  @State originCity: string = '成都 (定位中)';
  @State destCode: string = '---';
  @State destCity: string = '请选择目的地';
  @State flightNo: string = 'CA---';
  @State focusMinutesVal: number = 45;
  @State focusMinutes: string = '45 分钟';
  @State estDistance: string = '-- KM';
  @State isCheckIn: boolean = false;
  @State isLocating: boolean = false;
  @State isDestSelected: boolean = false;
  @State sliderTrackWidth: number = 300;
  @State planeXOffset: number = 0;
  @State planeYOffset: number = 0;
  @State planeScale: number = 1.0;
  @State planeRotate: number = 90;
  @State planeOpacity: number = 0.92;
  @State dashLineOffset: number = 0;

  private planeAnimTimer: number = -1;
  private lineFlowTimer: number = -1;

  private currentOriginAirport: Airport | null = null;
  @State currentDestAirport: Airport | null = null;

  // 4. 战术刻度尺水平 Scroller 控制器
  private rulerScroller: Scroller = new Scroller();
  private isRulerScrolledInit: boolean = false;

  // 1. 出发机场选择 Bottom Sheet 抽屉 Controller
  private originDialogController: CustomDialogController = new CustomDialogController({
    builder: AirportSelectDialog({
      title: '选择出发机场',
      currentCode: this.originCode,
      onSelectAirport: (airport: Airport) => {
        this.selectOriginAirport(airport);
      }
    }),
    alignment: DialogAlignment.Bottom,
    maskColor: 'rgba(2, 6, 23, 0.85)',
    customStyle: true,
    offset: { dx: 0, dy: 0 }
  });

  // 2. 目的机场选择 Bottom Sheet 抽屉 Controller
  private destDialogController: CustomDialogController = new CustomDialogController({
    builder: AirportSelectDialog({
      title: '选择到达机场',
      currentCode: this.destCode,
      onSelectAirport: (airport: Airport) => {
        this.selectDestAirport(airport);
      }
    }),
    alignment: DialogAlignment.Bottom,
    maskColor: 'rgba(2, 6, 23, 0.85)',
    customStyle: true,
    offset: { dx: 0, dy: 0 }
  });

  // 3. 真实航班实时搜索 Bottom Sheet 抽屉 Controller
  private flightSearchController: CustomDialogController = new CustomDialogController({
    builder: FlightSearchDialog({
      onSelectFlight: (flight: FlightInfo) => {
        this.selectFlight(flight);
      }
    }),
    alignment: DialogAlignment.Bottom,
    maskColor: 'rgba(2, 6, 23, 0.85)',
    customStyle: true,
    offset: { dx: 0, dy: 0 }
  });

  aboutToAppear(): void {
    this.refreshNearestLocation();
    this.startPlaneOrganicAnimation();
    this.startLineFlowAnimation();
  }

  aboutToDisappear(): void {
    if (this.planeAnimTimer !== -1) {
      clearTimeout(this.planeAnimTimer);
      this.planeAnimTimer = -1;
    }
    if (this.lineFlowTimer !== -1) {
      clearInterval(this.lineFlowTimer);
      this.lineFlowTimer = -1;
    }
  }

  private startPlaneOrganicAnimation(): void {
    const runTurbulence = () => {
      // 随机周期: 1200ms ~ 2200ms
      const duration = 1200 + Math.floor(Math.random() * 1000);
      // 随机 X/Y/Scale/Pitch 参数 (有机高空飞行感)
      const targetX = (Math.random() * 12) - 6;      // -6 ~ +6vp
      const targetY = (Math.random() * 4) - 2;       // -2 ~ +2vp
      const targetScale = 0.90 + (Math.random() * 0.24); // 0.90 ~ 1.14 深度纵深感
      const targetRotate = 88 + (Math.random() * 4); // 88° ~ 92° 姿态微倾斜
      const targetOpacity = 0.82 + (Math.random() * 0.18);

      this.getUIContext()?.animateTo({ duration: duration, curve: Curve.EaseInOut }, () => {
        this.planeXOffset = targetX;
        this.planeYOffset = targetY;
        this.planeScale = targetScale;
        this.planeRotate = targetRotate;
        this.planeOpacity = targetOpacity;
      });

      this.planeAnimTimer = setTimeout(runTurbulence, duration);
    };

    runTurbulence();
  }

  private startLineFlowAnimation(): void {
    const animateLine = () => {
      this.dashLineOffset = 0;
      this.getUIContext()?.animateTo({ duration: 550, curve: Curve.Linear }, () => {
        this.dashLineOffset = -9; // DashArray (5+4=9) 航线向左后退流动 (匹配飞机向右飞行 ➔)
      });
    };

    animateLine();
    this.lineFlowTimer = setInterval(animateLine, 550);
  }

  private selectFlight(flight: FlightInfo): void {
    this.currentOriginAirport = flight.originAirport;
    this.currentDestAirport = flight.destAirport;
    this.isDestSelected = true;

    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      this.originCode = flight.originAirport.code;
      this.originCity = flight.originAirport.city;
      this.destCode = flight.destAirport.code;
      this.destCity = flight.destAirport.city;
      this.flightNo = flight.flightNo;
      this.recalculateDistance();
    });

    if (this.onRouteChanged) {
      this.onRouteChanged(flight.originAirport, flight.destAirport);
    }
  }

  private selectOriginAirport(airport: Airport): void {
    this.currentOriginAirport = airport;
    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      this.originCode = airport.code;
      this.originCity = airport.city;
      this.recalculateDistance();
    });

    if (this.onRouteChanged) {
      this.onRouteChanged(airport, this.currentDestAirport);
    } else if (this.onOriginAirportChanged) {
      this.onOriginAirportChanged(airport);
    }
  }

  private selectDestAirport(airport: Airport): void {
    this.currentDestAirport = airport;
    this.isDestSelected = true;
    this.getUIContext()?.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      this.destCode = airport.code;
      this.destCity = airport.city;
      this.flightNo = `CA${Math.floor(100 + Math.random() * 900)}`;
      this.recalculateDistance();
    });

    const origin = this.currentOriginAirport || findAirportByCode(this.originCode);
    if (origin && this.onRouteChanged) {
      this.onRouteChanged(origin, airport);
    }
  }

  private recalculateDistance(): void {
    const origin = this.currentOriginAirport || findAirportByCode(this.originCode);
    const dest = this.currentDestAirport;
    if (origin && dest) {
      const dist = getDistanceKm(origin.lat, origin.lon, dest.lat, dest.lon);
      this.estDistance = `${dist} KM`;
    } else {
      this.estDistance = '-- KM';
    }
  }

  private triggerTickHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.clock.tick',
        count: 1
      }, {
        id: 0,
        usage: 'alarm'
      }).catch(() => {
        try {
          vibrator.startVibration({
            type: 'time',
            duration: 50
          }, {
            id: 0,
            usage: 'alarm'
          });
        } catch (e) {
          // ignore
        }
      });
    } catch (err) {
      try {
        vibrator.startVibration({
          type: 'time',
          duration: 50
        }, {
          id: 0,
          usage: 'alarm'
        });
      } catch (e) {
        // ignore
      }
    }
  }

  private async refreshNearestLocation(): Promise<void> {
    this.isLocating = true;
    try {
      const nearest = await LocationService.requestLocationAndGetNearestAirport();
      if (nearest) {
        this.selectOriginAirport(nearest);
      } else {
        const defaultOrigin = findAirportByCode('CTU') || { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.5785, lon: 103.9471 };
        this.selectOriginAirport(defaultOrigin);
      }
    } catch (err) {
      const defaultOrigin = findAirportByCode('CTU') || { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.5785, lon: 103.9471 };
      this.selectOriginAirport(defaultOrigin);
    } finally {
      this.isLocating = false;
    }
  }

  // 飞行直虚线航线与航班号标识组件
  @Builder
  TrajectoryArrow() {
    Column({ space: 5 }) {
      // 1. 航班号标识 Badge (极简 Cyber 暗黑玻璃胶囊)
      Row({ space: 5 }) {
        Text(this.isDestSelected ? this.flightNo : '搜索真实航班')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDestSelected ? '#F8FAFC' : '#38BDF8')
          .letterSpacing(0.6)

        Text('🔍')
          .fontSize(9)
          .opacity(0.8)
      }
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('rgba(15, 23, 42, 0.75)')
      .border({ width: 1, color: 'rgba(56, 189, 248, 0.25)', radius: 12 })
      .borderRadius(12)
      .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.4)' })
      .onClick(() => {
        this.flightSearchController.open();
      })

      // 2. 丝滑边缘渐隐向左流光虚线航线 (#fce7cd) + 有机高空气流客机 (#e4a524)
      Stack({ alignContent: Alignment.Center }) {
        // 向左无缝平滑流动的虚线航线 (#fce7cd)
        Line()
          .startPoint([-20, 10])
          .endPoint([120, 10])
          .stroke('#fce7cd')
          .strokeWidth(1.5)
          .strokeDashArray([5, 4])
          .width(140)
          .height(20)
          .offset({ x: this.dashLineOffset })

        // 航线右端渐隐 Mask (彻底消除右侧虚线生成时的突兀卡顿感)
        Row()
          .width(20)
          .height(20)
          .linearGradient({
            angle: 90,
            colors: [['rgba(10, 15, 26, 0)', 0], ['rgba(10, 15, 26, 0.95)', 1.0]]
          })
          .position({ x: 80, y: 0 })
          .hitTestBehavior(HitTestMode.None)

        // 航线左端渐隐 Mask (保证左侧退出时同样丝滑)
        Row()
          .width(20)
          .height(20)
          .linearGradient({
            angle: 90,
            colors: [['rgba(10, 15, 26, 0.95)', 0], ['rgba(10, 15, 26, 0)', 1.0]]
          })
          .position({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.None)

        // 航线正中央的用户专属 SVG 俯视视角客机 (#e4a524 琥珀金 + 随机高空气流与俯仰)
        Image($r('app.media.ic_plane_topview'))
          .width(18)
          .height(18)
          .rotate({ angle: this.planeRotate }) // 随机 88° ~ 92° 俯仰角
          .offset({ x: this.planeXOffset, y: this.planeYOffset }) // 随机 X 前后 + Y 气流沉浮
          .scale({ x: this.planeScale, y: this.planeScale }) // 随机 0.90 ~ 1.14 高空纵深感
          .opacity(this.planeOpacity)
      }
      .width(100)
      .height(20)
      .clip(true)
    }
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column({ space: 14 }) {
      // 1. 航线起终点与航班号标识 (对称 Cyber Boarding Header)
      Row() {
        // 出发地 (点击选择 30+ 热门机场)
        Column({ space: 2 }) {
          Text(this.originCode)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text(this.originCity)
            .fontSize(12)
            .fontColor('#94A3B8')
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 4, right: 4, top: 4, bottom: 4 })
        .borderRadius(8)
        .onClick(() => {
          this.originDialogController.open();
        })

        Blank()

        // 轨迹 (居中整合航班号搜索)
        this.TrajectoryArrow()

        Blank()

        // 到达地 (未选择时展示极简通透的 Cyber HUD 引导样式)
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Text(this.destCode === '---' ? 'DEST' : this.destCode)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDestSelected ? '#F8FAFC' : 'rgba(248, 250, 252, 0.35)')
          }
          Text(this.isDestSelected ? this.destCity : '点击选择 ➔')
            .fontSize(12)
            .fontColor(this.isDestSelected ? '#94A3B8' : '#38BDF8')
        }
        .alignItems(HorizontalAlign.End)
        .padding({ left: 4, right: 4, top: 4, bottom: 4 })
        .borderRadius(8)
        .onClick(() => {
          this.destDialogController.open();
        })
      }
      .width('100%')

      Divider().color('rgba(255, 255, 255, 0.08)')

      // 2. 专注时长与航空战术刻度尺 (Chrono Ruler Bar)
      Column({ space: 4 }) {
        Row() {
          Row({ space: 4 }) {
            Text('⏱️')
              .fontSize(11)
            Text('专注时长')
              .fontSize(11)
              .fontColor('#94A3B8')
          }
          Blank()
          // 完全无边框、无背景外衬的纯字展示
          Text(`${this.focusMinutesVal} 分钟`)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
        }
        .width('100%')

        // 极简纤细航空战术刻度尺窗口 (高度由 42 缩小至 30vp)
        Stack({ alignContent: Alignment.Center }) {
          // 可左右顺畅滚动的水平刻度列表
          Scroll(this.rulerScroller) {
            Row() {
              // 左侧半宽占位，确保 15 分钟能精确对准中央游标
              Blank().width(140)

              // 生成从 15 到 180 分钟的刻度线 (每 5 分钟占 24vp 宽度)
              ForEach([15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155, 160, 165, 170, 175, 180], (minute: number) => {
                Column({ space: 2 }) {
                  // 大刻度 (每15分钟) 与 小刻度
                  if (minute % 15 === 0) {
                    Text(`${minute}`)
                      .fontSize(8)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(minute === this.focusMinutesVal ? '#38BDF8' : 'rgba(148, 163, 184, 0.5)')
                    Column()
                      .width(1.5)
                      .height(10)
                      .backgroundColor(minute === this.focusMinutesVal ? '#38BDF8' : 'rgba(255, 255, 255, 0.35)')
                      .borderRadius(1)
                  } else {
                    Text('')
                      .fontSize(8)
                    Column()
                      .width(1)
                      .height(6)
                      .backgroundColor(minute === this.focusMinutesVal ? '#38BDF8' : 'rgba(255, 255, 255, 0.15)')
                      .borderRadius(1)
                  }
                }
                .width(24)
                .alignItems(HorizontalAlign.Center)
              }, (minute: number) => minute.toString())

              // 右侧半宽占位，确保 180 分钟能精确对准中央游标
              Blank().width(140)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height('100%')
          .onAreaChange(() => {
            if (!this.isRulerScrolledInit) {
              this.isRulerScrolledInit = true;
              // 初始平滑定位至默认 45 分钟 (索引 6)
              const initX = ((this.focusMinutesVal - 15) / 5) * 24;
              this.rulerScroller.scrollTo({ xOffset: initX, yOffset: 0 });
            }
          })
          .onDidScroll(() => {
            const xOff = this.rulerScroller.currentOffset().xOffset;
            const idx = Math.round(xOff / 24);
            let targetMinutes = 15 + idx * 5;
            if (targetMinutes < 15) targetMinutes = 15;
            if (targetMinutes > 180) targetMinutes = 180;
            if (this.focusMinutesVal !== targetMinutes) {
              this.focusMinutesVal = targetMinutes;
              this.focusMinutes = `${targetMinutes} 分钟`;
              this.triggerTickHaptic();
            }
          })
          .onScrollStop(() => {
            // 滚动停止时自动平滑吸附到最近的刻度线上
            const xOff = this.rulerScroller.currentOffset().xOffset;
            const targetX = Math.round(xOff / 24) * 24;
            this.rulerScroller.scrollTo({
              xOffset: targetX,
              yOffset: 0,
              animation: { duration: 150, curve: Curve.EaseOut }
            });
          })

          // 居中固定 Cyber Cyan 纯彩发光战术游标准星线
          Column()
            .width(1.5)
            .height(20)
            .backgroundColor('#38BDF8')
            .borderRadius(1)
            .shadow({ radius: 6, color: 'rgba(255, 255, 255, 0.8)' })
            .hitTestBehavior(HitTestMode.Transparent)
        }
        .width('100%')
        .height(30)
        .backgroundColor('rgba(2, 6, 23, 0.35)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.1)', radius: 8 })
        .borderRadius(8)
        .clip(true)
      }
      .width('100%')

      // 3. 预计航程与准点就绪状态
      Row() {
        Column({ space: 3 }) {
          Text('预计航程')
            .fontSize(11)
            .fontColor('#94A3B8')
          Text(this.estDistance)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 准点/就绪状态 Badge
        Row({ space: 4 }) {
          Circle({ width: 6, height: 6 })
            .fill(this.isDestSelected ? '#4ADE80' : '#38BDF8')
          Text(this.isDestSelected ? '准备就绪' : '待选目的地')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDestSelected ? '#4ADE80' : '#38BDF8')
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.isDestSelected ? 'rgba(74, 222, 128, 0.15)' : 'rgba(56, 189, 248, 0.12)')
        .border({ width: 1, color: this.isDestSelected ? 'rgba(74, 222, 128, 0.3)' : 'rgba(56, 189, 248, 0.3)', radius: 12 })
        .borderRadius(12)
      }
      .width('100%')

      // 4. 核心 Call-to-Action 按钮 (自定义 Row 精确居中文字与箭头)
      Row({ space: 6 }) {
        Text(this.isCheckIn ? '已登机 · 开启专注航线' : (this.isDestSelected ? '值机并获取登机牌' : '选择飞行目的地'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isCheckIn ? '#4ADE80' : '#38BDF8')
          .textAlign(TextAlign.Center)

        Text('→')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isCheckIn ? '#4ADE80' : '#38BDF8')
          .lineHeight(14)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.isCheckIn ? 'rgba(74, 222, 128, 0.22)' : 'rgba(56, 189, 248, 0.22)')
      .border({
        width: 1,
        color: this.isCheckIn ? 'rgba(74, 222, 128, 0.5)' : 'rgba(56, 189, 248, 0.5)',
        radius: 22
      })
      .borderRadius(22)
      .shadow({ radius: 16, color: this.isCheckIn ? 'rgba(74, 222, 128, 0.3)' : 'rgba(56, 189, 248, 0.3)', offsetY: 4 })
      .onClick(() => {
        if (!this.isDestSelected) {
          this.destDialogController.open();
          return;
        }
        this.isCheckIn = !this.isCheckIn;
      })
    }
    .width(340)
    .padding(16)
    .backgroundColor('rgba(10, 15, 26, 0.88)')
    .border({ width: 1, color: 'rgba(255, 255, 255, 0.14)', radius: 22 })
    .borderRadius(22)
    .shadow({ radius: 26, color: 'rgba(0, 0, 0, 0.7)', offsetY: 8 })
  }
}

