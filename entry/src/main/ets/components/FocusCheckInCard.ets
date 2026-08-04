import { common } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';
import { router } from '@kit.ArkUI';
import { LocationService } from '../services/LocationService';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { AirportSelectDialog } from './AirportSelectDialog';
import { FlightSearchDialog } from './FlightSearchDialog';
import { FlightInfo } from '../services/FlightService';
import { SeatSelectionDialog } from './SeatSelectionDialog';

/**
 * FocusCheckInCard.ets
 * 专注航班值机卡片 (Focus Check-in Card)
 * 纯净默认未选择目的地，用户自主挑选或搜索真实航班后开启专注航线
 */

@Component
export struct FocusCheckInCard {
  onOriginAirportChanged?: (airport: Airport) => void;
  onRouteChanged?: (origin: Airport, dest: Airport | null) => void;
  onRequestSeatSelection?: () => void;

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
  @State selectedSeat: string = '1F';
  @State checkInStep: number = 0;

  public setSelectedSeat(seatId: string): void {
    this.selectedSeat = seatId;
    this.checkInStep = 2;
    this.isCheckIn = true;
  }
  @State isSeatSheetOpen: boolean = false;
  @State seatSheetY: string = '100%';

  // 4. 1:1 对标图 1 在线选座值机抽屉 Controller
  private seatDialogController: CustomDialogController = new CustomDialogController({
    builder: SeatSelectionDialog({
      flightNo: this.flightNo !== 'CA---' ? this.flightNo : 'CA933',
      originCode: this.originCode,
      destCode: this.destCode,
      onConfirmSeat: (seatId: string, cabin: string) => {
        this.selectedSeat = seatId;
        this.isCheckIn = true;
      }
    }),
    alignment: DialogAlignment.Bottom,
    maskColor: 'rgba(2, 6, 23, 0.88)',
    customStyle: true,
    offset: { dx: 0, dy: 0 }
  });
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

  // 5. 值机动效状态 (小人拖行李箱去值机)
  @State isCheckingInAnim: boolean = false;
  @State checkInProgress: number = 0; // 0.0 ~ 1.0
  @State animWalkFrame: number = 0;
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private walkAnimTimer: number = -1;
  private checkInTimer: number = -1;

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

