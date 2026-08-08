import { Airport, POPULAR_AIRPORTS, findAirportByCode, getDistanceKm } from '../models/AirportModel';

/**
 * 对应 ArkTS 规范：显式定义地图节点接口
 */
export interface MapAirportNode {
  airport: Airport;
  xPct: number;
  yPct: number;
  isUnlocked?: boolean;
}

/**
 * FlightMapSelectOverlay.ets
 * 方案二 形态 B：全屏沉浸式航图大屏 (选目的地)
 * 允许用户在暖色手绘大航图上拖拽点选城市、查看金光弧线、累计足迹成就与盲盒抽取航线
 */
@CustomDialog
export struct FlightMapSelectOverlay {
  controller?: CustomDialogController;
  @Prop selectedCode: string = '';
  onDestinationSelected?: (airport: Airport) => void;

  @State currentSelectedCode: string = 'HND'; // 默认选中东京
  @State routeDistanceKm: number = 2480;
  @State unlockedCount: number = 4; // 示例已被解锁的城市计数

  // 整理全屏航图要展示的节点城市列表
  private readonly mapAirports: MapAirportNode[] = [
    { airport: findAirportByCode('CTU') || POPULAR_AIRPORTS[7], xPct: 35, yPct: 52, isUnlocked: true }, // 成都 (基准站)
    { airport: findAirportByCode('PEK') || POPULAR_AIRPORTS[0], xPct: 50, yPct: 32, isUnlocked: true }, // 北京
    { airport: findAirportByCode('PVG') || POPULAR_AIRPORTS[2], xPct: 62, yPct: 48, isUnlocked: true }, // 上海
    { airport: findAirportByCode('CAN') || POPULAR_AIRPORTS[4], xPct: 48, yPct: 68, isUnlocked: true }, // 广州
    { airport: findAirportByCode('SZX') || POPULAR_AIRPORTS[5], xPct: 52, yPct: 70 }, // 深圳
    { airport: findAirportByCode('HGH') || POPULAR_AIRPORTS[8], xPct: 58, yPct: 52 }, // 杭州
    { airport: findAirportByCode('XIY') || POPULAR_AIRPORTS[10], xPct: 40, yPct: 40 }, // 西安
    { airport: findAirportByCode('CKG') || POPULAR_AIRPORTS[11], xPct: 38, yPct: 56 }, // 重庆
    { airport: findAirportByCode('TAO') || POPULAR_AIRPORTS[16], xPct: 58, yPct: 38 }, // 青岛
    { airport: findAirportByCode('HKG') || POPULAR_AIRPORTS[19], xPct: 50, yPct: 73 }, // 香港
    { airport: findAirportByCode('HND') || POPULAR_AIRPORTS[22], xPct: 82, yPct: 34 }, // 东京
    { airport: findAirportByCode('ICN') || POPULAR_AIRPORTS[24], xPct: 68, yPct: 33 }, // 首尔
    { airport: findAirportByCode('SIN') || POPULAR_AIRPORTS[25], xPct: 42, yPct: 86 }, // 新加坡
    { airport: findAirportByCode('LHR') || POPULAR_AIRPORTS[26], xPct: 12, yPct: 22 }, // 伦敦
    { airport: findAirportByCode('CDG') || POPULAR_AIRPORTS[27], xPct: 16, yPct: 25 }  // 巴黎
  ];

  aboutToAppear() {
    if (this.selectedCode) {
      this.currentSelectedCode = this.selectedCode;
    }
    this.updateRouteDistance(this.currentSelectedCode);
  }

