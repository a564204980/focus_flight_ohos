import { common } from '@kit.AbilityKit';
import { LocationService } from '../services/LocationService';
import { Airport, findAirportByCode, getDistanceKm } from '../models/AirportModel';
import { AirportSelectDialog } from './AirportSelectDialog';

/**
 * FocusCheckInCard.ets
 * 专注航班值机卡片 (Focus Check-in Card)
 * 纯净默认未选择目的地，用户自主挑选后再开启专注航线
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
  @State focusMinutes: string = '45 分钟';
  @State estDistance: string = '-- KM';
  @State isCheckIn: boolean = false;
  @State isLocating: boolean = false;
  @State isDestSelected: boolean = false;

  private currentOriginAirport: Airport | null = null;
  @State currentDestAirport: Airport | null = null;

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

  aboutToAppear(): void {
    this.refreshNearestLocation();
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
      this.estDistance = `~${dist} KM`;
    } else {
      this.estDistance = '-- KM';
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

  // 飞行轨迹小箭头与战机图标
  @Builder
  TrajectoryArrow() {
    Row({ space: 4 }) {
      Path()
        .commands('M 3 19.5 H 21 M 3.5 13 L 7.5 11.5 L 11 14 L 15.5 9.5 L 12.8 6.8 L 14.2 5.4 L 19.2 10.4 C 19.8 11 19.8 12 19.2 12.6 L 13.5 18.3 L 12 14.5 Z')
        .fill('#38BDF8')
        .width(14)
        .height(14)

      Text('------------->')
        .fontSize(10)
        .fontColor('rgba(255, 255, 255, 0.25)')
    }
  }

  build() {
    Column({ space: 14 }) {
      // 1. 航线起终点与航班号标识
      Row() {
        // 出发地 (圈红区域：可点击弹窗选择 30+ 热门机场)
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

        // 轨迹
        this.TrajectoryArrow()

        Blank()

        // 到达地 (未选择时展示极简通透的 Cyber HUD 引导样式)
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Text(this.destCode === '---' ? 'DEST' : this.destCode)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDestSelected ? '#F8FAFC' : 'rgba(248, 250, 252, 0.35)')
            Text(this.isDestSelected ? '🚩' : '➕')
              .fontSize(12)
          }
          Text(this.isDestSelected ? this.destCity : '点击选择 ➔')
            .fontSize(12)
            .fontColor(this.isDestSelected ? '#94A3B8' : '#38BDF8')
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 4, right: 4, top: 4, bottom: 4 })
        .borderRadius(8)
        .onClick(() => {
          this.destDialogController.open();
        })

        // 航班号 Search 胶囊
        Row({ space: 4 }) {
          Text('🔍')
            .fontSize(10)
          Text(this.isDestSelected ? this.flightNo : 'CA---')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('rgba(56, 189, 248, 0.12)')
        .border({ width: 1, color: 'rgba(56, 189, 248, 0.3)', radius: 12 })
        .borderRadius(12)
        .margin({ left: 10 })
      }
      .width('100%')

      Divider().color('rgba(255, 255, 255, 0.08)')

      // 2. 专注时长、预计航程与准点状态
      Row() {
        Column({ space: 3 }) {
          Text('专注时长')
            .fontSize(11)
            .fontColor('#94A3B8')
          Text(this.focusMinutes)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

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

      // 3. 核心 Call-to-Action 按钮 (高奢暗黑微光高高亮按钮)
      Button(this.isCheckIn ? '已登机 · 开启专注航线 ➔' : (this.isDestSelected ? '值机并获取登机牌 ➔' : '选择飞行目的地 ➔'))
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(this.isCheckIn ? 'rgba(74, 222, 128, 0.22)' : 'rgba(56, 189, 248, 0.22)')
        .fontColor(this.isCheckIn ? '#4ADE80' : '#38BDF8')
        .border({
          width: 1,
          color: this.isCheckIn ? 'rgba(74, 222, 128, 0.5)' : 'rgba(56, 189, 248, 0.5)',
          radius: 22
        })
        .borderRadius(22)
        .shadow({ radius: 16, color: this.isCheckIn ? 'rgba(74, 222, 128, 0.3)' : 'rgba(56, 189, 248, 0.3)', offsetY: 4 })
        .onClick(() => {
          if (!this.isDestSelected) {
            // 未选择目的地时自动唤起目的地选择抽屉！
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