    try {
      const params = router.getParams() as Record<string, Object>;
      if (params && params['isCheckInConfirmed'] === true && params['completedSeat']) {
        this.selectedSeat = params['completedSeat'] as string;
        this.isCheckIn = true;
      }
    } catch (e) {
      // ignore
    }
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
    if (this.walkAnimTimer !== -1) {
      clearInterval(this.walkAnimTimer);
      this.walkAnimTimer = -1;
    }
    if (this.checkInTimer !== -1) {
      clearInterval(this.checkInTimer);
      this.checkInTimer = -1;
    }
  }

  private getCheckInStatusText(): string {
    if (this.checkInProgress < 0.35) {
      return '正在前往值机柜台...';
    } else if (this.checkInProgress < 0.75) {
      return '行李托运与安检查验中...';
    } else {
      return '生成电子登机牌中...';
    }
  }

  private startCheckInProcess(): void {
    if (this.isCheckingInAnim || this.isCheckIn) return;

    this.isCheckingInAnim = true;
    this.checkInProgress = 0;

    // 启动 Canvas 步伐走动动画
    if (this.walkAnimTimer !== -1) clearInterval(this.walkAnimTimer);
    this.walkAnimTimer = setInterval(() => {
      this.animWalkFrame += 0.3;
      this.drawWalkingScene();
    }, 30);

    const totalTime = 2600;
    const interval = 30;
    const step = interval / totalTime;

    if (this.checkInTimer !== -1) clearInterval(this.checkInTimer);
    this.checkInTimer = setInterval(() => {
      this.checkInProgress += step;
      if (this.checkInProgress >= 1.0) {
        this.checkInProgress = 1.0;
        clearInterval(this.checkInTimer);
        this.checkInTimer = -1;

        if (this.walkAnimTimer !== -1) {
          clearInterval(this.walkAnimTimer);
          this.walkAnimTimer = -1;
        }

        this.triggerTickHaptic();

        setTimeout(() => {
          this.isCheckingInAnim = false;
          this.isCheckIn = true;
        }, 150);
      }
    }, interval);
  }

  private drawWalkingScene(): void {
    const ctx = this.canvasContext;
    if (!ctx) return;

    const w = 308;
    const h = 76;
    ctx.clearRect(0, 0, w, h);

    // 1. 极光网格跑道与流线地面
    const groundY = 58;

    // 地面渐变网格 Base
    const groundGradient = ctx.createLinearGradient(0, groundY, 0, groundY + 12);
    groundGradient.addColorStop(0, 'rgba(56, 189, 248, 0.4)');
    groundGradient.addColorStop(1, 'rgba(56, 189, 248, 0.0)');
    ctx.fillStyle = groundGradient;
    ctx.fillRect(10, groundY, 288, 12);

    // 地面主发光跑道线
    ctx.beginPath();
    ctx.strokeStyle = '#38BDF8';
    ctx.lineWidth = 1.5;
    ctx.moveTo(10, groundY);
    ctx.lineTo(290, groundY);
    ctx.stroke();

    // 跑道向后流动的脉冲点阵 (Dot Grid Trail)
    for (let x = 12; x < 288; x += 16) {
      const dotX = (x - (this.animWalkFrame * 4) % 16 + 288) % 288 + 10;
      ctx.fillStyle = 'rgba(56, 189, 248, 0.5)';
      ctx.fillRect(dotX, groundY + 2, 3, 1.5);
    }

    // 2. 右侧全息安检闸门 (GATE A01 Holographic Portal)
    const gateX = 250;
    const gateY = 12;
    const gateW = 34;
    const gateH = 46;

    // 拱门左右发光半透明门柱
    const gateGradient = ctx.createLinearGradient(0, gateY, 0, gateY + gateH);
    gateGradient.addColorStop(0, 'rgba(74, 222, 128, 0.9)');
    gateGradient.addColorStop(1, 'rgba(56, 189, 248, 0.2)');

    ctx.fillStyle = gateGradient;
    // 左门柱 (圆角)
    ctx.beginPath();
    ctx.roundRect(gateX, gateY + 6, 5, gateH - 6, 2.5);
    ctx.fill();
    // 右门柱
    ctx.beginPath();
    ctx.roundRect(gateX + gateW - 5, gateY + 6, 5, gateH - 6, 2.5);
    ctx.fill();

    // 拱门顶部科技楣板
    ctx.fillStyle = '#4ADE80';
    ctx.beginPath();
    ctx.roundRect(gateX - 2, gateY, gateW + 4, 7, 3);
    ctx.fill();

    // 楣板文字与全息 Indicator
    ctx.fillStyle = '#020617';
    ctx.font = 'bold 7px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('GATE 01', gateX + gateW / 2, gateY + 5.5);
    ctx.textAlign = 'left'; // reset

    // 门洞内全息扫码激光网幕 (Laser Scanner Curtain)
    const scanPhase = (Math.sin(this.animWalkFrame * 0.35) + 1) / 2; // 0 ~ 1
    const scanY = gateY + 8 + scanPhase * (gateH - 12);
    
    // 激光帘半透明羽化面
    const laserGradient = ctx.createLinearGradient(0, scanY - 6, 0, scanY);
    laserGradient.addColorStop(0, 'rgba(74, 222, 128, 0.0)');
    laserGradient.addColorStop(1, 'rgba(74, 222, 128, 0.35)');
    ctx.fillStyle = laserGradient;
    ctx.fillRect(gateX + 5, scanY - 6, gateW - 10, 6);

    // 激光核心发光线
    ctx.beginPath();
    ctx.strokeStyle = '#4ADE80';
    ctx.lineWidth = 1.5;
    ctx.moveTo(gateX + 4, scanY);
    ctx.lineTo(gateX + gateW - 4, scanY);
    ctx.stroke();

    // 3. 拖行李箱的时尚旅客剪影 (Modern Traveler Silhouette)
    const charX = 25 + this.checkInProgress * 205;
    const charY = groundY;

    // 3a. 倾斜 18° 时尚登机箱 🧳 (拖在身左侧身后 charX - 24)
    ctx.save();
    const lugCenterX = charX - 24;
    const lugCenterY = charY - 14;
    ctx.translate(lugCenterX, lugCenterY);
    ctx.rotate(-18 * Math.PI / 180); // 倾斜 18° 拉动张力

    const lugW = 14;
    const lugH = 19;

    // 行李箱主体 (圆角 Cyber 蓝)
    ctx.fillStyle = '#38BDF8';
    ctx.beginPath();
    ctx.roundRect(-lugW / 2, -lugH / 2, lugW, lugH, 3);
    ctx.fill();

    // 镀铬银边框
    ctx.strokeStyle = 'rgba(248, 250, 252, 0.8)';
    ctx.lineWidth = 1;
    ctx.stroke();

    // 琥珀橙暖色中心标识带
    ctx.fillStyle = '#FF9500';
    ctx.fillRect(-lugW / 2 + 2, -lugH / 2 + 4, lugW - 4, 3.5);

    // 双小轮
    ctx.fillStyle = '#F8FAFC';
    ctx.beginPath();
    ctx.arc(-lugW / 2 + 3, lugH / 2 + 1.5, 2, 0, Math.PI * 2);
    ctx.arc(lugW / 2 - 3, lugH / 2 + 1.5, 2, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();

    // 拉杆 (连到旅客左手)
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(248, 250, 252, 0.75)';
    ctx.lineWidth = 1.2;
    ctx.moveTo(lugCenterX, lugCenterY - 6);
    ctx.lineTo(charX - 6, charY - 24);
    ctx.stroke();

    // 3b. 旅客头部与全息光晕
    const headX = charX;
    const headY = charY - 38;

    // 头部 halo 微光
    const headGlow = ctx.createRadialGradient(headX, headY, 1, headX, headY, 8);
    headGlow.addColorStop(0, 'rgba(56, 189, 248, 0.9)');
    headGlow.addColorStop(1, 'rgba(56, 189, 248, 0.0)');
    ctx.fillStyle = headGlow;
    ctx.beginPath();
    ctx.arc(headX, headY, 8, 0, Math.PI * 2);
    ctx.fill();

    // 头部实心
    ctx.fillStyle = '#F8FAFC';
    ctx.beginPath();
    ctx.arc(headX, headY, 4.5, 0, Math.PI * 2);
    ctx.fill();

    // 3c. 躯干服装 (优雅倾斜风衣 / 渐变多边形)
    const stepPhase = Math.sin(this.animWalkFrame * 0.45);

    // 身躯渐变色
    const torsoGrad = ctx.createLinearGradient(headX, headY + 5, headX, charY - 12);
    torsoGrad.addColorStop(0, '#38BDF8');
    torsoGrad.addColorStop(1, '#818CF8');

    ctx.fillStyle = torsoGrad;
    ctx.beginPath();
    // 头部下方颈口
    ctx.moveTo(headX - 3.5, headY + 5);
    ctx.lineTo(headX + 3.5, headY + 5);
    // 肩膀伸展
    ctx.lineTo(headX + 6, headY + 12);
    // 下摆风衣
    ctx.lineTo(headX + 2, charY - 14);
    ctx.lineTo(headX - 5, charY - 14);
    ctx.lineTo(headX - 6, headY + 12);
    ctx.closePath();
    ctx.fill();

    // 3d. 踱步双腿 (曲线迈步，带动感)
    const legY = charY - 14;
    const frontLegX = headX + stepPhase * 9;
    const backLegX = headX - stepPhase * 9;

    // 前腿 (荧光绿鞋底)
    ctx.beginPath();
    ctx.strokeStyle = '#4ADE80';
    ctx.lineWidth = 2.8;
    ctx.lineCap = 'round';
    ctx.moveTo(headX + 1, legY);
    ctx.lineTo(frontLegX, charY);
    ctx.stroke();

    // 后腿 (青蓝)
    ctx.beginPath();
    ctx.strokeStyle = '#38BDF8';
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.moveTo(headX - 2, legY);
    ctx.lineTo(backLegX, charY);
    ctx.stroke();

    // 3e. 双臂 (右臂前摆，左臂向后拉箱)
    // 右臂 (前摆)
    ctx.beginPath();
    ctx.strokeStyle = '#F8FAFC';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.moveTo(headX + 4, headY + 10);
    ctx.lineTo(headX + Math.cos(stepPhase) * 7 + 2, headY + 22);
    ctx.stroke();

    // 左臂 (向后拉杆)
    ctx.beginPath();
    ctx.strokeStyle = '#F8FAFC';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.moveTo(headX - 4, headY + 10);
    ctx.lineTo(charX - 6, charY - 24);
    ctx.stroke();

    // 4. 行李箱与步伐后方的流光星星微粒 (Sparkle Dust)
    for (let i = 0; i < 3; i++) {
      const pX = lugCenterX - 8 - i * 6 - (this.animWalkFrame * 2 + i * 3) % 12;
      const pY = groundY - 2 - Math.sin(this.animWalkFrame + i) * 3;
      ctx.fillStyle = `rgba(56, 189, 248, ${0.7 - i * 0.2})`;
      ctx.beginPath();
      ctx.arc(pX, pY, 1.2, 0, Math.PI * 2);
      ctx.fill();
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
        const defaultOrigin = findAirportByCode('CTU') || { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.589825, lon: 103.955706 };
        this.selectOriginAirport(defaultOrigin);
      }
    } catch (err) {
      const defaultOrigin = findAirportByCode('CTU') || { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.589825, lon: 103.955706 };
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

      // 切换视图：0: 未值机 (刻度尺) | 1: 卡片原位无弹窗展开图1机舱选座 | 2: 已完成值机锁牌
      if (this.checkInStep === 0) {
        // 【0: 未值机初始状态】：图1红框区域 (专注时长刻度尺 + 预计航程)
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
            Text(`${this.focusMinutesVal} 分钟`)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')
          }
          .width('100%')

          // 极简纤细航空战术刻度尺窗口 (高度 30vp)
          Stack({ alignContent: Alignment.Center }) {
            Scroll(this.rulerScroller) {
              Row() {
                Blank().width(140)

                ForEach([15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155, 160, 165, 170, 175, 180], (minute: number) => {
                  Column({ space: 2 }) {
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
              const xOff = this.rulerScroller.currentOffset().xOffset;
              const targetX = Math.round(xOff / 24) * 24;
              this.rulerScroller.scrollTo({
                xOffset: targetX,
                yOffset: 0,
                animation: { duration: 150, curve: Curve.EaseOut }
              });
            })

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

        // 预计航程与准点就绪状态
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

      } else if (this.checkInStep === 1) {
        // 【1: 零弹窗原位展开 1:1 图1机舱选座网格】(Inline Cabin Seat Selector)
        Column({ space: 10 }) {
          // 弧形机头 & 4 扇驾驶舱风挡
          Stack({ alignContent: Alignment.Top }) {
            Column()
              .width(220)
              .height(100)
              .backgroundColor('rgba(255, 255, 255, 0.04)')
              .border({ width: 1.5, color: 'rgba(255, 255, 255, 0.15)', radius: { topLeft: 110, topRight: 110 } })
              .borderRadius({ topLeft: 110, topRight: 110 })

            Row({ space: 5 }) {
              Row().width(38).height(20).backgroundColor('rgba(2, 6, 23, 0.88)').borderRadius({ topLeft: 10, topRight: 3 })
              Row().width(38).height(20).backgroundColor('rgba(2, 6, 23, 0.88)').borderRadius({ topLeft: 3, topRight: 3 })
              Row().width(38).height(20).backgroundColor('rgba(2, 6, 23, 0.88)').borderRadius({ topLeft: 3, topRight: 3 })
              Row().width(38).height(20).backgroundColor('rgba(2, 6, 23, 0.88)').borderRadius({ topLeft: 3, topRight: 10 })
            }
            .offset({ y: 38 })
          }
          .width('100%')
          .height(90)

          // 商务舱标头 & 座位
          Column({ space: 6 }) {
            Row() {
              Text('Business')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F8FAFC')
              Blank()
              Text('2 x 2 豪华宽座')
                .fontSize(10)
                .fontColor('#38BDF8')
            }
            .width('100%')

            Row() {
              Row({ space: 12 }) {
                Text('A').fontSize(10).fontColor('#94A3B8').width(22).textAlign(TextAlign.Center)
                Text('B').fontSize(10).fontColor('#94A3B8').width(22).textAlign(TextAlign.Center)
                Text('C').fontSize(10).fontColor('#94A3B8').width(22).textAlign(TextAlign.Center)
              }
              Blank()
              Text('过道').fontSize(8).fontColor('rgba(148, 163, 184, 0.4)')
              Blank()
              Row({ space: 12 }) {
                Text('D').fontSize(10).fontColor('#94A3B8').width(22).textAlign(TextAlign.Center)
                Text('E').fontSize(10).fontColor('#94A3B8').width(22).textAlign(TextAlign.Center)
                Text('F').fontSize(10).fontColor('#94A3B8').width(22).textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20 })

            ForEach([1, 2], (rowNum: number) => {
              Row() {
                Text(`${rowNum}`).fontSize(10).fontColor('#94A3B8').width(14)
                Row({ space: 10 }) {
                  ForEach(['A', 'B', 'C'], (col: string) => {
                    this.InlineSeatTile(`${rowNum}${col}`, rowNum, col, 'Business')
                  })
                }
                Blank()
                Row({ space: 10 }) {
                  ForEach(['D', 'E', 'F'], (col: string) => {
                    this.InlineSeatTile(`${rowNum}${col}`, rowNum, col, 'Business')
                  })
                }
                Text(`${rowNum}`).fontSize(10).fontColor('#94A3B8').width(14).textAlign(TextAlign.End)
              }
              .width('100%')
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(10)
        .backgroundColor('rgba(2, 6, 23, 0.4)')
        .border({ width: 1, color: 'rgba(56, 189, 248, 0.2)', radius: 14 })
        .borderRadius(14)

      } else {
        // 【2: 已完成值机登机状态】：包含已选座位号的纯净通透电子登机牌卡片
        Row({ space: 10 }) {
          Text('🎫')
            .fontSize(20)
          Column({ space: 3 }) {
            Row({ space: 6 }) {
              Text('电子登机牌已签发')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#4ADE80')
              Text(`座位 ${this.selectedSeat}`)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#38BDF8')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('rgba(56, 189, 248, 0.15)')
                .borderRadius(4)
            }
            Text(`专注航线: ${this.originCode} ➔ ${this.destCode} | 预计航程: ${this.estDistance}`)
              .fontSize(11)
              .fontColor('#94A3B8')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('rgba(74, 222, 128, 0.08)')
        .border({ width: 1, color: 'rgba(74, 222, 128, 0.3)', radius: 12 })
        .borderRadius(12)
      }

      // 4. 核心 Call-to-Action 按钮 (自定义 Row 精确居中文字与箭头)
      Row({ space: 6 }) {
        Text(this.checkInStep === 1 ? `确认选座 (${this.selectedSeat}) 并完成值机` : (this.checkInStep === 2 ? `已选座 ${this.selectedSeat} · 更改选座` : (this.isDestSelected ? '开始值机' : '选择飞行目的地')))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.checkInStep === 2 ? '#4ADE80' : '#38BDF8')
          .textAlign(TextAlign.Center)

        Text('→')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.checkInStep === 2 ? '#4ADE80' : '#38BDF8')
          .lineHeight(14)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.checkInStep === 2 ? 'rgba(74, 222, 128, 0.22)' : 'rgba(56, 189, 248, 0.22)')
      .border({
        width: 1,
        color: this.checkInStep === 2 ? 'rgba(74, 222, 128, 0.5)' : 'rgba(56, 189, 248, 0.5)',
        radius: 22
      })
      .borderRadius(22)
      .shadow({ radius: 16, color: this.checkInStep === 2 ? 'rgba(74, 222, 128, 0.3)' : 'rgba(56, 189, 248, 0.3)', offsetY: 4 })
      .onClick(() => {
        if (!this.isDestSelected) {
          this.destDialogController.open();
          return;
        }

        this.triggerTickHaptic();

        // 触发最高层级巨型飞机阴影从底部平滑升起覆盖全屏 UI！
        if (this.onRequestSeatSelection) {
          this.onRequestSeatSelection();
        }
      })
    }
    .width(340)
    .padding(16)
    .backgroundColor('rgba(10, 15, 26, 0.88)')
    .border({ width: 1, color: 'rgba(255, 255, 255, 0.14)', radius: 22 })
    .borderRadius(22)
    .shadow({ radius: 26, color: 'rgba(0, 0, 0, 0.7)', offsetY: 8 })
  }

  private isInlineSeatSelected(seatId: string): boolean {
    return this.selectedSeat === seatId;
  }

  private isInlineSeatOccupied(row: number, col: string): boolean {
    return (row === 1 && (col === 'A' || col === 'B')) || (row === 3 && col === 'C');
  }

  // 0 弹窗原位卡片机舱选座单元 Builder (Inline Seat Tile)
  @Builder
  InlineSeatTile(seatId: string, row: number, col: string, cabin: string) {
    Column() {
      if (this.isInlineSeatSelected(seatId)) {
        Text('✓')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      } else {
        Column()
          .width(18)
          .height(10)
          .backgroundColor(this.isInlineSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.15)' : 'rgba(255, 255, 255, 0.25)')
          .borderRadius({ topLeft: 3, topRight: 3 })
      }
    }
    .width(26)
    .height(26)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isInlineSeatSelected(seatId) ? '#38BDF8' : (this.isInlineSeatOccupied(row, col) ? 'rgba(15, 23, 42, 0.6)' : 'rgba(255, 255, 255, 0.08)'))
    .border({
      width: this.isInlineSeatSelected(seatId) ? 1.5 : (this.isInlineSeatOccupied(row, col) ? 0.5 : 1),
      color: this.isInlineSeatSelected(seatId) ? '#38BDF8' : (this.isInlineSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.2)' : 'rgba(255, 255, 255, 0.2)'),
      radius: 6
    })
    .borderRadius(6)
    .shadow({ radius: this.isInlineSeatSelected(seatId) ? 8 : 0, color: 'rgba(56, 189, 248, 0.6)' })
    .onClick(() => {
      if (this.isInlineSeatOccupied(row, col)) return;
      this.selectedSeat = seatId;
      this.triggerTickHaptic();
    })
  }
}

