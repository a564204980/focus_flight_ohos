import { map, mapCommon } from '@kit.MapKit';
import { getCustomRunwaysForAirport, getCustomTaxiwaysForAirport } from '../models/AirportRunwayConfig';
import { ctuAirportConfig } from '../models/airports/ctu';
import { pekAirportConfig } from '../models/airports/pek';
import {
  generateThresholdZebraStripes,
  generateTouchdownZoneMarkings,
  interpolateRunwayPoint,
  generatePAPILightPoints,
  generateGreatCirclePoints,
  generateQuadraticBezierPoints,
  LatLngPoint,
  interpolateLatLng
} from './GeodesicUtils';

function getCtuRunwayStart(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.start || { latitude: 30.592085, longitude: 103.958889 };
}

function getCtuRunwayEnd(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.end || { latitude: 30.562957, longitude: 103.945340 };
}

function getPekRunwayStart(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.start || { latitude: 40.079857, longitude: 116.603114 };
}

function getPekRunwayEnd(): LatLngPoint {
  return pekAirportConfig.takeoffRunway?.end || { latitude: 40.091200, longitude: 116.615000 };
}

/**
 * MapRenderHelper.ets
 * 鸿蒙 MapKit 机场跑道多边形、滑行道网络及三阶段贝塞尔战术发光航线绘制辅助工具
 */
