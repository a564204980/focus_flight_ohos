import { promptAction, router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { HomeFocusPanel } from '../components/HomeFocusPanel';
import { CabinInteriorOverlay } from '../components/CabinInteriorOverlay';
import { getCustomRunwaysForAirport, getCustomTaxiwaysForAirport, getAirportTakeoffRunway } from '../models/AirportRunwayConfig';
import { FlightSessionStore, FlightSessionData } from '../services/FlightSessionStore';
import {
  generateThresholdZebraStripes,
  generateTouchdownZoneMarkings,
  interpolateRunwayPoint,
  generatePAPILightPoints,
  generateGreatCirclePoints,
  generateCubicBezierPoints,
  generateQuadraticBezierPoints,
  chaikinSmoothPath,
  LatLngPoint,
  calculateBearing,
  interpolateLatLng,
  calculateCameraTargetForAnchor
} from '../utils/GeodesicUtils';



import { ctuAirportConfig } from '../models/airports/ctu';
import { pekAirportConfig } from '../models/airports/pek';

// ✈️ 动态从 ctuAirportConfig 直接读取起飞跑道起点与终点，100% 实时响应 ctu.ets 的任何修改！
function getCtuRunwayStart(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.start || { latitude: 30.592085, longitude: 103.958889 };
}

function getCtuRunwayEnd(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.end || { latitude: 30.562957, longitude: 103.945340 };
}

const CTU_RUNWAY_BEARING: number = ctuAirportConfig.runwayAngle ?? 158;

// ✈️ 默认飞行终点：北京首都国际机场 (PEK) 跑道数据（用于三阶段航线无缝连接）
function getPekRunwayStart(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.start || { latitude: 40.079857, longitude: 116.603114 };
}

function getPekRunwayEnd(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.end || { latitude: 40.091200, longitude: 116.615000 };
}


@Entry
@Component
struct Index {
  // === 沉浸式物理刹停与停靠动画状态 ===
  @State planeY: number = -45;                   // 飞机及阴影纵向位置（固定原位）
  @State planeX: number = 0;                     // 飞机及阴影横向对齐偏移（地图模式对齐跑道红点）
  @State planeScale: number = 1.0;               // 飞机与阴影原位 3D 缩放比例
  @State isPlaneMarkerActive: boolean = false;   // 动画完成后是否交接给地图原生 Marker
  @State currentZoomScale: number = 1.0;         // 随地图 Zoom 级别动态计算的物理比例 (2^(zoom - 17.2))
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
  @State currentZoomLevel: number = 17.2;        // 当前地图缩放级别 Zoom
  @State currentMapBearing: number = CTU_RUNWAY_BEARING; // 当前地图方位角度 Bearing
  @State planeMarkerRotation: number = 0;        // Marker 标记当前旋转角度 (默认0度)

  private currentPlaneMarker?: map.Marker;       // 地图原生 Marker 实例
  private animTimer: number = -1;
  private huaweiMapController?: map.MapComponentController;

  // 华为花瓣地图初始配置：默认卫星图 SATELLITE + 精修 CTU 跑道垂直朝上对齐视角
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: getCtuRunwayStart().latitude,
        longitude: getCtuRunwayStart().longitude
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
        const targetPos = getCtuRunwayStart();
        console.info(`[CTU Camera] target=(${targetPos.latitude}, ${targetPos.longitude}) bearing=${CTU_RUNWAY_BEARING}`);
        mapCtrl.moveCamera(map.newCameraPosition({
          target: {
            latitude: targetPos.latitude,
            longitude: targetPos.longitude
          },
          zoom: 17.2,
          bearing: CTU_RUNWAY_BEARING,
          tilt: 0
        }));
      } catch (e) {
        console.error('applyRunwayCameraOrientation error:', JSON.stringify(e));
      }
    }
  }

  private huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.setupHuaweiMap(controller);
      // 双重保障：在 MapComponent 渲染表面完全稳定后强行平移并旋转地图视角！
      setTimeout(() => {
        this.applyRunwayCameraOrientation(controller);
      }, 150);
      setTimeout(() => {
        this.applyRunwayCameraOrientation(controller);
      }, 650);
    }
  };

  /**
   * ✈️ 采用二次贝塞尔倒角圆弧 (Quadratic Bézier Fillet Arc) 与大圆航线算法
   * 绘制 100% 自然光滑、大弧度倒角顺滑的无死角全图战术航线
   */
  private async drawThreePhaseFlightRoute(controller: map.MapComponentController): Promise<void> {
    const ctuStart = getCtuRunwayStart();
    const ctuVertex = getCtuRunwayEnd();
    const pekVertex = getPekRunwayStart();
    const pekEnd = getPekRunwayEnd();

    // 1. 成都双流 (CTU) 离场大圆弧关键点计算
    // 跑道直飞段：沿跑道中线直飞 65% 距离 (约 2.2km 跑道中线直线滑跑)
    const turnStartPoint = interpolateLatLng(ctuStart, ctuVertex, 0.65);
    // 离场倒角控制点：大幅延伸至跑道末端外侧 170% 处 (空中爬升远端控制点，向上冲出更远)
    const departureControlPoint = interpolateLatLng(ctuStart, ctuVertex, 1.70);
    // 高空巡航线切入点：扩展至远端 0.02 处 (约 30km 空中切入点，打造超大半径、极尽广阔宏伟的巨型离场大圆弧)
    const turnEndPoint = interpolateLatLng(ctuVertex, pekVertex, 0.02);

    // 2. 北京首都 (PEK) 进近大圆弧关键点计算
    const landingStartPoint = interpolateLatLng(ctuVertex, pekVertex, 0.98);
    const arrivalControlPoint = interpolateLatLng(pekVertex, pekEnd, -0.7);
    const landingEndPoint = interpolateLatLng(pekVertex, pekEnd, 0.65);

    // 3. 构造航线各段点集
    // (1) 跑道滑跑直飞段 (65% 跑道中线)
    const taxiSegment = generateGreatCirclePoints(ctuStart, turnStartPoint, 20);
    // (2) 巨型宏伟离场二次贝塞尔切线圆弧 (100 点高密度、超大弧度真圆弧)
    const departureArc = generateQuadraticBezierPoints(turnStartPoint, departureControlPoint, turnEndPoint, 100);
    // (3) 高空巡航大圆航线段
    const cruiseSegment = generateGreatCirclePoints(turnEndPoint, landingStartPoint, 150);
    // (4) 巨型宏伟进近二次贝塞尔切线圆弧 (100 点高密度、超大弧度真圆弧)
    const arrivalArc = generateQuadraticBezierPoints(landingStartPoint, arrivalControlPoint, landingEndPoint, 100);
    // (5) 降落跑道接地接地段
    const landingSegment = generateGreatCirclePoints(landingEndPoint, pekEnd, 15);

    // 4. 按功能和视觉主题划分为三阶段发光航线
    // 阶段 1：跑道离地 & 离场爬升大圆弧 (Cyber Cyan 蓝光)
    const phase1Points = [
      ...taxiSegment,
      ...departureArc.slice(1)
    ];

    // 阶段 2：高空大圆巡航 (Amber Gold 琥珀金)
    const phase2Points = cruiseSegment;

    // 阶段 3：进近切入 & 跑道接地接地 (Emerald Green 翡翠绿)
    const phase3Points = [
      ...arrivalArc,
      ...landingSegment.slice(1)
    ];

    // ----------------------------------------------------
    // 阶段 1：跑道离地蓝光发光线条 (Cyber Cyan)
    // ----------------------------------------------------
    await controller.addPolyline({ points: phase1Points, width: 16, color: 0x6638BDF8 });
    await controller.addPolyline({ points: phase1Points, width: 6, color: 0xFF38BDF8 });
    await controller.addPolyline({
      points: phase1Points,
      width: 3,
      color: 0xFFFFFFFF,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 12 },
        { type: mapCommon.PatternItemType.GAP, length: 8 }
      ]
    });

    // ----------------------------------------------------
    // 阶段 2：高空巡航琥珀金发光线条 (Amber Gold)
    // ----------------------------------------------------
    await controller.addPolyline({ points: phase2Points, width: 12, color: 0x66F59E0B });
    await controller.addPolyline({ points: phase2Points, width: 5, color: 0xFFF59E0B });
    await controller.addPolyline({
      points: phase2Points,
      width: 3,
      color: 0xFFFFFFFF,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 16 },
        { type: mapCommon.PatternItemType.GAP, length: 10 }
      ]
    });

    // ----------------------------------------------------
    // 阶段 3：北京接地翡翠绿发光线条 (Emerald Green)
    // ----------------------------------------------------
    await controller.addPolyline({ points: phase3Points, width: 14, color: 0x664ADE80 });
    await controller.addPolyline({ points: phase3Points, width: 6, color: 0xFF4ADE80 });
    await controller.addPolyline({
      points: phase3Points,
      width: 3,
      color: 0xFFFFFFFF,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 10 },
        { type: mapCommon.PatternItemType.GAP, length: 6 }
      ]
    });
  }

  /**
   * 🧭 旋转地图视角 90° (平滑动画过渡)
   */
  private rotateMapNextAngle(): void {
    this.triggerHapticFeedback();
    this.currentMapBearing = Math.round((this.currentMapBearing + 90) % 360);
    if (this.huaweiMapController) {
      try {
        const currentCam = this.huaweiMapController.getCameraPosition();
        this.huaweiMapController.animateCamera(map.newCameraPosition({
          target: currentCam?.target || getCtuRunwayStart(),
          zoom: currentCam?.zoom || 17.2,
          bearing: this.currentMapBearing,
          tilt: 0
        }), 500);
        this.honkToastText = `🧭 地图视角已旋转至 ${this.currentMapBearing}°`;
        this.isHonkToastVisible = true;
        setTimeout(() => {
          this.isHonkToastVisible = false;
        }, 2000);
      } catch (e) {
        console.error('rotateMapNextAngle error:', JSON.stringify(e));
      }
    }
  }

  /**
   * 📐 微调地图视角 Bearing 角度 (±1°)
   */
  private tweakMapBearing(deltaDeg: number): void {
    this.triggerHapticFeedback();
    this.currentMapBearing = Math.round((this.currentMapBearing + deltaDeg + 360) % 360);
    if (this.huaweiMapController) {
      try {
        const currentCam = this.huaweiMapController.getCameraPosition();
        this.huaweiMapController.moveCamera(map.newCameraPosition({
          target: currentCam?.target || getCtuRunwayStart(),
          zoom: currentCam?.zoom || 17.2,
          bearing: this.currentMapBearing,
          tilt: 0
        }));
      } catch (e) {
        console.error('tweakMapBearing error:', JSON.stringify(e));
      }
    }
    this.honkToastText = `📐 地图视角已微调至 ${this.currentMapBearing}°`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 1200);
  }

  /**
   * ✈️ 微调飞机 Marker 点标记角度 (±1° 或 ±90°)
   */
  private tweakMarkerRotation(deltaDeg: number): void {
    this.triggerHapticFeedback();
    this.planeMarkerRotation = Math.round((this.planeMarkerRotation + deltaDeg + 360) % 360);
    if (this.currentPlaneMarker) {
      try {
        this.currentPlaneMarker.setRotation(this.planeMarkerRotation);
      } catch (e) {
        console.error('setRotation error:', JSON.stringify(e));
      }
    }
    this.honkToastText = `✈️ 飞机 Marker 角度已调整至 ${this.planeMarkerRotation}°`;
    this.isHonkToastVisible = true;
    setTimeout(() => {
      this.isHonkToastVisible = false;
    }, 1200);
  }

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 0a. 立即强制将地图镜头平移与旋转至跑道垂直朝上对齐视角！
      this.applyRunwayCameraOrientation(controller);

      // 0b. 监听地图点击事件，实时输出并弹窗提示经纬度坐标点
      controller.on('mapClick', (data: Object) => {
        const latLng = data as mapCommon.LatLng;
        if (latLng && latLng.latitude !== undefined && latLng.longitude !== undefined) {
          const latStr = latLng.latitude.toFixed(6);
          const lonStr = latLng.longitude.toFixed(6);
          console.info(`[MapClick] Lat: ${latStr}, Lon: ${lonStr}`);
          this.honkToastText = `📍 选点坐标: ${latStr}, ${lonStr}`;
          this.isHonkToastVisible = true;
          setTimeout(() => {
            this.isHonkToastVisible = false;
          }, 4500);
        }
      });

      // 0c. 监听地图缩放与镜头变换，获取最新 cameraPosition.zoom，使飞机尺寸与地图 100% 等比缩放！
      try {
        controller.on('cameraChange', (_data: Object) => {
          const cam = controller.getCameraPosition();
          if (cam && cam.zoom !== undefined) {
            this.currentZoomLevel = parseFloat(cam.zoom.toFixed(1));
            const baseZoom = 17.2;
            const factor = Math.pow(2, cam.zoom - baseZoom);
            this.currentZoomScale = Math.min(Math.max(factor, 0.35), 8.0);
          }
          if (cam && cam.bearing !== undefined) {
            this.currentMapBearing = Math.round(cam.bearing);
          }
        });
      } catch (e) { }

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

      // 3. 绘制无缝连贯三阶段战术航线 (滑行段 -> 高空大圆巡航段 -> 北京降落进近段)
      await this.drawThreePhaseFlightRoute(controller);

      // 4. 若在进入页面前已激活 Marker 状态或开启地图背景，绘制机头垂直对准12点方向的原生 Marker
      if (this.isPlaneMarkerActive || this.isMapBackgroundVisible) {
        this.currentPlaneMarker = await controller.addMarker({
          position: getCtuRunwayStart(),
          icon: $r('app.media.b737_800_top_3_medium'),
          anchorU: 0.5,
          anchorV: 0.5,
          flat: false,
          rotation: this.planeMarkerRotation,
          clickable: false
        });
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
    this.checkAndRestoreActiveSession();
    this.startAnimationSequence();
  }

  onPageShow() {
    this.checkAndRestoreActiveSession();
    this.startAnimationSequence();
  }

  private async checkAndRestoreActiveSession(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, Object>;
      if (params && params.startFlight) {
        this.isCabinExposed = false;
        this.isFullFocusMode = false;
        this.isMapBackgroundVisible = true;
        this.planeScale = 0.45;
        this.planeY = 0;
        this.planeX = 0;
        this.isVehiclesDocked = true;
        this.isHudVisible = true;
        return;
      }

      const session = await FlightSessionStore.getSession();
      if (session && session.isFlightActive && session.startTimeMs > 0) {
        const elapsedMs = Date.now() - session.startTimeMs;
        const totalMs = (session.durationMin || 25) * 60 * 1000;
        if (elapsedMs < totalMs) {
          // 自动在当前 Index 页面恢复沉浸飞行视界（飞机缩小 3 倍）！
          this.isCabinExposed = false;
          this.isFullFocusMode = false;
          this.isMapBackgroundVisible = true;
          this.planeScale = 0.45;
          this.planeY = 0;
          this.planeX = 0;
          this.isVehiclesDocked = true;
          this.isHudVisible = true;
          return;
        } else {
          // 飞行已在后台自然完成
          FlightSessionStore.clearSession();
        }
      }
    } catch (e) {
      // ignore
    }
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

    // 2. 0.35 秒后隐藏机舱透视，飞机平滑 3D 缩小至 1/3 (0.33)，背后的华为 Petal Maps 地图无缝淡入浮现！
    setTimeout(() => {
      this.isCabinExposed = false;
      this.isFullFocusMode = false;
      this.isMapBackgroundVisible = true; // 背后华为花瓣地图无缝出现！

      if (this.huaweiMapController) {
        try {
          this.huaweiMapController.animateCamera(map.newCameraPosition({
            target: getCtuRunwayStart(),
            zoom: 17.2,
            bearing: CTU_RUNWAY_BEARING,
            tilt: 0
          }), 1200);
        } catch (e) { }
      }

      // 飞机在当前页面平滑 3D 缩小至 0.45 比例（与适中 Marker 100% 尺寸对齐）
      this.getUIContext()?.animateTo({ duration: 1600, curve: Curve.FastOutSlowIn }, () => {
        this.planeScale = 0.45;
        this.planeY = 0;
        this.planeX = 0;
      });

      // 恢复周围地勤设备与 HUD 界面
      this.getUIContext()?.animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.isVehiclesDocked = true;
        this.isHudVisible = true;
      });

      // 3. 1600ms 物理缩小动效落定瞬间：无缝交接给贴地随地图同比例缩放的原生 Marker！
      setTimeout(async () => {
        if (this.huaweiMapController) {
          try {
            this.currentPlaneMarker = await this.huaweiMapController.addMarker({
              position: getCtuRunwayStart(),
              icon: $r('app.media.b737_800_top_3_medium'),
              anchorU: 0.5,
              anchorV: 0.5,
              flat: false,
              rotation: this.planeMarkerRotation,
              clickable: false
            });
          } catch (e) { }
        }
        this.getUIContext()?.animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
          this.isPlaneMarkerActive = true;
        });
      }, 1600);
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
    if (this.isMapBackgroundVisible || this.isFullFocusMode) return;
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
    if (this.isMapBackgroundVisible || this.isFullFocusMode) return;
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
    this.planeX = 0;
    this.isPlaneMarkerActive = false;
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
      .hitTestBehavior((this.isFullFocusMode || this.isMapBackgroundVisible) ? HitTestMode.None : HitTestMode.Default)
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

      // 4. 飞机本体地面阴影
      Image($r('app.media.b737_800_top_3_shadow'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .opacity((this.isPlaneMarkerActive || (this.isMapBackgroundVisible && !this.isCabinExposed)) ? 0 : 1.0)
        .scale({ x: this.planeScale, y: this.planeScale })
        .translate({ x: this.planeX + 8, y: this.planeY + 20 })
        .hitTestBehavior(HitTestMode.None)

      // === 实体层 ===

      // 1. 地面勤务车辆（加油车）
      Image($r('app.media.jiayouche'))
        .width(110)
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity((this.isFullFocusMode || this.isMapBackgroundVisible) ? 0 : 1)
        .hitTestBehavior((this.isFullFocusMode || this.isMapBackgroundVisible) ? HitTestMode.None : HitTestMode.Default)
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
        .hitTestBehavior((this.isFullFocusMode || this.isMapBackgroundVisible) ? HitTestMode.None : HitTestMode.Default)
        .translate({
          x: this.isVehiclesDocked ? -125 : -340,
          y: this.isVehiclesDocked ? -90 : 120
        })
        .rotate({ angle: this.isVehiclesDocked ? 0 : 45 })
        .animation({ duration: 800, curve: Curve.EaseOut })
        .onClick(() => {
          this.onTractorClick();
        })

      // 3. 飞机 3D 标志图层 (随地图 Zoom 级别 100% 物理同步缩放，在单纯地图模式时隐藏，选座时保持可见)
      Image($r('app.media.b737_800_top_3'))
        .width(315)
        .height(450.1)
        .objectFit(ImageFit.Contain)
        .opacity((this.isPlaneMarkerActive || (this.isMapBackgroundVisible && !this.isCabinExposed)) ? 0 : 1.0)
        .scale({
          x: this.planeScale * (this.isMapBackgroundVisible ? this.currentZoomScale : 1.0),
          y: this.planeScale * (this.isMapBackgroundVisible ? this.currentZoomScale : 1.0)
        })
        .translate({ x: this.planeX, y: this.planeY })
        .hitTestBehavior((this.isMapBackgroundVisible && !this.isCabinExposed) ? HitTestMode.None : HitTestMode.Transparent)

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

      // 7. 地图模式下的右上角 Cyber HUD 双维度控制组：缩放 + 地图角度微调 + 飞机 Marker 角度微调
      if (this.isMapBackgroundVisible && !this.isCabinExposed) {
        Column({ space: 6 }) {
          // 第一排：地图视角控制 (缩放倍率 + 地图角度微调 + 90°旋转)
          Row({ space: 6 }) {
            // 缩放
            Row({ space: 4 }) {
              Text('🔍').fontSize(11)
              Text(`${this.currentZoomLevel.toFixed(1)}x`).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#38BDF8')
            }
            .padding({ left: 8, right: 9, top: 7, bottom: 7 })
            .backgroundColor('rgba(10, 15, 26, 0.85)')
            .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 18 })

            // 地图视角角度与微调
            Row({ space: 3 }) {
              Text('🗺️').fontSize(11)
              Text(`${Math.round(this.currentMapBearing)}°`).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#38BDF8')
              Text('-1°').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 }).backgroundColor('rgba(255, 255, 255, 0.18)').borderRadius(6)
                .onClick(() => { this.tweakMapBearing(-1); })
              Text('+1°').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 }).backgroundColor('rgba(255, 255, 255, 0.18)').borderRadius(6)
                .onClick(() => { this.tweakMapBearing(1); })
            }
            .padding({ left: 7, right: 7, top: 7, bottom: 7 })
            .backgroundColor('rgba(10, 15, 26, 0.85)')
            .border({ width: 1, color: 'rgba(56, 189, 248, 0.35)', radius: 18 })

            // 地图 90° 旋转
            Row({ space: 3 }) {
              Text('🧭').fontSize(11)
              Text('旋转').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
            }
            .padding({ left: 8, right: 10, top: 7, bottom: 7 })
            .backgroundColor('rgba(10, 15, 26, 0.85)')
            .border({ width: 1, color: 'rgba(255, 255, 255, 0.25)', radius: 18 })
            .onClick(() => { this.rotateMapNextAngle(); })
          }

          // 第二排：飞机 Marker 点标记角度独立微调与控制组
          Row({ space: 6 }) {
            Row({ space: 4 }) {
              Text('✈️').fontSize(11)
              Text(`飞机: ${this.planeMarkerRotation}°`).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#4ADE80')

              Text('-1°').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
                .padding({ left: 6, right: 6, top: 3, bottom: 3 }).backgroundColor('rgba(255, 255, 255, 0.18)').borderRadius(8).margin({ left: 4 })
                .onClick(() => { this.tweakMarkerRotation(-1); })

              Text('+1°').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#F8FAFC')
                .padding({ left: 6, right: 6, top: 3, bottom: 3 }).backgroundColor('rgba(255, 255, 255, 0.18)').borderRadius(8)
                .onClick(() => { this.tweakMarkerRotation(1); })

              Text('-90°').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#38BDF8')
                .padding({ left: 5, right: 5, top: 3, bottom: 3 }).backgroundColor('rgba(56, 189, 248, 0.2)').borderRadius(8)
                .onClick(() => { this.tweakMarkerRotation(-90); })

              Text('+90°').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#38BDF8')
                .padding({ left: 5, right: 5, top: 3, bottom: 3 }).backgroundColor('rgba(56, 189, 248, 0.2)').borderRadius(8)
                .onClick(() => { this.tweakMarkerRotation(90); })
            }
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor('rgba(10, 15, 26, 0.88)')
            .border({ width: 1, color: 'rgba(74, 222, 128, 0.4)', radius: 18 })
            .shadow({ radius: 12, color: 'rgba(74, 222, 128, 0.25)', offsetY: 2 })
          }
          .alignSelf(ItemAlign.End)
        }
        .position({ x: '100%', y: 44 })
        .markAnchor({ x: '100%', y: 0 })
        .margin({ right: 14 })
        .zIndex(200)
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      // 🛡️ 只有在非地图模式下才响应全屏点击收起逻辑，防止地图操作被穿透触发模式切换！
      if (this.isFullFocusMode && !this.isMapBackgroundVisible && !this.isCabinExposed) {
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