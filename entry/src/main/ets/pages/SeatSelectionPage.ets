import { promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { getCustomRunwaysForAirport, getCustomTaxiwaysForAirport, getAirportTakeoffRunway } from '../models/AirportRunwayConfig';
import { generateGreatCirclePoints, LatLngPoint, calculateBearing, interpolateLatLng, calculateCameraTargetForAnchor } from '../utils/GeodesicUtils';
import { FlightSessionStore, FlightSessionData } from '../services/FlightSessionStore';

// ✈️ 从机场配置动态读取 CTU 起飞跑道数据
const _ctuRunway = getAirportTakeoffRunway('CTU');
const CTU_RUNWAY_START: LatLngPoint = _ctuRunway?.start ?? { latitude: 30.561173, longitude: 103.942350 };
const CTU_RUNWAY_END: LatLngPoint = _ctuRunway?.end ?? { latitude: 30.589161, longitude: 103.955371 };
const CTU_RUNWAY_BEARING: number = calculateBearing(CTU_RUNWAY_START, CTU_RUNWAY_END);
// 物理级镜头对齐：使跑道起点红点 (30.561173, 103.942350) 居于画面中心偏下方 80px 适中视角！
const CTU_CAMERA_TARGET: LatLngPoint = calculateCameraTargetForAnchor(CTU_RUNWAY_START, CTU_RUNWAY_END, 80, 17.2);

/**
 * SeatSelectionPage.ets
 * 战术全景选座舱 (Tactical Seat Selection Page)
 * 点击座椅后：整架飞机与机舱选座卡片平滑 3D 缩小，100% 震撼露出背后的华为 Petal Maps 与 Cyber 战术航线地图！
 */

interface SeatParams {
  flightNo?: string;
  originCode?: string;
  destCode?: string;
  focusMinutesVal?: number;
  estDistance?: string;
  currentSeat?: string;
}

@Entry
@Component
struct SeatSelectionPage {
  @State flightNo: string = 'CA933';
  @State originCode: string = 'CTU';
  @State destCode: string = 'CDG';
  @State focusMinutesVal: number = 45;
  @State estDistance: string = '8,245 KM';
  @State selectedSeatId: string = '1F';
  @State selectedCabin: string = 'Business';

  // === 飞机/机舱缩小与背后地图联动动画状态 ===
  @State isMapExposed: boolean = false;           // 是否已点击座椅缩小飞机并露出背后地图
  @State seatCardScale: number = 1.0;            // 飞机/机舱选座卡片 3D 缩放比例
  @State seatCardY: number = 0;                  // 飞机/机舱卡片 Y 轴平移偏移量
  @State seatCardOpacity: number = 1.0;          // 选座卡片透明度
  @State mapOpacity: number = 0.25;              // 背后战术地图透明度
  @State mapZoomScale: number = 1.0;             // 背景地图镜头拉近缩放

  private huaweiMapController?: map.MapComponentController;
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: CTU_CAMERA_TARGET.latitude,
        longitude: CTU_CAMERA_TARGET.longitude
      },
      zoom: 17.2,
      bearing: CTU_RUNWAY_BEARING,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE,
    zoomControlsEnabled: false,
    compassControlsEnabled: false,
    rotateGesturesEnabled: true,
    zoomGesturesEnabled: true
  };

  private applyRunwayCameraOrientation(controller?: map.MapComponentController): void {
    const mapCtrl = controller || this.huaweiMapController;
    if (mapCtrl) {
      try {
        mapCtrl.moveCamera(map.newCameraPosition({
          target: {
            latitude: CTU_CAMERA_TARGET.latitude,
            longitude: CTU_CAMERA_TARGET.longitude
          },
          zoom: 17.2,
          bearing: CTU_RUNWAY_BEARING,
          tilt: 0
        }));
      } catch (e) {
        console.error('SeatSelectionPage applyRunwayCameraOrientation error:', JSON.stringify(e));
      }
    }
  }

  private huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.setupHuaweiMap(controller);
      setTimeout(() => {
        this.applyRunwayCameraOrientation(controller);
      }, 150);
      setTimeout(() => {
        this.applyRunwayCameraOrientation(controller);
      }, 650);
    }
  };

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 0a. 强制将地图镜头平移与旋转至跑道垂直朝上对齐视角！
      this.applyRunwayCameraOrientation(controller);

      // 0b. 监听地图点击事件，实时输出并弹窗提示经纬度坐标点
      controller.on('mapClick', (latLng: mapCommon.LatLng) => {
        const latStr = latLng.latitude.toFixed(6);
        const lonStr = latLng.longitude.toFixed(6);
        console.info(`[SeatSelectionPage MapClick] Lat: ${latStr}, Lon: ${lonStr}`);
        try {
          promptAction.showToast({
            message: `📍 选点坐标: ${latStr}, ${lonStr}`,
            duration: 4000
          });
        } catch (e) {}
      });

      // 1. 绘制 CTU 精修跑道
      const customRunwayPolygons = getCustomRunwaysForAirport('CTU');
      if (customRunwayPolygons) {
        for (const corners of customRunwayPolygons) {
          await controller.addPolygon({
            points: corners,
            fillColor: 0xFF1E293B,
            strokeColor: 0xFF38BDF8,
            strokeWidth: 2
          });
        }
      }

      // 2. 绘制 CTU 精修滑行道网络
      const customTaxiways = getCustomTaxiwaysForAirport('CTU');
      if (customTaxiways) {
        for (const taxiway of customTaxiways) {
          await controller.addPolyline({
            points: taxiway,
            color: 0xCC38BDF8,
            width: 3
          });
        }
      }

      // 3. 将滑行道的两个点使用标准 Cyber 航线样式在地图最顶层连结呈现！
      const taxiwayRoutePoints = generateGreatCirclePoints(CTU_RUNWAY_START, CTU_RUNWAY_END, 120);
      await controller.addPolyline({
        points: taxiwayRoutePoints,
        width: 16,
        color: 0x6638BDF8
      });
      await controller.addPolyline({
        points: taxiwayRoutePoints,
        width: 6,
        color: 0xFF38BDF8
      });
      await controller.addPolyline({
        points: taxiwayRoutePoints,
        width: 3,
        color: 0xFFFFFFFF,
        patterns: [
          { type: mapCommon.PatternItemType.DASH, length: 12 },
          { type: mapCommon.PatternItemType.GAP, length: 8 }
        ]
      });


    } catch (e) {
      console.error('SeatSelectionPage Petal Map setup error:', JSON.stringify(e));
    }
  }

  aboutToAppear(): void {
    const params = router.getParams() as SeatParams;
    if (params) {
      if (params.flightNo) this.flightNo = params.flightNo;
      if (params.originCode) this.originCode = params.originCode;
      if (params.destCode) this.destCode = params.destCode;
      if (params.focusMinutesVal) this.focusMinutesVal = params.focusMinutesVal;
      if (params.estDistance) this.estDistance = params.estDistance;
      if (params.currentSeat) this.selectedSeatId = params.currentSeat;
    }
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 25
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  private isSeatSelected(seatId: string): boolean {
    return this.selectedSeatId === seatId;
  }

  private isSeatOccupied(row: number, col: string): boolean {
    return false;
  }

  // 重置/重新放大机舱选座卡片
  private resetCabinScale(): void {
    this.triggerHaptic();
    this.getUIContext()?.animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.isMapExposed = false;
      this.seatCardScale = 1.0;
      this.seatCardY = 0;
      this.seatCardOpacity = 1.0;
      this.mapOpacity = 0.25;
      this.mapZoomScale = 1.0;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // ==========================================
      // 1. 底层：100% 稳定震撼呈现的 Cyber 战术地图视界 (双保险：MapKit + 精精修停机坪/弧形航线背景)
      // ==========================================
      Stack({ alignContent: Alignment.Center }) {
        // 1a. 高清机场跑道与停机坪基础贴图
        Image($r('app.media.bg_1'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: this.mapZoomScale, y: this.mapZoomScale })
          .animation({ duration: 800, curve: Curve.EaseOut })

        // 1b. 华为原生 MapComponent
        MapComponent({ mapOptions: this.huaweiMapOptions, mapCallback: this.huaweiMapCallback })
          .width('100%')
          .height('100%')
          .opacity(0.85)

        // 1c. 战术 HUD 航线与坐标叠加图层
        Column() {
          // 顶部 HUD 视角坐标与战术网格
          Row() {
            Column({ space: 2 }) {
              Text('RADAR TACTICAL MAP')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#38BDF8')
                .letterSpacing(1)
              Text('N 30°33\'41"  E 103°56\'32"')
                .fontSize(9)
                .fontColor('rgba(248, 250, 252, 0.6)')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Row({ space: 6 }) {
              Circle({ width: 6, height: 6 }).fill('#4ADE80')
              Text('CTU 跑道 02L 在线')
                .fontSize(10)
                .fontColor('#4ADE80')
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('rgba(74, 222, 128, 0.15)')
            .borderRadius(8)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 100 })

          Blank()

          // 中央弧形测地线示意 (航线指示线)
          Stack({ alignContent: Alignment.Center }) {
            // 弧形跑道航线 SVG/Line 效果
            Column()
              .width(260)
              .height(260)
              .border({ width: 2, color: 'rgba(56, 189, 248, 0.35)', style: BorderStyle.Dashed, radius: 130 })
              .borderRadius(130)
              .scale({ x: 1.4, y: 0.4 })

            // 战线起终点 Badge
            Row() {
              Row({ space: 4 }) {
                Circle({ width: 8, height: 8 }).fill('#38BDF8')
                Text(this.originCode).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('rgba(15, 23, 42, 0.85)')
              .border({ width: 1, color: '#38BDF8', radius: 10 })

              Blank()

              Row({ space: 4 }) {
                Text(this.destCode).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
                Circle({ width: 8, height: 8 }).fill('#4ADE80')
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('rgba(15, 23, 42, 0.85)')
              .border({ width: 1, color: '#4ADE80', radius: 10 })
            }
            .width('80%')
          }
          .width('100%')
          .height(200)

          Blank()
        }
        .width('100%')
        .height('100%')
        .opacity(this.isMapExposed ? 1.0 : 0.2)
        .animation({ duration: 800, curve: Curve.EaseOut })
      }
      .width('100%')
      .height('100%')
      .opacity(this.mapOpacity)
      .animation({ duration: 800, curve: Curve.EaseInOut })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // ==========================================
      // 2. 顶栏战术 Header (固定顶部，保持高层级 ZIndex)
      // ==========================================
      Row() {
        // 返回按钮
        Row({ space: 6 }) {
          Text('‹')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
          Text('返回')
            .fontSize(14)
            .fontColor('#F8FAFC')
        }
        .padding({ left: 10, right: 14, top: 6, bottom: 6 })
        .backgroundColor('rgba(255, 255, 255, 0.08)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.12)', radius: 18 })
        .borderRadius(18)
        .onClick(() => {
          this.triggerHaptic();
          router.back();
        })

        Blank()

        // 标题
        Column({ space: 2 }) {
          Text(this.isMapExposed ? '🗺️ 航线战术全景' : '全景选座 · 战术机舱')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text(`航班 ${this.flightNo} · ${this.originCode} ➔ ${this.destCode}`)
            .fontSize(11)
            .fontColor('#38BDF8')
        }

        Blank()

        // 状态 Badge
        Text(this.isMapExposed ? '飞机已缩小' : 'FOCUS FIRST')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isMapExposed ? '#38BDF8' : '#4ADE80')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.isMapExposed ? 'rgba(56, 189, 248, 0.18)' : 'rgba(74, 222, 128, 0.12)')
          .border({ width: 1, color: this.isMapExposed ? 'rgba(56, 189, 248, 0.4)' : 'rgba(74, 222, 128, 0.3)', radius: 10 })
          .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 12 })
      .backgroundColor('rgba(10, 15, 26, 0.88)')
      .border({ width: { bottom: 1 }, color: 'rgba(255, 255, 255, 0.1)' })
      .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.5)', offsetY: 4 })
      .zIndex(100)

      // ==========================================
      // 3. 飞机与机舱选座整体 Body (支持整体 3D 缩小退场，露出背后地图)
      // ==========================================
      Column({ space: 0 }) {
        // 3a. 缩小状态下的浮空点击放大提示卡片
        if (this.isMapExposed) {
          Row({ space: 8 }) {
            Text('✨ 飞机已缩小展示背后航线 · 点击卡片展开选座')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F8FAFC')
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ top: 10, bottom: 8 })
          .backgroundColor('rgba(56, 189, 248, 0.25)')
          .border({ width: 1, color: '#38BDF8', radius: 16 })
          .borderRadius(16)
          .shadow({ radius: 12, color: 'rgba(56, 189, 248, 0.4)' })
          .onClick(() => {
            this.resetCabinScale();
          })
        }

        // 3b. 完整飞机选座舱 Body 容器
        Column() {
          Scroll() {
            Column({ space: 20 }) {
              // 1) 1:1 完整飞机机头（雷达罩 + 风挡玻璃）
              Stack({ alignContent: Alignment.Top }) {
                Column()
                  .width(90)
                  .height(60)
                  .backgroundColor('rgba(255, 255, 255, 0.03)')
                  .border({ width: 2, color: 'rgba(255, 255, 255, 0.15)', radius: { topLeft: 45, topRight: 45 } })
                  .borderRadius({ topLeft: 45, topRight: 45 })
                  .offset({ y: 0 })

                Column()
                  .width(280)
                  .height(150)
                  .backgroundColor('rgba(255, 255, 255, 0.03)')
                  .border({ width: 2, color: 'rgba(255, 255, 255, 0.15)', radius: { topLeft: 140, topRight: 140 } })
                  .borderRadius({ topLeft: 140, topRight: 140 })
                  .offset({ y: 40 })

                Row({ space: 8 }) {
                  Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 16, topRight: 4 })
                  Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 4, topRight: 4 })
                  Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 4, topRight: 4 })
                  Row().width(52).height(30).backgroundColor('rgba(2, 6, 23, 0.9)').borderRadius({ topLeft: 4, topRight: 16 })
                }
                .offset({ y: 98 })
              }
              .width('100%')
              .height(190)

              // 2) 座位状态图例
              Row({ space: 16 }) {
                Row({ space: 6 }) {
                  Row().width(12).height(12).backgroundColor('rgba(255, 255, 255, 0.15)').border({ width: 1, color: 'rgba(255, 255, 255, 0.3)', radius: 3 }).borderRadius(3)
                  Text('可选空座').fontSize(10).fontColor('#94A3B8')
                }

                Row({ space: 6 }) {
                  Row().width(12).height(12).backgroundColor('#38BDF8').borderRadius(3)
                  Text('已选择').fontSize(10).fontColor('#38BDF8')
                }

                Row({ space: 6 }) {
                  Row().width(12).height(12).backgroundColor('rgba(15, 23, 42, 0.8)').border({ width: 0.5, color: 'rgba(148, 163, 184, 0.2)', radius: 3 }).borderRadius(3)
                  Text('已被占用').fontSize(10).fontColor('rgba(148, 163, 184, 0.5)')
                }
              }

              // 3) 商务舱 Business
              Column({ space: 14 }) {
                Row() {
                  Text('Business')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#F8FAFC')
                  Blank()
                  Text('2 x 2 豪华宽座舱')
                    .fontSize(12)
                    .fontColor('#38BDF8')
                }
                .width('100%')
                .padding({ left: 16, right: 16 })

                Row() {
                  Row({ space: 20 }) {
                    Text('A').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                    Text('B').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                    Text('C').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                  }
                  Blank()
                  Text('过道').fontSize(10).fontColor('rgba(148, 163, 184, 0.35)')
                  Blank()
                  Row({ space: 20 }) {
                    Text('D').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                    Text('E').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                    Text('F').fontSize(12).fontColor('#94A3B8').width(32).textAlign(TextAlign.Center)
                  }
                }
                .width('100%')
                .padding({ left: 32, right: 32 })

                ForEach([1, 2], (rowNum: number) => {
                  Row() {
                    Text(`${rowNum}`).fontSize(12).fontColor('#94A3B8').width(20)
                    Row({ space: 16 }) {
                      ForEach(['A', 'B', 'C'], (col: string) => {
                        this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Business')
                      })
                    }
                    Blank()
                    Row({ space: 16 }) {
                      ForEach(['D', 'E', 'F'], (col: string) => {
                        this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Business')
                      })
                    }
                    Text(`${rowNum}`).fontSize(12).fontColor('#94A3B8').width(20).textAlign(TextAlign.End)
                  }
                  .width('100%')
                  .padding({ left: 10, right: 10 })
                })
              }
              .width('100%')

              Divider().color('rgba(255, 255, 255, 0.08)')

              // 4) 经济舱 Economy
              Column({ space: 14 }) {
                Row() {
                  Text('Economy')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#F8FAFC')
                  Blank()
                  Text('3 x 3 舒适标准座')
                    .fontSize(12)
                    .fontColor('#94A3B8')
                }
                .width('100%')
                .padding({ left: 16, right: 16 })

                ForEach([3, 4, 5, 6, 7, 8, 9, 10], (rowNum: number) => {
                  Row() {
                    Text(`${rowNum}`).fontSize(12).fontColor('#94A3B8').width(20)
                    Row({ space: 16 }) {
                      ForEach(['A', 'B', 'C'], (col: string) => {
                        this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Economy')
                      })
                    }
                    Blank()
                    Row({ space: 16 }) {
                      ForEach(['D', 'E', 'F'], (col: string) => {
                        this.SeatTile(`${rowNum}${col}`, rowNum, col, 'Economy')
                      })
                    }
                    Text(`${rowNum}`).fontSize(12).fontColor('#94A3B8').width(20).textAlign(TextAlign.End)
                  }
                  .width('100%')
                  .padding({ left: 10, right: 10 })
                })
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 80 })
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
        .width('94%')
        .height(this.isMapExposed ? 480 : '82%')
        .backgroundColor(this.isMapExposed ? 'rgba(10, 15, 26, 0.88)' : 'rgba(10, 15, 26, 0.95)')
        .border({ width: 1, color: this.isMapExposed ? 'rgba(56, 189, 248, 0.4)' : 'rgba(255, 255, 255, 0.12)', radius: 24 })
        .borderRadius(24)
        .shadow({ radius: this.isMapExposed ? 32 : 12, color: 'rgba(0, 0, 0, 0.8)', offsetY: 8 })
        .onClick(() => {
          if (this.isMapExposed) {
            this.resetCabinScale();
          }
        })
      }
      .width('100%')
      .margin({ top: 105 })
      .scale({ x: this.seatCardScale, y: this.seatCardScale })
      .translate({ y: this.seatCardY })
      .opacity(this.seatCardOpacity)
      .animation({ duration: 750, curve: Curve.FastOutSlowIn })
      .zIndex(50)

      // ==========================================
      // 4. 底部固定战术确认栏 (Sticky Bottom Bar)
      // ==========================================
      Row() {
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text('已选座位:')
              .fontSize(12)
              .fontColor('#94A3B8')
            Text(this.selectedSeatId)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#38BDF8')
          }

          Text(this.selectedSeatId.endsWith('A') || this.selectedSeatId.endsWith('F') ? '靠窗 Seat · 视野极佳' : '靠近过道 · 出入顺畅')
            .fontSize(11)
            .fontColor('rgba(248, 250, 252, 0.7)')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 若已缩小显示地图，提供“放大选座”辅助按钮
        if (this.isMapExposed) {
          Row() {
            Text('放大选座')
              .fontSize(12)
              .fontColor('#38BDF8')
          }
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .margin({ right: 10 })
          .backgroundColor('rgba(56, 189, 248, 0.15)')
          .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 18 })
          .borderRadius(18)
          .onClick(() => {
            this.resetCabinScale();
          })
        }

        // 确认选座生成登机牌主 Action 按钮
        Row({ space: 6 }) {
          Text('确认选座并完成值机')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#020617')
          Text('➔')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#020617')
        }
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .backgroundColor('#4ADE80')
        .borderRadius(24)
        .shadow({ radius: 16, color: 'rgba(74, 222, 128, 0.45)', offsetY: 4 })
        .onClick(() => {
          this.triggerHaptic();
          const startTimeMs = Date.now();
          const sessionData: FlightSessionData = {
            isFlightActive: true,
            flightNo: this.flightNo,
            seatId: this.selectedSeatId,
            taskTitle: '💻 深度编程',
            durationMin: this.focusMinutesVal,
            originCode: this.originCode,
            destCode: this.destCode,
            startTimeMs: startTimeMs
          };
          FlightSessionStore.saveSession(sessionData);

          router.pushUrl({
            url: 'pages/Index',
            params: sessionData
          });
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 24 })
      .backgroundColor('rgba(10, 15, 26, 0.95)')
      .border({ width: { top: 1 }, color: 'rgba(255, 255, 255, 0.12)' })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.9)', offsetY: -6 })
      .position({ y: '100%' })
      .markAnchor({ y: '100%' })
      .zIndex(100)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
  }

  // 单个 SeatTile 组件
  @Builder
  SeatTile(seatId: string, row: number, col: string, cabin: string) {
    Column() {
      if (this.isSeatSelected(seatId)) {
        Text('✓')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      } else {
        Column()
          .width(22)
          .height(12)
          .backgroundColor(this.isSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.15)' : 'rgba(255, 255, 255, 0.25)')
          .borderRadius({ topLeft: 4, topRight: 4 })
      }
    }
    .width(34)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isSeatSelected(seatId) ? '#38BDF8' : (this.isSeatOccupied(row, col) ? 'rgba(15, 23, 42, 0.8)' : 'rgba(255, 255, 255, 0.08)'))
    .border({
      width: this.isSeatSelected(seatId) ? 1.5 : (this.isSeatOccupied(row, col) ? 0.5 : 1),
      color: this.isSeatSelected(seatId) ? '#38BDF8' : (this.isSeatOccupied(row, col) ? 'rgba(148, 163, 184, 0.2)' : 'rgba(255, 255, 255, 0.2)'),
      radius: 8
    })
    .borderRadius(8)
    .shadow({ radius: this.isSeatSelected(seatId) ? 10 : 0, color: 'rgba(56, 189, 248, 0.65)' })
    .onClick(() => {
      if (this.isSeatOccupied(row, col)) return;
      this.selectedSeatId = seatId;
      this.selectedCabin = cabin;
      this.triggerHaptic();

      // ✨ 当点击座椅时，整架飞机/选座舱卡片平滑 3D 缩小退场，100% 震撼露出背后的 Petal Maps & 战术航线地图！
      this.getUIContext()?.animateTo({ duration: 750, curve: Curve.FastOutSlowIn }, () => {
        this.isMapExposed = true;
        this.seatCardScale = 0.48;
        this.seatCardY = -40;
        this.seatCardOpacity = 0.75;
        this.mapOpacity = 1.0;
        this.mapZoomScale = 1.12;
      });

      if (this.huaweiMapController) {
        try {
          this.huaweiMapController.animateCamera(map.newCameraPosition({
            target: { latitude: 30.561432, longitude: 103.942466 },
            zoom: 14.5,
            bearing: 0,
            tilt: 0
          }), 1000);
        } catch (e) { }
      }
    })
  }
}
