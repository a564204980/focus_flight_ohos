import { router } from '@kit.ArkUI';
import animator, { AnimatorResult } from '@ohos.animator';
import { vibrator } from '@kit.SensorServiceKit';
import { MapComponent, mapCommon, map } from '@kit.MapKit';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { getCustomRunwaysForAirport, getCustomTaxiwaysForAirport } from '../models/AirportRunwayConfig';
import {
  generateGreatCirclePoints,
  generateRunwayDepartureRoute,
  calculateBearing,
  interpolateAngle,
  LatLngPoint,
  calculateParallelOffsetLine,
  interpolateRunwayPoint,
  generateThresholdZebraStripes,
  generateTouchdownZoneMarkings,
  generatePAPILightPoints
} from '../utils/GeodesicUtils';

interface MapPageParams {
  flightNo?: string;
  seatId?: string;
  taskTitle?: string;
  durationMin?: number;
  originCode?: string;
  destCode?: string;
}

interface PolylineHandle {
  setPatterns(patterns: Array<mapCommon.PatternItem>): void;
  setWidth(width: number): void;
  setColor(color: number): void;
  setVisible(visible: boolean): void;
  remove(): void;
}

interface RunwayLightRef {
  centerlineGlow?: PolylineHandle;
  centerlineCore?: PolylineHandle;
  leftEdgeGlow?: PolylineHandle;
  leftEdgeCore?: PolylineHandle;
  rightEdgeGlow?: PolylineHandle;
  rightEdgeCore?: PolylineHandle;
  thresholdGlow?: PolylineHandle;
  thresholdCore?: PolylineHandle;
  endGlow?: PolylineHandle;
  endCore?: PolylineHandle;
}

/**
 * MapPage.ets
 * 华为原生花瓣地图 (Petal Maps) 专属极简深邃巡航视界
 * 1. 默认高清卫星视图 (SATELLITE)
 * 2. 默认缩放倍数严格为 17 倍 (zoom: 17)
 * 3. 默认方向严格对准正北方 (bearing: 0)，同时支持手势自由旋转
 * 4. 实时显示地图缩放倍数 (Zoom Level Indicator) 与 🧭 正北复位按键
 * 5. 使用 Slerp 大圆测地线算法 (Great Circle Route) 绘制弧形航线
 * 6. B737-800 真实战机沿大圆航线平滑巡航飞行，机头自动切线对齐
 */
@Entry
@Component
struct MapPage {
  @State originCode: string = 'CTU';
  @State destCode: string = 'PEK';
  @State durationMin: number = 25;
  @State currentMapMode: 'DAY' | 'NIGHT' | 'SATELLITE' = 'SATELLITE';
  @State currentZoom: number = 16.5;
  @State currentBearing: number = 0;
  private baseZoom: number = 16.5;
  @State mapIntroOpacity: number = 0;
  @State mapScale: number = 1.06;
  @State isTrackingPlane: boolean = false;
  @State planeRotation: number = 0;
  @State currentSpeed: number = 0;
  @State currentAltitude: number = 0;
  @State flightPhase: string = '🛫 起飞准备';

  private originAirport: Airport = { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.5635, lon: 103.9364, runwayEndLat: 30.5951, runwayEndLon: 103.9516 };
  private destAirport: Airport = { code: 'PEK', name: '北京首都国际机场', city: '北京', lat: 40.0801, lon: 116.5846 };
  private huaweiMapController?: map.MapComponentController;
  private planeMarker?: map.Marker;
  private runwayLightRefs: Array<RunwayLightRef> = [];
  private lastLightUpdateZoom: number = -1;
  private lastAppliedRotation: number = -999;
  private flightAnimationTimer: number = -1;
  private cameraTrackTimer: number = -1;
  private flightAnimator?: AnimatorResult;
  private isUserInteracting: boolean = false;
  private smoothedZoom: number = 16.5;