  private updateRouteDistance(targetCode: string) {
    const origin = findAirportByCode('CTU');
    const target = findAirportByCode(targetCode);
    if (origin && target && origin.lat !== undefined && origin.lon !== undefined && target.lat !== undefined && target.lon !== undefined) {
      const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(target.lat), Number(target.lon));
      if (!isNaN(dist) && dist > 0) {
        this.routeDistanceKm = dist;
      }
    }
  }

  private selectRandomDestination() {
    const candidateList = this.mapAirports.filter(item => item.airport.code !== 'CTU');
    if (candidateList.length > 0) {
      const randomIdx = Math.floor(Math.random() * candidateList.length);
      const chosen = candidateList[randomIdx];
      this.currentSelectedCode = chosen.airport.code;
      this.updateRouteDistance(chosen.airport.code);
    }
  }

  private confirmSelection() {
    const selected = findAirportByCode(this.currentSelectedCode);
    if (selected && this.onDestinationSelected) {
      this.onDestinationSelected(selected);
    }
    if (this.controller) {
      this.controller.close();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 全屏温润手绘大航图背景与网络线
      Column() {
        // 背景微缩网格与经纬度线装饰
        Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach([1, 2, 3, 4, 5, 6], (_: number) => {
            Row()
              .width('100%')
              .height(1)
              .backgroundColor('rgba(226, 232, 240, 0.4)')
          })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FAF7F2')

      // 2. 交互地图主区域 (散落城市 Marker 点标)
      Stack({ alignContent: Alignment.TopStart }) {
        // 渲染城市节点 Marker
        ForEach(this.mapAirports, (item: MapAirportNode) => {
          Column({ space: 3 }) {
            // 节点图标
            Stack() {
              if (item.airport.code === 'CTU') {
                // 基准起飞站 (成都)
                Circle({ width: 22, height: 22 })
                  .fill('rgba(240, 101, 83, 0.25)')
                Circle({ width: 12, height: 12 })
                  .fill('#F06553')
              } else if (item.airport.code === this.currentSelectedCode) {
                // 当前选中目标城市 (暖珊瑚红发光高亮)
                Circle({ width: 26, height: 26 })
                  .fill('rgba(240, 101, 83, 0.35)')
                Circle({ width: 14, height: 14 })
                  .fill('#F06553')
                Text('✈️')
                  .fontSize(10)
              } else if (item.isUnlocked) {
                // 已解锁城市足迹 (金色爪印)
                Circle({ width: 18, height: 18 })
                  .fill('rgba(245, 158, 11, 0.2)')
                Text('🐾')
                  .fontSize(10)
              } else {
                // 未解锁普通城市 (柔和微光)
                Circle({ width: 10, height: 10 })
                  .fill('#CBD5E1')
              }
            }
            .width(26)
            .height(26)

            // 城市卡片小标签
            Row({ space: 2 }) {
              Text(item.airport.city)
                .fontSize(11)
                .fontWeight(item.airport.code === this.currentSelectedCode ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(item.airport.code === this.currentSelectedCode ? '#F06553' : (item.airport.code === 'CTU' ? '#1E293B' : '#475569'))
            }
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(item.airport.code === this.currentSelectedCode ? 'rgba(255, 255, 255, 0.95)' : 'rgba(255, 255, 255, 0.75)')
            .borderRadius(8)
            .border({ width: 1, color: item.airport.code === this.currentSelectedCode ? '#F06553' : '#E2E8F0' })
          }
          .position({ x: `${item.xPct}%`, y: `${item.yPct}%` })
          .onClick(() => {
            if (item.airport.code !== 'CTU') {
              this.currentSelectedCode = item.airport.code;
              this.updateRouteDistance(item.airport.code);
            }
          })
        })

        // 浮动右下角“🎲 随机探索”盲盒按钮
        Button() {
          Row({ space: 6 }) {
            Text('🎲')
              .fontSize(14)
            Text('随机盲盒航线')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F06553')
          }
        }
        .padding({ left: 14, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(240, 101, 83, 0.3)', radius: 20 })
        .shadow({ radius: 10, color: 'rgba(240, 101, 83, 0.15)', offsetY: 3 })
        .position({ x: '58%', y: '68%' })
        .onClick(() => {
          this.selectRandomDestination();
        })
      }
      .width('100%')
      .height('100%')

      // 3. 顶部 Header 悬浮栏 (标题、足迹统计、关闭按钮)
      Row() {
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text('全屏沉浸航图')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1E293B')

            Row({ space: 4 }) {
              Text('🐾')
                .fontSize(11)
              Text(`已解锁 ${this.unlockedCount}/15 城市`)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#D97706')
            }
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#FEF3C7')
            .borderRadius(10)
          }

          Text('探索全球坐标 · 绘制您的专属专注足迹')
            .fontSize(12)
            .fontColor('#64748B')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 关闭按钮 ✕
        Row() {
          Text('✕')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#64748B')
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.85)')
        .borderRadius(18)
        .border({ width: 1, color: '#E2E8F0' })
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 44, bottom: 14 })
      .backgroundColor('rgba(250, 247, 242, 0.88)')
      .backdropBlur(12)

      // 4. 底部拟真登机牌确认面板 (Flight Ticket Floating Sheet)
      Column({ space: 12 }) {
        // 拟真登机牌卡片 Header
        Row() {
          // 出发地
          Column({ space: 2 }) {
            Text('CTU')
              .fontSize(20)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#1E293B')
            Text('成都双流')
              .fontSize(12)
              .fontColor('#64748B')
          }
          .alignItems(HorizontalAlign.Start)

          // 航线路线指示
          Column({ space: 4 }) {
            Text(`${this.routeDistanceKm} km`)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F06553')

            Row({ space: 4 }) {
              Row().width(24).height(1).backgroundColor('#F06553')
              Image($r('app.media.ic_airport'))
                .width(14)
                .height(14)
                .fillColor('#F06553')
              Row().width(24).height(1).backgroundColor('#F06553')
            }
          }

          // 目的地
          Column({ space: 2 }) {
            Text(this.currentSelectedCode)
              .fontSize(20)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#1E293B')
            Text(findAirportByCode(this.currentSelectedCode)?.city || '目标城市')
              .fontSize(12)
              .fontColor('#64748B')
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        // 确认登机并开始专注按钮
        Button() {
          Row({ space: 8 }) {
            Text('确认航线 · 准备起飞 🛫')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor('#F06553')
        .borderRadius(24)
        .shadow({ radius: 12, color: 'rgba(240, 101, 83, 0.35)', offsetY: 4 })
        .onClick(() => {
          this.confirmSelection();
        })
      }
      .width('90%')
      .padding({ left: 20, right: 20, top: 16, bottom: 20 })
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .shadow({ radius: 18, color: 'rgba(0, 0, 0, 0.08)', offsetY: 6 })
      .border({ width: 1, color: 'rgba(240, 101, 83, 0.25)' })
      .position({ x: '5%', y: '75%' })
    }
    .width('100%')
    .height('100%')
  }
}