export class MapRenderHelper {
  /**
   * ✈️ 绘制机场滑行道网络 (Cyan/Blue 发光折线)
   */
  public static async drawTaxiways(
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
   * ✈️ 单条跑道完整 ICAO 战术灯光与标线渲染函数
   */
  public static async drawSingleRunway(
    controller: map.MapComponentController,
    runwayPolygonPoints: Array<mapCommon.LatLng>
  ): Promise<void> {
    if (!runwayPolygonPoints || runwayPolygonPoints.length < 4) return;

    // 1. 跑道物理路面 (深暗黑沉浸式沥青基底 + 柔和银白边界防碰撞线，100% 不透明完全遮挡防透光)
    await controller.addPolygon({
      points: runwayPolygonPoints,
      fillColor: 0xFF0B132B,
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

    // 8. 跑道入口 PAPI 进近坡度指示灯
    const papiPoints = generatePAPILightPoints(runwayPolygonPoints);
    for (let point of papiPoints) {
      await controller.addCircle({
        center: point,
        radius: 4,
        fillColor: 0xFFFF0055,
        strokeColor: 0xFFFFFFFF,
        strokeWidth: 1
      });
    }
  }

  /**
   * ✈️ 绘制三阶段发光战术航线
   */
  public static async drawThreePhaseFlightRoute(controller: map.MapComponentController): Promise<void> {
    const ctuStart = getCtuRunwayStart();
    const ctuEnd = getCtuRunwayEnd();
    const pekStart = getPekRunwayStart();
    const pekEnd = getPekRunwayEnd();

    const turnStartPoint = interpolateLatLng(ctuStart, ctuEnd, 0.65);
    const departureControlPoint = interpolateLatLng(ctuStart, ctuEnd, 3.2);

    const ctuVertex: mapCommon.LatLng = { latitude: ctuStart.latitude, longitude: ctuStart.longitude };
    const pekVertex: mapCommon.LatLng = { latitude: pekStart.latitude, longitude: pekStart.longitude };

    const turnEndPoint = interpolateLatLng(ctuVertex, pekVertex, 0.02);

    const landingStartPoint = interpolateLatLng(ctuVertex, pekVertex, 0.98);
    const arrivalControlPoint = interpolateLatLng(pekVertex, pekEnd, -0.7);
    const landingEndPoint = interpolateLatLng(pekVertex, pekEnd, 0.65);

    const taxiSegment: mapCommon.LatLng[] = generateGreatCirclePoints(ctuStart, turnStartPoint, 20);
    const departureArc: mapCommon.LatLng[] = generateQuadraticBezierPoints(turnStartPoint, departureControlPoint, turnEndPoint, 100);
    const cruiseSegment: mapCommon.LatLng[] = generateGreatCirclePoints(turnEndPoint, landingStartPoint, 150);
    const arrivalArc: mapCommon.LatLng[] = generateQuadraticBezierPoints(landingStartPoint, arrivalControlPoint, landingEndPoint, 100);
    const landingSegment: mapCommon.LatLng[] = generateGreatCirclePoints(landingEndPoint, pekEnd, 15);

    const phase1Points: mapCommon.LatLng[] = taxiSegment.concat(departureArc.slice(1));
    const phase2Points: mapCommon.LatLng[] = cruiseSegment;
    const phase3Points: mapCommon.LatLng[] = arrivalArc.concat(landingSegment.slice(1));

    // 阶段 1：离场爬升 (Cyber Cyan)
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

    // 阶段 2：高空巡航 (Amber Gold)
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

    // 阶段 3：进近接地 (Emerald Green)
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
   * ✈️ 一键完整加载跑道、滑行道与航线渲染
   */
  public static async setupRunwaysAndRoutes(controller: map.MapComponentController): Promise<void> {
    const customRunwayPolygons = getCustomRunwaysForAirport('CTU');
    if (customRunwayPolygons) {
      for (const corners of customRunwayPolygons) {
        await MapRenderHelper.drawSingleRunway(controller, corners);
      }
    }

    await MapRenderHelper.drawThreePhaseFlightRoute(controller);
  }

  /**
   * ✈️ 获取完整的全程三阶段飞行航线点集（离场滑跑 -> 离场爬升弧 -> 高空巡航 -> 进近降落）
   */
  public static getFullFlightPathPoints(): mapCommon.LatLng[] {
    const ctuStart = getCtuRunwayStart();
    const ctuEnd = getCtuRunwayEnd();
    const pekStart = getPekRunwayStart();
    const pekEnd = getPekRunwayEnd();

    const turnStartPoint = interpolateLatLng(ctuStart, ctuEnd, 0.65);
    const departureControlPoint = interpolateLatLng(ctuStart, ctuEnd, 3.2);

    const ctuVertex: mapCommon.LatLng = { latitude: ctuStart.latitude, longitude: ctuStart.longitude };
    const pekVertex: mapCommon.LatLng = { latitude: pekStart.latitude, longitude: pekStart.longitude };

    const turnEndPoint = interpolateLatLng(ctuVertex, pekVertex, 0.02);

    const landingStartPoint = interpolateLatLng(ctuVertex, pekVertex, 0.98);
    const arrivalControlPoint = interpolateLatLng(pekVertex, pekEnd, -0.7);
    const landingEndPoint = interpolateLatLng(pekVertex, pekEnd, 0.65);

    const taxiSegment: mapCommon.LatLng[] = generateGreatCirclePoints(ctuStart, turnStartPoint, 20);
    const departureArc: mapCommon.LatLng[] = generateQuadraticBezierPoints(turnStartPoint, departureControlPoint, turnEndPoint, 100);
    const cruiseSegment: mapCommon.LatLng[] = generateGreatCirclePoints(turnEndPoint, landingStartPoint, 150);
    const arrivalArc: mapCommon.LatLng[] = generateQuadraticBezierPoints(landingStartPoint, arrivalControlPoint, landingEndPoint, 100);
    const landingSegment: mapCommon.LatLng[] = generateGreatCirclePoints(landingEndPoint, pekEnd, 15);

    return taxiSegment
      .concat(departureArc.slice(1))
      .concat(cruiseSegment.slice(1))
      .concat(arrivalArc.slice(1))
      .concat(landingSegment.slice(1));
  }

  /**
   * 🧭 计算两个经纬度坐标点之间的航向角 Bearing (0 ~ 360°)
   */
  public static calculateBearing(start: mapCommon.LatLng, end: mapCommon.LatLng): number {
    const rad = Math.PI / 180;
    const lat1 = start.latitude * rad;
    const lat2 = end.latitude * rad;
    const dLon = (end.longitude - start.longitude) * rad;

    const y = Math.sin(dLon) * Math.cos(lat2);
    const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

    const brng = Math.atan2(y, x) * 180 / Math.PI;
    return (brng + 360) % 360;
  }
}