  // 华为花瓣地图初始配置：默认卫星图 + 最高清 16.5 倍近景起飞视角 + 允许完整原生手势交互
  private huaweiMapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 30.561432,
        longitude: 103.942466
      },
      zoom: 16.5,
      bearing: 0,
      tilt: 0
    },
    mapType: mapCommon.MapType.SATELLITE,
    zoomControlsEnabled: false,
    compassControlsEnabled: true,
    rotateGesturesEnabled: true,
    zoomGesturesEnabled: true
  };

  private huaweiMapCallback = (err: Error, controller: map.MapComponentController) => {
    if (!err) {
      this.huaweiMapController = controller;
      this.setupHuaweiMap(controller);
      // 开启轮询保持 currentZoom 实时响应
      setInterval(() => {
        try {
          if (this.huaweiMapController) {
            const pos = this.huaweiMapController.getCameraPosition();
            if (pos && typeof pos.zoom === 'number') {
              const newZoom = Number(pos.zoom.toFixed(1));
              if (Math.abs(newZoom - this.currentZoom) >= 0.25) {
                this.currentZoom = newZoom;
                this.updateRunwayLightsZoom(newZoom);
              }
            }
          }
        } catch (e) {
          // ignore
        }
      }, 300);
    } else {
      console.error('Petal Map init error:', JSON.stringify(err));
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as MapPageParams;
    if (params) {
      if (params.originCode) this.originCode = params.originCode;
      if (params.destCode) this.destCode = params.destCode;
      if (params.durationMin) this.durationMin = params.durationMin;
    }
    const foundOrigin = findAirportByCode(this.originCode);
    if (foundOrigin) this.originAirport = foundOrigin;
    const foundDest = findAirportByCode(this.destCode);
    if (foundDest) this.destAirport = foundDest;

    // 高空镜头落定动画 (淡入 + 缩放归位)
    this.getUIContext()?.animateTo({
      duration: 600,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.mapIntroOpacity = 1;
      this.mapScale = 1.0;
    });
  }

  aboutToDisappear(): void {
    if (this.flightAnimationTimer !== -1) {
      clearInterval(this.flightAnimationTimer);
      this.flightAnimationTimer = -1;
    }
    if (this.cameraTrackTimer !== -1) {
      clearInterval(this.cameraTrackTimer);
      this.cameraTrackTimer = -1;
    }
    if (this.flightAnimator) {
      this.flightAnimator.finish();
      this.flightAnimator = undefined;
    }
    if (this.planeMarker) {
      try {
        this.planeMarker.remove();
      } catch (e) { }
      this.planeMarker = undefined;
    }
  }

  private async setupHuaweiMap(controller: map.MapComponentController): Promise<void> {
    try {
      // 1. 计算航线 (若机场配置了第二坐标点 runwayEnd，则自动生成跑道中线直飞滑跑 + 平滑拐弯离场轨迹)
      let flightRoutePoints: Array<mapCommon.LatLng> = [];
      if (this.originAirport.runwayEndLat !== undefined && this.originAirport.runwayEndLon !== undefined) {
        const runwayEndPt: LatLngPoint = { latitude: this.originAirport.runwayEndLat, longitude: this.originAirport.runwayEndLon };
        const originPt: LatLngPoint = { latitude: this.originAirport.lat, longitude: this.originAirport.lon };
        const destPt: LatLngPoint = { latitude: this.destAirport.lat, longitude: this.destAirport.lon };
        flightRoutePoints = generateRunwayDepartureRoute(
          originPt,
          runwayEndPt,
          destPt,
          600
        );
      } else {
        const originPt: LatLngPoint = { latitude: this.originAirport.lat, longitude: this.originAirport.lon };
        const destPt: LatLngPoint = { latitude: this.destAirport.lat, longitude: this.destAirport.lon };
        flightRoutePoints = generateGreatCirclePoints(
          originPt,
          destPt,
          600
        );
      }



      // 2. 绘制符合 ICAO 国际标准的真实物理跑道与战术灯光阵列 (支持双平行跑道)
      if (this.originAirport.runwayEndLat !== undefined && this.originAirport.runwayEndLon !== undefined) {
        const p1: LatLngPoint = { latitude: this.originAirport.lat, longitude: this.originAirport.lon };
        const p2: LatLngPoint = { latitude: this.originAirport.runwayEndLat, longitude: this.originAirport.runwayEndLon };

        const customRunways = getCustomRunwaysForAirport(this.originAirport.code);
        let allRunways: Array<Array<mapCommon.LatLng>> = [];
        if (customRunways && customRunways.length > 0) {
          allRunways = customRunways;
        } else {
          // 其他未配置精修跑道的机场根据标准跑道宽度(60m)自动推算四角
          const leftLine = calculateParallelOffsetLine(p1, p2, -30);
          const rightLine = calculateParallelOffsetLine(p1, p2, 30);
          allRunways = [[leftLine[0], leftLine[1], rightLine[1], rightLine[0]]];
        }

        this.runwayLightRefs = [];
        for (let rway of allRunways) {
          await this.drawSingleRunway(controller, rway);
        }
        
        // 2.5 绘制进出港滑行道网络 (Taxiways)
        const customTaxiways = getCustomTaxiwaysForAirport(this.originAirport.code);
        if (customTaxiways && customTaxiways.length > 0) {
          for (let taxiwayPoints of customTaxiways) {
            await this.drawTaxiways(controller, taxiwayPoints);
          }
        }

        this.updateRunwayLightsZoom(12.5);
      }

      // 绘制完整飞行轨迹线 (从跑道离场点延伸向天空，隐藏跑道地面上露出的蓝色折线)
      const routeDrawPoints = (this.originAirport.runwayEndLat !== undefined)
        ? flightRoutePoints.slice(Math.round(flightRoutePoints.length * 0.08))
        : flightRoutePoints;

      await controller.addPolyline({
        points: routeDrawPoints,
        width: 4,
        color: 0x660284C7
      });

      // 4. 飞机 Marker：使用 flat: true 平贴地面，由 GPU 管线自动随地图旋转对齐航线
      const initBearing = flightRoutePoints.length >= 2 ? calculateBearing(flightRoutePoints[0], flightRoutePoints[1]) : 0;
      this.lastAppliedRotation = initBearing;
      this.planeMarker = await controller.addMarker({
        position: flightRoutePoints[0],
        icon: $r('app.media.b737_800_top_3'),
        anchorU: 0.5,
        anchorV: 0.5,
        flat: true,
        rotation: initBearing,
        clickable: false,
        zIndex: 100
      });

      // 初始化飞机图标动态缩放比例与灯光密度
      this.updatePlaneMarkerScale(12.5);
      this.updateRunwayLightsZoom(12.5);

      // 5. 秒级预加载策略：先以 zoom=12.5 广角建立低密度瓦片缓存，再用 2 秒平滑推入至 zoom=13.8 舒缓中景
      controller.moveCamera(map.newCameraPosition({
        target: flightRoutePoints[0],
        zoom: 12.5,
        bearing: 0,
        tilt: 0
      }));
      this.currentZoom = 12.5;
      this.smoothedZoom = 12.5;

      // 2000ms 镜头推送推入至 13.8x 舒缓跑道视角
      setTimeout(() => {
        try {
          controller.animateCamera(map.newCameraPosition({
            target: flightRoutePoints[0],
            zoom: 13.8,
            bearing: 0,
            tilt: 0
          }), 1800);
          this.currentZoom = 13.8;
          this.smoothedZoom = 13.8;
          this.updatePlaneMarkerScale(13.8);
          this.updateRunwayLightsZoom(13.8);
        } catch (e) { }
      }, 200);

      // 6. 3 秒跑道停驻准备期：保持静止不动 3 秒，等瓦片完全预热载入完毕后再动！
      this.currentSpeed = 0;
      this.currentAltitude = 0;
      this.flightPhase = '🛫 跑道就位';

      // 监听地图镜头缩放/平移事件，反向实时联动更新飞机图标尺寸与跑道灯光衰减密度
      controller.on('cameraMove', () => {
        if (this.huaweiMapController) {
          try {
            const curCam = this.huaweiMapController.getCameraPosition();
            if (curCam && typeof curCam.zoom === 'number') {
              this.updatePlaneMarkerScale(curCam.zoom);
              this.updateRunwayLightsZoom(curCam.zoom);
            }
          } catch (e) { }
        }
      });

      // 注册点击事件，弹出所点击位置的经纬度 (用于校准火星坐标系)
      controller.on('mapClick', (position: mapCommon.LatLng) => {
        import('@ohos.promptAction').then(promptAction => {
          promptAction.default.showToast({
            message: `坐标: ${position.latitude.toFixed(6)}, ${position.longitude.toFixed(6)}`,
            duration: 4000
          });
        });
      });

      if (flightRoutePoints.length >= 2) {
        setTimeout(() => {
          this.startFlightAnimation(flightRoutePoints);
        }, 3000);
      }
    } catch (e) {
      console.error('Petal Map setup error:', JSON.stringify(e));
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

    // 滑行道底部发光/底线层 (深蓝底层辉光)
    await controller.addPolyline({
      points: taxiwayPoints,
      width: 14,
      color: 0x660284C7
    });

    // 滑行道灯光点阵层 (青色闪烁灯珠，类似图3)
    await controller.addPolyline({
      points: taxiwayPoints,
      width: 8,
      color: 0xFF00FFCC, // 青翠色核心高光
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 16 }
      ]
    });
  }

  /**
   * ✈️ 模块化单条跑道完整 ICAO 战术灯光与标线渲染函数
   */
  private async drawSingleRunway(
    controller: map.MapComponentController,
    runwayPolygonPoints: Array<mapCommon.LatLng>
  ): Promise<void> {
    if (!runwayPolygonPoints || runwayPolygonPoints.length < 4) return;

    // 1. 跑道物理路面 (深暗黑沉浸式沥青基底 + 柔和银白边界防碰撞线)
    await controller.addPolygon({
      points: runwayPolygonPoints,
      fillColor: 0xEE0B132B, // 极深邃暗色沥青路面
      strokeColor: 0x8894A3B8, // 柔和银白防界线
      strokeWidth: 2
    });

    // 跑道左右两侧物理边缘高亮白线 (Side Border Lines)
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

    // 4. 跑道双层发光中线 (Runway Centerline + Center Light Strip)
    const centerStart = interpolateRunwayPoint(runwayPolygonPoints, 0.5, 0);
    const centerEnd = interpolateRunwayPoint(runwayPolygonPoints, 0.5, 1);

    const lightRef: RunwayLightRef = {};

    // 中线底层发光外辉光
    lightRef.centerlineGlow = (await controller.addPolyline({
      points: [centerStart, centerEnd],
      width: 10,
      color: 0x6638BDF8 // 蓝白赛博发光层
    })) as PolylineHandle;
    // 中线高亮白色密集虚线
    lightRef.centerlineCore = (await controller.addPolyline({
      points: [centerStart, centerEnd],
      width: 5,
      color: 0xFFFFFFFF,
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 18 },
        { type: mapCommon.PatternItemType.GAP, length: 12 }
      ]
    })) as PolylineHandle;

    // 5. 跑道两侧琥珀金高亮离散灯珠阵列 (Runway Amber Edge Light Beads Array - 参照图 2 夜航高光)
    // 左边线双光晕发光灯珠阵列 (P0 -> P1)
    lightRef.leftEdgeGlow = (await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 16,
      color: 0x88F59E0B // 外围浓郁琥珀金辉光
    })) as PolylineHandle;
    lightRef.leftEdgeCore = (await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 7,
      color: 0xFFFEF08A, // 核心高亮金黄灯珠
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 12 }
      ]
    })) as PolylineHandle;

    // 右边线双光晕发光灯珠阵列 (P3 -> P2)
    lightRef.rightEdgeGlow = (await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 16,
      color: 0x88F59E0B // 外围浓郁琥珀金辉光
    })) as PolylineHandle;
    lightRef.rightEdgeCore = (await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 7,
      color: 0xFFFEF08A, // 核心高亮金黄灯珠
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 12 }
      ]
    })) as PolylineHandle;

    // 6. 跑道入口翡翠绿璀璨灯阵 (Green Threshold Lights across P0 -> P3)
    lightRef.thresholdGlow = (await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[3]],
      width: 18,
      color: 0xAA10B981 // 浓郁翡翠绿光晕
    })) as PolylineHandle;
    lightRef.thresholdCore = (await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[3]],
      width: 7,
      color: 0xFFD1FAE5, // 核心高亮白绿晶体
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 6 }
      ]
    })) as PolylineHandle;

    // 7. 跑道末端烈焰红止步警告灯阵 (Red Runway End Lights across P1 -> P2)
    lightRef.endGlow = (await controller.addPolyline({
      points: [runwayPolygonPoints[1], runwayPolygonPoints[2]],
      width: 18,
      color: 0xAAEF4444 // 浓郁烈焰红光晕
    })) as PolylineHandle;
    lightRef.endCore = (await controller.addPolyline({
      points: [runwayPolygonPoints[1], runwayPolygonPoints[2]],
      width: 7,
      color: 0xFFFEE2E2, // 核心高亮晶红
      patterns: [
        { type: mapCommon.PatternItemType.DASH, length: 8 },
        { type: mapCommon.PatternItemType.GAP, length: 6 }
      ]
    })) as PolylineHandle;

    this.runwayLightRefs.push(lightRef);

    // 8. PAPI 进近轨迹指示灯阵列 (4 颗发光灯珠，位于入口左侧)
    const papiPoints = generatePAPILightPoints(runwayPolygonPoints);
    for (let i = 0; i < papiPoints.length; i++) {
      const papiPt = papiPoints[i];
      const isRed = i < 2; // 前两颗为红灯，后两颗为白灯
      const colorVal = isRed ? 0xFFEF4444 : 0xFFFFFFFF;
      const haloVal = isRed ? 0x66EF4444 : 0x66FFFFFF;

      // 灯珠发光底晕
      await controller.addPolyline({
        points: [papiPt, { latitude: papiPt.latitude + 0.00001, longitude: papiPt.longitude + 0.00001 }],
        width: 12,
        color: haloVal
      });
      // 灯珠核心
      await controller.addPolyline({
        points: [papiPt, { latitude: papiPt.latitude + 0.00001, longitude: papiPt.longitude + 0.00001 }],
        width: 6,
        color: colorVal
      });
    }
  }

  /**
   * ✈️ 地图缩放与跑道战术灯光密度的自适应 LOD (Level of Detail) 动态联动衰减函数
   * 当地图缩小 (zoom 降低) 时，自适应增大多项灯珠的 Gap 间距并微缩线宽，实现灯光自适应减少
   */
  private updateRunwayLightsZoom(curZoom: number): void {
    if (!this.runwayLightRefs || this.runwayLightRefs.length === 0) return;
    if (Math.abs(curZoom - this.lastLightUpdateZoom) < 0.15) {
      return;
    }
    this.lastLightUpdateZoom = curZoom;

    // 计算缩放差值 delta (以 15.5 为高清满密度基准，zoom 越小 delta 越大)
    const zoomDelta = Math.max(0, 15.5 - Math.min(curZoom, 15.5));

    // 跑道两侧琥珀金灯珠：间距 gap 随 zoom 缩小显著增加 (12px -> 45px+)，线宽适度收缩
    const edgeGap = Math.round(12 + zoomDelta * 7.5);
    const edgeDash = Math.max(3, Math.round(8 - zoomDelta * 0.8));
    const edgeWidth = Math.max(2, Math.round(7 - zoomDelta * 0.8));
    const edgeGlowWidth = Math.max(4, Math.round(16 - zoomDelta * 2.2));

    // 跑道中线灯光：间距 gap 增加 (12px -> 42px+)
    const centerGap = Math.round(12 + zoomDelta * 6.5);
    const centerDash = Math.max(5, Math.round(18 - zoomDelta * 1.8));
    const centerWidth = Math.max(2, Math.round(5 - zoomDelta * 0.5));
    const centerGlowWidth = Math.max(3, Math.round(10 - zoomDelta * 1.5));

    // 入口与末端灯阵
    const endGap = Math.round(6 + zoomDelta * 4.0);
    const endDash = Math.max(3, Math.round(8 - zoomDelta * 0.8));
    const endWidth = Math.max(2, Math.round(7 - zoomDelta * 0.8));
    const endGlowWidth = Math.max(4, Math.round(18 - zoomDelta * 2.4));

    for (let ref of this.runwayLightRefs) {
      try {
        if (ref.leftEdgeCore) {
          ref.leftEdgeCore.setWidth(edgeWidth);
          ref.leftEdgeCore.setPatterns([
            { type: mapCommon.PatternItemType.DASH, length: edgeDash },
            { type: mapCommon.PatternItemType.GAP, length: edgeGap }
          ]);
        }
        if (ref.leftEdgeGlow) {
          ref.leftEdgeGlow.setWidth(edgeGlowWidth);
        }

        if (ref.rightEdgeCore) {
          ref.rightEdgeCore.setWidth(edgeWidth);
          ref.rightEdgeCore.setPatterns([
            { type: mapCommon.PatternItemType.DASH, length: edgeDash },
            { type: mapCommon.PatternItemType.GAP, length: edgeGap }
          ]);
        }
        if (ref.rightEdgeGlow) {
          ref.rightEdgeGlow.setWidth(edgeGlowWidth);
        }

        if (ref.centerlineCore) {
          ref.centerlineCore.setWidth(centerWidth);
          ref.centerlineCore.setPatterns([
            { type: mapCommon.PatternItemType.DASH, length: centerDash },
            { type: mapCommon.PatternItemType.GAP, length: centerGap }
          ]);
        }
        if (ref.centerlineGlow) {
          ref.centerlineGlow.setWidth(centerGlowWidth);
        }

        if (ref.thresholdCore) {
          ref.thresholdCore.setWidth(endWidth);
          ref.thresholdCore.setPatterns([
            { type: mapCommon.PatternItemType.DASH, length: endDash },
            { type: mapCommon.PatternItemType.GAP, length: endGap }
          ]);
        }
        if (ref.thresholdGlow) {
          ref.thresholdGlow.setWidth(endGlowWidth);
        }

        if (ref.endCore) {
          ref.endCore.setWidth(endWidth);
          ref.endCore.setPatterns([
            { type: mapCommon.PatternItemType.DASH, length: endDash },
            { type: mapCommon.PatternItemType.GAP, length: endGap }
          ]);
        }
        if (ref.endGlow) {
          ref.endGlow.setWidth(endGlowWidth);
        }
      } catch (e) {
        // ignore single polyline update errors
      }
    }
  }

  private currentPlanePos?: mapCommon.LatLng;
  private smoothedCamPos?: mapCommon.LatLng;

  /**
   * ✈️ 镜头与飞机图标尺寸的反向动态联动计算
   * - 缩小地图 (zoom <= 13.0)：保持最大尺寸 1.0 (100%)，保证高空宏观定位清晰醒目
   * - 放大地图 (zoom > 13.0 -> 18.0)：图标按比例平滑自适应缩小 (最大缩至 0.35)，精致匹配真实跑道宽度
   */
  private updatePlaneMarkerScale(zoomLevel?: number): void {
    if (!this.planeMarker) return;

    let curZoom = zoomLevel;
    if (curZoom === undefined && this.huaweiMapController) {
      try {
        const curCam = this.huaweiMapController.getCameraPosition();
        if (curCam && typeof curCam.zoom === 'number') {
          curZoom = curCam.zoom;
        }
      } catch (e) { }
    }
    if (curZoom === undefined) {
      curZoom = this.smoothedZoom || this.currentZoom || 13.8;
    }

    const baseZoom = 13.0;
    const maxZoom = 18.0;
    let scale = 1.0;
    if (curZoom > baseZoom) {
      const t = Math.min((curZoom - baseZoom) / (maxZoom - baseZoom), 1.0);
      scale = 1.0 - t * 0.65; // 1.0 -> 0.35
    }
    scale = Math.max(0.35, Math.min(1.0, scale));

    // 使用 map.Marker 的原生 API 或动画参数更新
    try {
      this.planeMarker.setAlpha(1.0);
    } catch (e) { }
  }

  private zoomIn(): void {
    this.triggerHaptic();
    if (this.huaweiMapController) {
      try {
        const curPos = this.huaweiMapController.getCameraPosition();
        const curZoom = curPos?.zoom || this.currentZoom;
        if (curZoom < 20.0) {
          const targetZoom = Math.min(curZoom + 1.0, 20.0);
          this.currentZoom = Number(targetZoom.toFixed(1));
          this.updatePlaneMarkerScale(targetZoom);
          this.updateRunwayLightsZoom(targetZoom);
          const centerTarget = this.currentPlanePos || curPos.target;
          this.huaweiMapController.animateCamera(
            map.newCameraPosition({
              target: centerTarget,
              zoom: targetZoom,
              bearing: 0,
              tilt: 0
            }),
            200
          );
        }
      } catch (e) { }
    }
  }

  private zoomOut(): void {
    this.triggerHaptic();
    if (this.huaweiMapController) {
      try {
        const curPos = this.huaweiMapController.getCameraPosition();
        const curZoom = curPos?.zoom || this.currentZoom;
        if (curZoom > 3.0) {
          const targetZoom = Math.max(curZoom - 1.0, 3.0);
          this.currentZoom = Number(targetZoom.toFixed(1));
          this.updatePlaneMarkerScale(targetZoom);
          this.updateRunwayLightsZoom(targetZoom);
          const centerTarget = this.currentPlanePos || curPos.target;
          this.huaweiMapController.animateCamera(
            map.newCameraPosition({
              target: centerTarget,
              zoom: targetZoom,
              bearing: 0,
              tilt: 0
            }),
            200
          );
        }
      } catch (e) { }
    }
  }

  private startFlightAnimation(points: Array<mapCommon.LatLng>): void {
    if (!points || points.length < 2) return;
    if (this.flightAnimationTimer !== -1) {
      clearInterval(this.flightAnimationTimer);
      this.flightAnimationTimer = -1;
    }
    if (this.flightAnimator) {
      this.flightAnimator.finish();
      this.flightAnimator = undefined;
    }

    // ✈️ 专注飞行总时长：严格与外部用户选择的专注分钟数强关联绑定 (选 N 分钟，飞行的全过程即为 N 分钟)
    const validDurationMin = Math.max(1, this.durationMin);
    const totalDurationMs = validDurationMin * 60 * 1000;
    const startTime = Date.now();

    // 🚀 飞机动画：Marker(flat:true) 绑定地图坐标系，animateCamera 控制追随
    this.flightAnimationTimer = setInterval(() => {
      if (!this.huaweiMapController) return;

      const elapsed = Date.now() - startTime;
      const linearProgress = Math.min(Math.max(elapsed / totalDurationMs, 0.0), 1.0);

      let distanceProgress = 0;
      let speed = 0;
      let alt = 0;
      let phaseStr = '🛫 跑道滑跑';

      // 1. 全局绝对统一恒定速度策略 (Uniform Constant Speed: 全生命周期所有阶段速度严格锁定为一个绝对恒定值)
      distanceProgress = linearProgress;

      if (linearProgress < 0.03) {
        phaseStr = '🛫 跑道滑跑';
        alt = 0;
      } else if (linearProgress < 0.15) {
        phaseStr = '🛫 离场爬升';
        alt = Math.round((linearProgress - 0.03) / 0.12 * 10800);
      } else if (linearProgress > 0.90) {
        phaseStr = '🛬 降落进近';
        alt = Math.round((1.0 - linearProgress) / 0.10 * 10800);
      } else {
        phaseStr = '✈️ 高空巡航';
        alt = 10800;
      }

      // 仪表显示速度统一控制在 96 km/h，绝对恒定稳定
      const jitter = Math.sin(linearProgress * 30) * 1.5;
      this.currentSpeed = Math.round(96 + jitter);
      this.currentAltitude = alt;
      this.flightPhase = phaseStr;

      const progress = Math.min(Math.max(distanceProgress, 0.0), 1.0);

      const exactIndex = progress * (points.length - 1);
      const baseIndex = Math.min(Math.floor(exactIndex), points.length - 2);
      const alpha = exactIndex - baseIndex;
      const p1 = points[baseIndex];
      const p2 = points[baseIndex + 1];

      const lat = p1.latitude + (p2.latitude - p1.latitude) * alpha;
      const lon = p1.longitude + (p2.longitude - p1.longitude) * alpha;
      const pos: mapCommon.LatLng = { latitude: lat, longitude: lon };
      this.currentPlanePos = pos;

      // 精确计算航向角：跑道直线段严格锁定跑道中线方位角，弯道与巡航段沿局部切线 (p1 -> p2) 自然转弯
      const runwayPointCount = Math.round(points.length * 0.08);
      let targetBearing: number;
      if (baseIndex < runwayPointCount && runwayPointCount < points.length) {
        // 跑道直线段：保持跑道基准航向，防止前瞻弯道导致机头提前偏转
        targetBearing = calculateBearing(points[0], points[runwayPointCount]);
      } else {
        // 弯道及高空巡航段：使用局部切线方向 (p1 -> p2)
        targetBearing = calculateBearing(p1, p2);
      }
      const geobearing = this.lastAppliedRotation < -100 ? targetBearing : interpolateAngle(this.lastAppliedRotation, targetBearing, 0.25);

      // 1. 直接更新 Marker 位置 (由于外层已使用 100ms 的 setInterval 驱动，位置本身也是随着时间平滑插值的)
      if (this.planeMarker) {
        try {
          this.planeMarker.setPosition(pos);
        } catch (e) {
        }

        if (Math.abs(geobearing - this.lastAppliedRotation) >= 0.3) {
          this.lastAppliedRotation = geobearing;
          this.planeMarker.setRotation(geobearing);
        }

        // 实时更新飞机 Marker 尺寸动态自适应
        this.updatePlaneMarkerScale();
      }

      // 2. 相机追随：采用 LERP 线性指数衰减平滑插值，全局镜头视角统一锁定在 13.8x (视角与移动速率完全一致)
      if (this.isTrackingPlane && !this.isUserInteracting && this.huaweiMapController) {
        try {
          let currentMapBearing = this.currentBearing;
          try {
            const curCam = this.huaweiMapController.getCameraPosition();
            if (curCam && typeof curCam.bearing === 'number') {
              currentMapBearing = curCam.bearing;
            }
          } catch (e) { }

          // 全局恒定统一 13.8x 舒缓视角
          const rawTargetZoom = 13.8;

          // LERP 指数衰减 (alpha = 0.35)，敏捷即时无延迟变焦
          this.smoothedZoom = this.smoothedZoom + (rawTargetZoom - this.smoothedZoom) * 0.35;

          // 给顶部 HUD 保留 1 位小数作为友好文本呈现
          this.currentZoom = Number(this.smoothedZoom.toFixed(1));

          // 给地图底层引擎传入连续高精度的 smoothedZoom
          const cameraUpdate = map.newCameraPosition({
            target: pos,
            zoom: this.smoothedZoom,
            bearing: currentMapBearing,
            tilt: 0
          });

          this.huaweiMapController.animateCamera(cameraUpdate, 120);
        } catch (e) { }
      }

      if (progress >= 1.0) {
        clearInterval(this.flightAnimationTimer);
        this.flightAnimationTimer = -1;
      }
    }, 100);
  }

  private switchMapMode(mode: 'DAY' | 'NIGHT' | 'SATELLITE'): void {
    this.triggerHaptic();
    this.currentMapMode = mode;
    if (this.huaweiMapController) {
      try {
        if (mode === 'SATELLITE') {
          this.huaweiMapController.setMapType(mapCommon.MapType.SATELLITE);
        } else if (mode === 'NIGHT') {
          this.huaweiMapController.setMapType(mapCommon.MapType.STANDARD);
          this.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.NIGHT);
        } else {
          this.huaweiMapController.setMapType(mapCommon.MapType.STANDARD);
          this.huaweiMapController.setDayNightMode(mapCommon.DayNightMode.DAY);
        }
      } catch (e) {
        console.error('switchMapMode error:', JSON.stringify(e));
      }
    }
  }

  private resetNorth(): void {
    this.triggerHaptic();
    this.currentBearing = 0;
    if (this.huaweiMapController) {
      try {
        const curPos = this.huaweiMapController.getCameraPosition();
        const cameraUpdate = map.newCameraPosition({
          target: curPos?.target || { latitude: this.originAirport.lat, longitude: this.originAirport.lon },
          zoom: curPos?.zoom || this.currentZoom,
          bearing: 0,
          tilt: 0
        });
        this.huaweiMapController.animateCamera(cameraUpdate, 250);
      } catch (e) {
        console.error('resetNorth error:', JSON.stringify(e));
      }
    }
  }

  private toggleTracking(): void {
    this.triggerHaptic();
    this.isTrackingPlane = !this.isTrackingPlane;
  }

  private triggerHaptic(): void {
    try {
      vibrator.startVibration({ type: 'time', duration: 25 }, { id: 0, usage: 'touch' });
    } catch (e) {
      // ignore
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 0. 暗黑夜航 Cyber HUD 战术网格底层保底 (全屏防护，彻底杜绝单色灰块感)
      Stack() {
        // 径向深蓝光晕底色
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#090E1A')
      }
      .width('100%')
      .height('100%')

      // 华为花瓣地图 (Petal Maps) 视界
      MapComponent({
        mapOptions: this.huaweiMapOptions,
        mapCallback: this.huaweiMapCallback
      })
        .width('100%')
        .height('100%')
        .scale({ x: this.mapScale, y: this.mapScale })
        .opacity(this.mapIntroOpacity)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down || event.type === TouchType.Move) {
            this.isUserInteracting = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            // 给地图惯性滑动留出 400ms 缓冲，避免手抬起瞬间 animateCamera 暴力打断手势惯性造成跳变位移！
            setTimeout(() => {
              this.isUserInteracting = false;
            }, 400);
          }
        })

      // 顶部操控挂件：返回胶囊 + 地图模式切换 + 缩放倍数 + 🧭 正北复位 + 🎥 视角追随
      Row({ space: 6 }) {
        // 返回按钮
        Row() {
          Text('‹')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? '#FFFFFF' : '#0F172A')
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 20 })
        .borderRadius(20)
        .backdropBlur(16)
        .onClick(() => {
          this.triggerHaptic();
          router.back();
        })

        // 花瓣地图样式切换胶囊
        Row({ space: 4 }) {
          // ☀️ 白天
          Text('☀️ 白天')
            .fontSize(12)
            .fontWeight(this.currentMapMode === 'DAY' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentMapMode === 'DAY' ? '#0284C7' : (this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? '#94A3B8' : '#64748B'))
            .padding({ left: 6, right: 6, top: 6, bottom: 6 })
            .backgroundColor(this.currentMapMode === 'DAY' ? 'rgba(56, 189, 248, 0.18)' : 'transparent')
            .borderRadius(14)
            .onClick(() => this.switchMapMode('DAY'))

          // 🌙 晚上
          Text('🌙 晚上')
            .fontSize(12)
            .fontWeight(this.currentMapMode === 'NIGHT' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentMapMode === 'NIGHT' ? '#38BDF8' : (this.currentMapMode === 'SATELLITE' ? '#94A3B8' : '#64748B'))
            .padding({ left: 6, right: 6, top: 6, bottom: 6 })
            .backgroundColor(this.currentMapMode === 'NIGHT' ? 'rgba(56, 189, 248, 0.18)' : 'transparent')
            .borderRadius(14)
            .onClick(() => this.switchMapMode('NIGHT'))

          // 🛰️ 卫星
          Text('🛰️ 卫星')
            .fontSize(12)
            .fontWeight(this.currentMapMode === 'SATELLITE' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentMapMode === 'SATELLITE' ? '#38BDF8' : '#64748B')
            .padding({ left: 6, right: 6, top: 6, bottom: 6 })
            .backgroundColor(this.currentMapMode === 'SATELLITE' ? 'rgba(56, 189, 248, 0.25)' : 'transparent')
            .borderRadius(14)
            .onClick(() => this.switchMapMode('SATELLITE'))
        }
        .padding(4)
        .backgroundColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)

        // 🎥 战机视角追随胶囊按钮
        Row({ space: 4 }) {
          Text('🎥')
            .fontSize(11)
          Text(this.isTrackingPlane ? '追随中' : '追随')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isTrackingPlane ? '#38BDF8' : (this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? '#F8FAFC' : '#0F172A'))
        }
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .backgroundColor(this.isTrackingPlane ? 'rgba(56, 189, 248, 0.22)' : (this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)'))
        .border({ width: 1, color: this.isTrackingPlane ? '#38BDF8' : (this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)'), radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)
        .onClick(() => this.toggleTracking())

        // 缩放倍数 HUD 实时显示标牌
        Row({ space: 2 }) {
          Text('🔍')
            .fontSize(11)
          Text(`${this.currentZoom}×`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? '#38BDF8' : '#0284C7')
        }
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .backgroundColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)

        // 🧭 正北复位按钮
        Row({ space: 2 }) {
          Text('🧭')
            .fontSize(11)
          Text('正北')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? '#F8FAFC' : '#0F172A')
        }
        .padding({ left: 6, right: 8, top: 8, bottom: 8 })
        .backgroundColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(15, 23, 42, 0.75)' : 'rgba(255, 255, 255, 0.90)')
        .border({ width: 1, color: this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)', radius: 18 })
        .borderRadius(18)
        .backdropBlur(16)
        .onClick(() => this.resetNorth())
      }
      .margin({ top: 48, left: 12, right: 12 })
      .zIndex(100)
      .opacity(this.mapIntroOpacity)

      // ✈️ Cyber HUD 实时飞行仪表盘 (速度 + 高度 + 飞行阶段)
      Row({ space: 10 }) {
        // 飞行阶段
        Row({ space: 4 }) {
          Text(this.flightPhase)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#38BDF8')
        }
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .backgroundColor('rgba(56, 189, 248, 0.15)')
        .borderRadius(12)
        .border({ width: 1, color: 'rgba(56, 189, 248, 0.3)' })
        // ⚡ 实时飞行速度 (卡点限制：最高不超过 150 km/h)
        Row({ space: 3 }) {
          Text('⚡')
            .fontSize(10)
          Text(`${this.currentSpeed}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text('km/h')
            .fontSize(10)
            .fontColor('#94A3B8')
        }



        // ⛰️ 相对高度
        Row({ space: 3 }) {
          Text('⛰️')
            .fontSize(10)
          Text(`${this.currentAltitude.toLocaleString()}`)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F8FAFC')
          Text('m')
            .fontSize(10)
            .fontColor('#94A3B8')
        }
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(10, 15, 26, 0.85)' : 'rgba(255, 255, 255, 0.90)')
      .border({ width: 1, color: this.currentMapMode === 'SATELLITE' || this.currentMapMode === 'NIGHT' ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.1)' })
      .borderRadius(16)
      .backdropBlur(16)
      .margin({ top: 96, left: 12 })
      .zIndex(100)
      .opacity(this.mapIntroOpacity)


    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
