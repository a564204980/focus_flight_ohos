import { promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { HomeFocusPanel } from '../components/HomeFocusPanel';
import { CabinInteriorOverlay } from '../components/CabinInteriorOverlay';
import { getCustomRunwaysForAirport, getCustomTaxiwaysForAirport } from '../models/AirportRunwayConfig';
import {
  generateThresholdZebraStripes,
  generateTouchdownZoneMarkings,
  interpolateRunwayPoint,
  generatePAPILightPoints,
  LatLngPoint
} from '../utils/GeodesicUtils';

@Entry
@Component
struct Index {
  // === 沉浸式物理刹停与停靠动画状态 ===
  @State planeY: number = -45;                   // 飞机及阴影纵向位置（固定原位）
  @State planeScale: number = 1.0;               // 飞机与阴影原位 3D 缩放比例
  @State isFullFocusMode: boolean = false;       // 11.8倍极简沉浸专注模式（隐藏所有UI）
  @State isCabinExposed: boolean = false;        // 飞机放大后机身外壳剖开状态
  @State shellSplitOffset: number = 0;           // 机壳剖开向两侧滑移偏移量
  @State isMapBackgroundVisible: boolean = false; // 只有当飞机放大完毕后，底部才无缝切为花瓣地图精修机场
  @State isVehiclesDocked: boolean = false;      // 勤务车辆与廊桥对接状态
  @State fuelTruckX: number = -350;              // 加油车 X 坐标
  @State fuelTruckY: number = 220;               // 加油车 Y 坐标
  @State fuelTruckRotate: number = 90;           // 加油车车头角度
  @State isHudVisible: boolean = false;          // Cyber HUD 界面可见状态
  @State isFuelTruckParked: boolean = false;     // 加油车已完成驶入并停稳标志
  @State isFuelTruckDeparting: boolean = false;  // 加油车正在驶离标志
  @State honkToastText: string = '';             // 提示文本
  @State isHonkToastVisible: boolean = false;    // 提示框显隐

  private animTimer: number = -1;
  private huaweiMapController?: map.MapComponentController;

  // 华为花瓣地图初始配置：默认卫星图 SATELLITE + 精修 CTU 机场跑道/滑行道
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 30.561432,
        longitude: 103.942466
      },
      zoom: 16.5,
      bearing: 25.5,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE,
    zoomControlsEnabled: false,
    compassControlsEnabled: false,
    rotateGesturesEnabled: true,
    zoomGesturesEnabled: true
  };

  private huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.setupHuaweiMap(controller);
    }
  };

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 1. 绘制 CTU 成都双流精修跑道多边形 (双平行跑道 + ICAO 战术标线与灯光阵列)
      const customRunwayPolygons = getCustomRunwaysForAirport('CTU');
      if (customRunwayPolygons) {
        for (const corners of customRunwayPolygons) {
          await this.drawSingleRunway(controller, corners);
        }
      }

      // 2. 绘制 CTU 精修滑行道网络 (Refined Taxiways)
      const customTaxiways = getCustomTaxiwaysForAirport('CTU');
      if (customTaxiways) {
        for (const taxiway of customTaxiways) {
          await this.drawTaxiways(controller, taxiway);
        }
      }
    } catch (e) {
      console.error('Index Petal Map setup error:', JSON.stringify(e));
    }
  }

  /**
   * ✈️ 绘制机场滑行道网络 (Cyan/Blue 发光折线)
   */
  private async drawTaxiways(
    controller: map.MapComponentController,
    taxiwayPoints: Array<mapCommon.LatLng>
  ): Promise<void> {
    if (!taxiwayPoints || taxiwayPoints.length < 2) return;

    await controller.addPolyline({
      points: taxiwayPoints,
      width: 14,
      color: 0x660284C7
    });

    await controller.addPolyline({
      points: taxiwayPoints,
      width: 8,
      color: 0xFF00FFCC,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 16 }
      ]
    });
  }

  /**
   * ✈️ 模块化单条跑道完整 ICAO 战术灯光与标线渲染函数 (成都双流 CTU 精修)
   */
  private async drawSingleRunway(
    controller: map.MapComponentController,
    runwayPolygonPoints: Array<mapCommon.LatLng>
  ): Promise<void> {
    if (!runwayPolygonPoints || runwayPolygonPoints.length < 4) return;

    // 1. 跑道物理路面 (深暗黑沉浸式沥青基底 + 柔和银白边界防碰撞线)
    await controller.addPolygon({
      points: runwayPolygonPoints,
      fillColor: 0xEE0B132B,
      strokeColor: 0x8894A3B8,
      strokeWidth: 2
    });

    // 跑道左右两侧物理边缘高亮白线
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 3,
      color: 0xFFF8FAFC
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 3,
      color: 0xFFF8FAFC
    });

    // 2. 跑道入口白色斑马线标志 (Threshold Zebra Markings)
    const zebraStripes = generateThresholdZebraStripes(runwayPolygonPoints, 10);
    for (let stripe of zebraStripes) {
      await controller.addPolyline({
        points: stripe,
        width: 3,
        color: 0xFFF8FAFC
      });
    }

    // 3. 跑道接地带双侧矩形标志 (Touchdown Zone Markings)
    const touchdownMarkings = generateTouchdownZoneMarkings(runwayPolygonPoints);
    for (let marking of touchdownMarkings) {
      await controller.addPolyline({
        points: marking,
        width: 4,
        color: 0xEEE2E8F0
      });
    }

    // 4. 跑道双层发光中线
    const centerStart = interpolateRunwayPoint(runwayPolygonPoints, 0.5, 0);
    const centerEnd = interpolateRunwayPoint(runwayPolygonPoints, 0.5, 1);

    await controller.addPolyline({
      points: [centerStart, centerEnd],
      width: 10,
      color: 0x6638BDF8
    });
    await controller.addPolyline({
      points: [centerStart, centerEnd],
      width: 5,
      color: 0xFFFFFFFF,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 18 },
        { type: mapCommon.PatternItemType.GAP, length: 12 }
      ]
    });

    // 5. 跑道两侧琥珀金高亮离散灯珠阵列
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 14,
      color: 0x88F59E0B
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 6,
      color: 0xFFFEF08A,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 12 }
      ]
    });

    await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 14,
      color: 0x88F59E0B
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 6,
      color: 0xFFFEF08A,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 12 }
      ]
    });

    // 6. 跑道入口翡翠绿璀璨灯阵
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[3]],
      width: 16,
      color: 0xAA10B981
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[3]],
      width: 6,
      color: 0xFFD1FAE5,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 6 }
      ]
    });

    // 7. 跑道末端烈焰红止步警告灯阵
    await controller.addPolyline({
      points: [runwayPolygonPoints[1], runwayPolygonPoints[2]],
      width: 16,
      color: 0xAAEF4444
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[1], runwayPolygonPoints[2]],
      width: 6,
      color: 0xFFFEE2E2,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 6 }
      ]
    });

    // 8. PAPI 进近轨迹指示灯阵列
    const papiPoints = generatePAPILightPoints(runwayPolygonPoints);
    for (let i = 0; i < papiPoints.length; i++) {
      const papiPt = papiPoints[i];
      const isRed = i < 2;
      const colorVal = isRed ? 0xFFEF4444 : 0xFFFFFFFF;
      const haloVal = isRed ? 0x66EF4444 : 0x66FFFFFF;

      await controller.addPolyline({
        points: [papiPt, { latitude: papiPt.latitude + 0.00001, longitude: papiPt.longitude + 0.00001 }],
        width: 12,
        color: haloVal
      });
      await controller.addPolyline({
        points: [papiPt, { latitude: papiPt.latitude + 0.00001, longitude: papiPt.longitude + 0.00001 }],
        width: 6,
        color: colorVal
      });
    }
  }

  aboutToAppear() {
    this.startAnimationSequence();
  }

  onPageShow() {
    this.startAnimationSequence();
  }

  /**
   * 当用户在首页放大的机舱中点击任意座椅时：
   * 彻底取消页面跳转！在当前页面内实现纯 3D 无缝缩小退场与背后华为 Petal Maps 地图的平滑浮现
   */
  private onSeatSelectedInIndex(seatId: string) {
    this.honkToastText = `✨ 已选择座位 ${seatId} · 战术航线与地图无缝就绪`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3000);

    // 1. 400ms 平滑缝合剖开的机身外壳
    this.getUIContext()?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
      this.shellSplitOffset = 0;
    });

    // 2. 0.35 秒后隐藏机舱透视，飞机平滑 3D 缩小至原大小，背后的华为 Petal Maps 地图无缝淡入浮现！
    setTimeout(() => {
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.isMapBackgroundVisible = true; // 背后华为花瓣地图无缝出现！

      // 飞机在当前页面平滑 3D 缩小至 1.0 倍
      this.getUIContext()?.animateTo({ duration: 1600, curve: Curve.FastOutSlowIn }, () => {
        this.planeScale = 1.0;
        this.planeY = -45;
      });

      // 恢复周围地勤设备与 HUD 界面
      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = true;
        this.isHudVisible = true;
      });
    }, 350);
  }

  private triggerHapticFeedback(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 30
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (e) {
      // ignore
    }
  }

  private runFuelTruckDepartureAnimation() {
    if (this.isFuelTruckDeparting) return;
    this.isFuelTruckDeparting = true;
    this.isFuelTruckParked = false;

    this.triggerHapticFeedback();
    this.honkToastText = '⛽ 航油已加满！加油车打火启动，从翼下驶离停机坪...';
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3200);

    const duration = 3500;
    const startTime = Date.now();

    const startX = this.fuelTruckX;
    const startY = this.fuelTruckY;

    // 离场三阶贝塞尔路径：从飞机翼下停靠点转向，从机翼腹部下方滑过并驶离屏幕
    const p0x = startX, p0y = startY;
    const p1x = -10,   p1y = -160;
    const p2x = 180,   p2y = -260;
    const p3x = 480,   p3y = -360;

    let departureTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      let rawT = elapsed / duration;

      if (rawT >= 1.0) {
        rawT = 1.0;
        clearInterval(departureTimer);
      }

      let t = rawT;
      const mt = 1 - t;
      const x = mt * mt * mt * p0x + 3 * mt * mt * t * p1x + 3 * mt * t * t * p2x + t * t * t * p3x;
      const y = mt * mt * mt * p0y + 3 * mt * mt * t * p1y + 3 * mt * t * t * p2y + t * t * t * p3y;

      const dx = 3 * mt * mt * (p1x - p0x) + 6 * mt * t * (p2x - p1x) + 3 * t * t * (p3x - p2x);
      const dy = 3 * mt * mt * (p1y - p0y) + 6 * mt * t * (p2y - p1y) + 3 * t * t * (p3y - p2y);

      const angleRad = Math.atan2(dy, dx);
      const angleDeg = angleRad * (180 / Math.PI) + 90;

      this.fuelTruckX = x;
      this.fuelTruckY = y;
      this.fuelTruckRotate = angleDeg;
    }, 16);
  }

  private onFuelTruckClick(): void {
    if (!this.isFuelTruckDeparting) {
      this.runFuelTruckDepartureAnimation();
    } else {
      this.triggerHapticFeedback();
      this.honkToastText = '⛽ 勤务加油车已完成任务并驶离停机坪';
      this.isHonkToastVisible = true;
      setTimeout(() => {
        this.isHonkToastVisible = false;
      }, 2500);
    }
  }

  private onTractorClick(): void {
    this.triggerHapticFeedback();
    this.honkToastText = '🚜 勤务牵引车就绪 · 轮档已撤除，随时准备离港后推！';
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 3000);
  }

  /**
   * 启动开场动画
   */
  private startAnimationSequence() {
    this.planeY = 450;
    this.isVehiclesDocked = false;
    this.fuelTruckX = -350;
    this.fuelTruckY = 220;
    this.fuelTruckRotate = 90;
    this.isHudVisible = false;
    this.isFuelTruckParked = false;
    this.isFuelTruckDeparting = false;
    this.isHonkToastVisible = false;
    this.isMapBackgroundVisible = false;

    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }

    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 1700, curve: Curve.Friction }, () => {
        this.planeY = -48;
      });

      setTimeout(() => {
        this.getUIContext()?.animateTo({ duration: 350, curve: Curve.FastOutSlowIn }, () => {
          this.planeY = -45;
        });
      }, 1700);

      setTimeout(() => {
        this.isVehiclesDocked = true;
        this.runRealTruckPhysicsAnimation();
      }, 2050);

      setTimeout(() => {
        this.isHudVisible = true;
      }, 3000);
    }, 50);
  }

  private runRealTruckPhysicsAnimation() {
    const duration = 4600;
    const startTime = Date.now();

    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
    }

    this.animTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      let rawT = elapsed / duration;

      if (rawT >= 1.0) {
        rawT = 1.0;
        clearInterval(this.animTimer);
        this.animTimer = -1;
        this.isFuelTruckParked = true;
      }

      let t = rawT;
      if (rawT > 0.85) {
        const subT = (rawT - 0.85) / 0.15;
        t = 0.85 + 0.15 * (1 - Math.pow(1 - subT, 2));
      }

      const p0x = -350, p0y = 220;
      const p1x = 180,  p1y = 220;
      const p2x = 220,  p2y = 40;
      const p3x = 120,  p3y = -85;

      const mt = 1 - t;
      const x = mt * mt * mt * p0x + 3 * mt * mt * t * p1x + 3 * mt * t * t * p2x + t * t * t * p3x;
      const y = mt * mt * mt * p0y + 3 * mt * mt * t * p1y + 3 * mt * t * t * p2y + t * t * t * p3y;

      const dx = 3 * mt * mt * (p1x - p0x) + 6 * mt * t * (p2x - p1x) + 3 * t * t * (p3x - p2x);
      const dy = 3 * mt * mt * (p1y - p0y) + 6 * mt * t * (p2y - p1y) + 3 * t * t * (p3y - p2y);

      const angleRad = Math.atan2(dy, dx);
      const angleDeg = angleRad * (180 / Math.PI) + 90;

      this.fuelTruckX = x;
      this.fuelTruckY = y;
      this.fuelTruckRotate = angleDeg;
    }, 16);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 全屏背景层 (未放大时为停机坪 bg_1，仅在【飞机完全放大完毕】或【点击座椅后】无缝切为华为花瓣地图精修机场)
      Stack({ alignContent: Alignment.Center }) {
        // 底层：停机坪地面
        Image($r('app.media.bg_1'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .scale({ x: 1.05, y: 1.05 })
          .translate({ x: 4 })
          .opacity(this.isMapBackgroundVisible ? 0 : 1)
          .animation({ duration: 800, curve: Curve.EaseInOut })

        // 上层：华为原生花瓣地图 (Petal Maps) 精修机场地图
        if (this.isMapBackgroundVisible) {
          MapComponent({ mapOptions: this.huaweiMapOptions, mapCallback: this.huaweiMapCallback })
            .width('100%')
            .height('100%')
            .opacity(this.isMapBackgroundVisible ? 1 : 0)
            .animation({ duration: 800, curve: Curve.EaseInOut })
        }
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 2. 顶部问候栏
      Row() {
        Column({ space: 4 }) {
          Text('早上好')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Row({ space: 4 }) {
            Text('✔')
              .fontSize(11)
              .fontColor('#10B981')
            Text('航班就绪')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#64748B')
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 8 }) {
          Row() {
            Text('CTU')
              .fontSize(11)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#D97706')
          }
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('rgba(245, 158, 11, 0.15)')
          .border({ width: 1, color: 'rgba(217, 119, 6, 0.35)', radius: 6 })
          .borderRadius(6)

          Row({ space: 5 }) {
            Circle({ width: 5, height: 5 })
              .fill('#10B981')

            Text('成都双流国际机场')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F172A')
          }
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 50, bottom: 8 })
      .position({ y: 0 })
      .opacity((this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 1 : 0)
      .animation({ duration: 800, curve: Curve.EaseOut })
      .zIndex(50)

      // Toast 战术提示浮标
      if (this.isHonkToastVisible) {
        Row({ space: 8 }) {
          Text(this.honkToastText)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('rgba(10, 15, 26, 0.9)')
        .border({ width: 1, color: '#38BDF8', radius: 20 })
        .borderRadius(20)
        .shadow({ radius: 16, color: 'rgba(56, 189, 248, 0.5)', offsetY: 4 })
        .position({ y: 110 })
        .zIndex(300)
      }

      // 1. 牵引车阴影
      Image($r('app.media.qiangyingche_shadow'))
        .width(90)
        .height(90)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .translate({
          x: (this.isVehiclesDocked ? -125 : -340) + 2,
          y: (this.isVehiclesDocked ? -90 : 120)+3
        })
        .rotate({ angle: this.isVehiclesDocked ? 0 : 45 })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 2. 加油车阴影
      Image($r('app.media.jiayouche_shadow'))
        .width(110)
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .translate({
          x: this.fuelTruckX + 4,
          y: this.fuelTruckY + 4
        })
        .rotate({ angle: this.fuelTruckRotate })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 3. 廊桥阴影（1.0 满不透明度，还原图 2 极富立体感的浓重暗部阴影）
      Image($r('app.media.langqiao_shadow'))
        .width(320)
        .height(163.6)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .translate({
          x: (this.isVehiclesDocked ? -150 : -380) +36,
          y: -160 + 18
        })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 4. 飞机本体地面阴影（1.0 满不透明度，暗部浓郁沉浸）
      Image($r('app.media.b737_800_top_3_shadow'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1.0)
        .scale({ x: this.planeScale, y: this.planeScale })
        .translate({ x: 8, y: this.planeY + 20 })
        .hitTestBehavior(HitTestMode.None)

      // === 实体层 ===

      // 1. 地面勤务车辆（加油车）
      Image($r('app.media.jiayouche'))
        .width(110)
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .translate({
          x: this.fuelTruckX,
          y: this.fuelTruckY
        })
        .rotate({ angle: this.fuelTruckRotate })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .onClick(() => {
          this.onFuelTruckClick();
        })

      // 2. 地面勤务车辆（牵引车）
      Image($r('app.media.qiangyingche'))
        .width(90)
        .height(90)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .translate({
          x: this.isVehiclesDocked ? -125 : -340,
          y: this.isVehiclesDocked ? -90 : 120
        })
        .rotate({ angle: this.isVehiclesDocked ? 0 : 45 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .onClick(() => {
          this.onTractorClick();
        })

      // 3. 飞机本体
      Image($r('app.media.b737_800_top_3'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .scale({ x: this.planeScale, y: this.planeScale })
        .translate({ y: this.planeY })
        .hitTestBehavior(HitTestMode.Transparent)

      // 3b. 放大后的机身无缝剖开与透视机舱 layer
      if (this.isCabinExposed) {
        Stack({ alignContent: Alignment.Center }) {
          // 下层：全景机舱内部与座位
          CabinInteriorOverlay({
            onSeatClick: (seatId: string): void => {
              this.onSeatSelectedInIndex(seatId);
            }
          })
            .opacity(this.isCabinExposed ? 1 : 0)
            .scale({ x: this.isCabinExposed ? 1 : 0.9, y: this.isCabinExposed ? 1 : 0.9 })
            .animation({ duration: 600, curve: Curve.EaseOut })

          // 上层：与主飞机 100% 保持同等 11.8 倍放大倍率的左右剖开外壳
          Row() {
            // 左半机身真实外壳
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.b737_800_top_3'))
                .width(300)
                .height(428.7)
                .objectFit(ImageFit.Contain)
                .scale({ x: this.planeScale, y: this.planeScale })
                .translate({ x: 82.5, y: this.planeY - 50 })

              Column()
                .width('100%')
                .height('100%')
                .border({ width: { right: 2 }, color: 'rgba(180, 160, 140, 0.85)' })
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.12)', offsetX: 3 })
            }
            .width('50%')
            .height('100%')
            .clip(true)
            .translate({ x: -this.shellSplitOffset })
            .opacity(1 - this.shellSplitOffset / 320)

            // 右半机身真实外壳
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.b737_800_top_3'))
                .width(300)
                .height(428.7)
                .objectFit(ImageFit.Contain)
                .scale({ x: this.planeScale, y: this.planeScale })
                .translate({ x: -82.5, y: this.planeY - 50 })

              Column()
                .width('100%')
                .height('100%')
                .border({ width: { left: 2 }, color: 'rgba(180, 160, 140, 0.85)' })
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.12)', offsetX: -3 })
            }
            .width('50%')
            .height('100%')
            .clip(true)
            .translate({ x: this.shellSplitOffset })
            .opacity(1 - this.shellSplitOffset / 320)
          }
          .width('100%')
          .height('100%')
          .clip(true)
          .hitTestBehavior(HitTestMode.None)
        }
        .width('88%')
        .height(530)
        .borderRadius(24)
        .clip(true)
        .translate({ y: 50 })
        .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.08)', offsetY: 4 })
        .zIndex(20)
      }

      // 4. 廊桥本体
      Image($r('app.media.langqiao'))
        .width(320)
        .height(163.6)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .translate({ x: this.isVehiclesDocked ? -150 : -380, y: -160 })
        .animation({ duration: 800, curve: Curve.EaseOut })

      // 5. 底部专注控制面板
      HomeFocusPanel({
        onStartFlight: () => {
          this.triggerPureScaleAnimation();
        }
      })
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })
        .opacity((this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 1 : 0)
        .translate({ y: (this.isHudVisible && !this.isFullFocusMode && !this.isMapBackgroundVisible) ? 0 : 260 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .zIndex(100)

      // 6. 客舱透视或纯净地图模式下的左上角返回按钮
      if (this.isCabinExposed || (this.isMapBackgroundVisible && !this.isCabinExposed)) {
        Row() {
          Image($r('app.media.ic_back_btn'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor('rgba(10, 15, 26, 0.85)')
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.25)', radius: 21 })
        .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.4)', offsetY: 2 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .position({ x: 18, y: 44 })
        .zIndex(200)
        .onClick(() => {
          this.triggerPureScaleAnimation();
        })
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      if (this.isFullFocusMode) {
        this.triggerPureScaleAnimation();
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 触发飞机原位慢慢放大至 11.8 倍 -> 等飞机放大完毕后，露出华为 Petal Maps 精修机场地图与机舱
   */
  private triggerPureScaleAnimation() {
    if (!this.isFullFocusMode) {
      this.isFullFocusMode = true;
      this.isMapBackgroundVisible = false;

      // 阶段一：2.5 秒内飞机原位平滑放大到 11.8 倍
      this.getUIContext()?.animateTo({ duration: 2500, curve: Curve.EaseInOut }, () => {
        this.planeScale = 11.8;
        this.planeY = 1200;
      });

      // 阶段二：放大完毕后，剖开机舱
      setTimeout(() => {
        if (this.isFullFocusMode) {
          this.getUIContext()?.animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
            this.isCabinExposed = true;
            this.isMapBackgroundVisible = true;
          });
          this.getUIContext()?.animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
            this.shellSplitOffset = 160;
          });
        }
      }, 2400);

      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = false;
      });
    } else {
      // 退出沉浸专注模式：背景先平滑切回停机坪地面，关合缝合机壳，再缩小飞机
      this.getUIContext()?.animateTo({ duration: 400, curve: Curve.EaseIn }, () => {
        this.shellSplitOffset = 0;
        this.isMapBackgroundVisible = false;
      });

      setTimeout(() => {
        this.isCabinExposed = false;
        this.isFullFocusMode = false;

        this.getUIContext()?.animateTo({ duration: 2000, curve: Curve.EaseInOut }, () => {
          this.planeScale = 1.0;
          this.planeY = -45;
        });

        this.getUIContext()?.animateTo({ duration: 1200, curve: Curve.EaseOut }, () => {
          this.isVehiclesDocked = true;
        });
      }, 400);
    }
  }
}