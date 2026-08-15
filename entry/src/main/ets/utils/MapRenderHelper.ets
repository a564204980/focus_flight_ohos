import { map, mapCommon } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
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
export interface RainbowColorInfo {
  core: number;
  glow: number;
}

export interface RainbowStripe {
  points: mapCommon.LatLng[];
  width: number;
  color: number;
  zIndex: number;
}

export interface RainbowTailColorBand {
  maxRatio: number;
  r: number;
  g: number;
  b: number;
}

export class MapRenderHelper {
  /**
   * ✈️ 绘制机场滑行道网络 (Cyan/Blue 发光实心折线，稳如磐石)
   */
  public static async drawTaxiways(
    controller: map.MapComponentController,
    taxiwayPoints: Array<mapCommon.LatLng>
  ): Promise<void> {
    if (!taxiwayPoints || taxiwayPoints.length < 2) return;

    await controller.addPolyline({
      points: taxiwayPoints,
      width: 10,
      color: 0x440284C7
    });

    await controller.addPolyline({
      points: taxiwayPoints,
      width: 4,
      color: 0xCC00FFCC
    });
  }

  /**
   * ✈️ 单条跑道完整 ICAO 战术灯光与标线渲染函数 (实心发光灯带，绝无频闪滚动)
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

    // 4. 跑道双层发光实心中线
    const centerStart = interpolateRunwayPoint(runwayPolygonPoints, 0.5, 0);
    const centerEnd = interpolateRunwayPoint(runwayPolygonPoints, 0.5, 1);

    await controller.addPolyline({
      points: [centerStart, centerEnd],
      width: 8,
      color: 0x4438BDF8
    });
    await controller.addPolyline({
      points: [centerStart, centerEnd],
      width: 3,
      color: 0xEEFFFFFF
    });

    // 5. 跑道两侧琥珀金高亮实心灯带 (彻底消除虚线走马灯滚动)
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 8,
      color: 0x55F59E0B
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[1]],
      width: 3,
      color: 0xFFFEF08A
    });

    await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 8,
      color: 0x55F59E0B
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[3], runwayPolygonPoints[2]],
      width: 3,
      color: 0xFFFEF08A
    });

    // 6. 跑道入口翡翠绿实心灯带
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[3]],
      width: 10,
      color: 0x6610B981
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[0], runwayPolygonPoints[3]],
      width: 4,
      color: 0xFFD1FAE5
    });

    // 7. 跑道末端烈焰红实心警告灯带
    await controller.addPolyline({
      points: [runwayPolygonPoints[1], runwayPolygonPoints[2]],
      width: 10,
      color: 0x66EF4444
    });
    await controller.addPolyline({
      points: [runwayPolygonPoints[1], runwayPolygonPoints[2]],
      width: 4,
      color: 0xFFFEE2E2
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
   * ✈️ 绘制稳固前方预告未飞航线（前方待解锁实心导引线）
   */
  public static async drawUnflownPreviewRoute(controller: map.MapComponentController): Promise<void> {
    const allPoints = MapRenderHelper.getFullFlightPathPoints();
    if (!allPoints || allPoints.length < 2) return;

    // 1. 半透明天蓝外光晕
    await controller.addPolyline({
      points: allPoints,
      width: 8,
      color: 0x2238BDF8,
      zIndex: 2
    });

    // 2. 稳固待解锁实心导引线
    await controller.addPolyline({
      points: allPoints,
      width: 3,
      color: 0x44CBD5E1,
      zIndex: 3
    });
  }

  public static readonly RAINBOW_COLORS: number[] = [
    0xFFFF3B30, // 0: 热情红 (Coral Red)
    0xFFFF9500, // 1: 活力橙 (Sunset Orange)
    0xFFFFCC00, // 2: 阳光黄 (Golden Sun)
    0xFF34C759, // 3: 清新绿 (Mint Green)
    0xFF00C7BE, // 4: 碧海青 (Cyan)
    0xFF007AFF, // 5: 蔚蓝蓝 (Deep Blue)
    0xFFAF52DE  // 6: 梦幻紫 (Royal Purple)
  ];

  public static readonly RAINBOW_GLOW_COLORS: number[] = [
    0x66FF3B30,
    0x66FF9500,
    0x66FFCC00,
    0x6634C759,
    0x6600C7BE,
    0x66007AFF,
    0x66AF52DE
  ];

  /**
   * 🌈 创建从左至右经典 6 色单向彩虹光谱纹理 PixelMap (🟣紫 -> 🔵蓝 -> 🟢绿 -> 🟡黄 -> 🟠橙 -> 🔴红)
   * 严格对齐图 1 真实单向 6 色彩虹光束，宽度 48px 等宽分布
   */
  public static async createRainbowRibbonPixelMap(): Promise<image.PixelMap | undefined> {
    try {
      const width = 64;  // 沿航线方向重复平铺
      const height = 64; // 垂直于航线横向 6 色等宽分布
      const buffer = new ArrayBuffer(width * height * 4);
      const data = new Uint8Array(buffer);

      // 单向 6 色光谱: 🟣紫 -> 🔵蓝 -> 🟢绿 -> 🟡黄 -> 🟠橙 -> 🔴红
      const spectrum: RainbowTailColorBand[] = [
        { maxRatio: 1 / 6, r: 175, g: 82, b: 222 },  // 🟣 梦幻紫
        { maxRatio: 2 / 6, r: 10, g: 132, b: 255 },  // 🔵 蔚蓝蓝
        { maxRatio: 3 / 6, r: 52, g: 199, b: 89 },   // 🟢 清新绿
        { maxRatio: 4 / 6, r: 255, g: 204, b: 0 },   // 🟡 阳光黄
        { maxRatio: 5 / 6, r: 255, g: 149, b: 0 },   // 🟠 活力橙
        { maxRatio: 1.0, r: 255, g: 59, b: 48 }      // 🔴 热情红
      ];

      let idx = 0;
      for (let y = 0; y < height; y++) {
        const normY = y / height;
        let band = spectrum[spectrum.length - 1];
        for (let k = 0; k < spectrum.length; k++) {
          if (normY <= spectrum[k].maxRatio) {
            band = spectrum[k];
            break;
          }
        }
        for (let x = 0; x < width; x++) {
          data[idx] = band.r;
          data[idx + 1] = band.g;
          data[idx + 2] = band.b;
          data[idx + 3] = 255;
          idx += 4;
        }
      }

      const opts: image.InitializationOptions = {
        size: { width: width, height: height },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: false
      };
      return await image.createPixelMap(buffer, opts);
    } catch (e) {
      return undefined;
    }
  }

  /**
   * 🌈 动态生成符合图 1 极光光束/气体消散效果的彩虹尾迹 (Rainbow Beam & Gas Vapor Dissipation)
   * 顶部与 48px 单向 6 色彩虹 (紫->蓝->绿->黄->橙->红) 100% 严丝合缝同轴对接，
   * 向下如真实气体与光芒般自然纵向渐隐消散至透明 (Alpha 100% -> 0%)
   */
  public static async generateRainbowGasBeamTailPixelMap(targetWidthPx: number = 48, targetHeightPx: number = 60): Promise<image.PixelMap | undefined> {
    try {
      const scale = 2; // 2x 超采样抗锯齿
      const w = targetWidthPx * scale; // 96
      const h = targetHeightPx * scale; // 120
      const buffer = new ArrayBuffer(w * h * 4);
      const data = new Uint8Array(buffer);

      const spectrum: RainbowTailColorBand[] = [
        { maxRatio: 1 / 6, r: 175, g: 82, b: 222 }, // 🟣 梦幻紫
        { maxRatio: 2 / 6, r: 10, g: 132, b: 255 },  // 🔵 蔚蓝蓝
        { maxRatio: 3 / 6, r: 52, g: 199, b: 89 },   // 🟢 清新绿
        { maxRatio: 4 / 6, r: 255, g: 204, b: 0 },   // 🟡 阳光黄
        { maxRatio: 5 / 6, r: 255, g: 149, b: 0 },   // 🟠 活力橙
        { maxRatio: 1.0, r: 255, g: 59, b: 48 }      // 🔴 热情红
      ];

      let idx = 0;
      for (let y = 0; y < h; y++) {
        const t = y / h; // 0.0 (顶部) -> 1.0 (底部)
        // 纵向消散衰减曲线 (自上而下平滑淡出至完全透明)
        const alphaT = Math.pow(1.0 - t, 1.25);

        for (let x = 0; x < w; x++) {
          const normX = x / w; // 0.0 -> 1.0 (紫到红)
          let targetColor = spectrum[spectrum.length - 1];
          for (let k = 0; k < spectrum.length; k++) {
            if (normX <= spectrum[k].maxRatio) {
              targetColor = spectrum[k];
              break;
            }
          }

          // 边缘亚像素羽化
          const edgeDist = Math.min(x, w - 1 - x);
          const edgeAlpha = edgeDist < 4 ? edgeDist / 4 : 1.0;
          const finalAlpha = Math.min(1.0, alphaT * edgeAlpha);

          data[idx] = targetColor.r;
          data[idx + 1] = targetColor.g;
          data[idx + 2] = targetColor.b;
          data[idx + 3] = Math.round(finalAlpha * 255);
          idx += 4;
        }
      }

      const opts: image.InitializationOptions = {
        size: { width: w, height: h },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: false
      };
      return await image.createPixelMap(buffer, opts);
    } catch (e) {
      return undefined;
    }
  }

  // 🌈 单向 6 色平行彩虹光带颜色 (从左至右: 🟣紫 -> 🔵蓝 -> 🟢绿 -> 🟡黄 -> 🟠橙 -> 🔴红)
  public static readonly RAINBOW_PARALLEL_COLORS: number[] = [
    0xFFAF52DE, // 0 (最左): 🟣 梦幻紫 (Royal Purple)
    0xFF0A84FF, // 1: 🔵 蔚蓝蓝 (Azure Blue)
    0xFF34C759, // 2: 🟢 清新绿 (Mint Green)
    0xFFFFCC00, // 3: 🟡 阳光黄 (Golden Sun)
    0xFFFF9500, // 4: 🟠 活力橙 (Sunset Orange)
    0xFFFF3B30  // 5 (最右): 🔴 热情红 (Ruby Red)
  ];

  /**
   * 🌈 根据航线点集与连续相机缩放等级，生成屏幕恒定宽度 (36px) 的单向 6 色平行彩虹光带地理坐标
   * @param basePoints 原始航线已飞过点集合
   * @param continuousZoom 当前相机连续缩放等级 (浮点数，无量化阶跃)
   */
  public static generateParallelRainbowStripes(
    basePoints: mapCommon.LatLng[],
    continuousZoom: number = 17.0
  ): Array<mapCommon.LatLng[]> {
    if (!basePoints || basePoints.length === 0) {
      return [[], [], [], [], [], []];
    }

    // 1. 过滤无效/微小重复点
    const pts: mapCommon.LatLng[] = [];
    for (let i = 0; i < basePoints.length; i++) {
      const p = basePoints[i];
      if (pts.length === 0) {
        pts.push(p);
      } else {
        const lastP = pts[pts.length - 1];
        const distSq = Math.pow(p.latitude - lastP.latitude, 2) + Math.pow(p.longitude - lastP.longitude, 2);
        if (distSq > 1e-12) {
          pts.push(p);
        }
      }
    }
    if (pts.length === 0) {
      return [[], [], [], [], [], []];
    }

    const lat0 = pts[0].latitude;
    // 使用高精度连续浮点缩放比例，杜绝 0.1 阶跃抖动
    const meterPerPixel = 156543.03392 * Math.cos(lat0 * Math.PI / 180) / Math.pow(2, continuousZoom);

    // 6 条色带在屏幕上的中心偏移像素 (紧密贴合无缝，中心距 3.0px，与 14px 线宽重叠咬合，100% 紧密挨在一起零黑缝)
    const offsetsPx: number[] = [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5];
    const result: Array<mapCommon.LatLng[]> = [[], [], [], [], [], []];

    // 2. 预计算每个航线点的切线朝向 (Heading)
    const headings: number[] = new Array(pts.length);
    for (let i = 0; i < pts.length; i++) {
      if (i < pts.length - 1) {
        headings[i] = MapRenderHelper.calculateBearing(pts[i], pts[i + 1]);
      } else if (i > 0) {
        headings[i] = headings[i - 1];
      } else {
        headings[i] = 202.5;
      }
      if (isNaN(headings[i])) {
        headings[i] = 202.5;
      }
    }

    // 起点首点强制与跑道绝对平行，彻底杜绝尾部 90° 旋转倒钩缺陷
    headings[0] = 202.5;

    // 3. 计算 6 条平行色带经纬度坐标
    // 顶端精准延伸 +3.5 屏幕像素进入飞机机翼主梁内部，100% 严密被机翼覆盖
    const tipAdvancePx = 3.5;

    for (let k = 0; k < 6; k++) {
      const offsetM = offsetsPx[k] * meterPerPixel;
      const stripePts: mapCommon.LatLng[] = new Array(pts.length);
      for (let i = 0; i < pts.length; i++) {
        const pt = pts[i];
        const normalAngleRad = (headings[i] + 90) * Math.PI / 180;
        const dLat = (offsetM * Math.cos(normalAngleRad)) / 111320;
        const dLng = (offsetM * Math.sin(normalAngleRad)) / (111320 * Math.cos(pt.latitude * Math.PI / 180));

        let advLat = 0;
        let advLng = 0;
        if (i === pts.length - 1 && pts.length > 1) {
          const advM = tipAdvancePx * meterPerPixel;
          const headRad = headings[i] * Math.PI / 180;
          advLat = (advM * Math.cos(headRad)) / 111320;
          advLng = (advM * Math.sin(headRad)) / (111320 * Math.cos(pt.latitude * Math.PI / 180));
        }

        stripePts[i] = {
          latitude: pt.latitude + dLat + advLat,
          longitude: pt.longitude + dLng + advLng
        };
      }
      result[k] = stripePts;
    }
    return result;
  }

  public static getRainbowColorForProgress(progress: number): RainbowColorInfo {
    const p = Math.max(0, Math.min(0.999, progress));
    const idx = Math.floor(p * 7);
    const result: RainbowColorInfo = {
      core: MapRenderHelper.RAINBOW_COLORS[idx],
      glow: MapRenderHelper.RAINBOW_GLOW_COLORS[idx]
    };
    return result;
  }

  /**
   * ✈️ 一键完整加载跑道、滑行道与加粗预告航线
   */
  public static async setupRunwaysAndRoutes(controller: map.MapComponentController): Promise<void> {
    const customRunwayPolygons = getCustomRunwaysForAirport('CTU');
    if (customRunwayPolygons) {
      for (const corners of customRunwayPolygons) {
        await MapRenderHelper.drawSingleRunway(controller, corners);
      }
    }

    await MapRenderHelper.drawUnflownPreviewRoute(controller);
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
    const departureArc: mapCommon.LatLng[] = generateQuadraticBezierPoints(turnStartPoint, departureControlPoint, turnEndPoint, 300);
    const cruiseSegment: mapCommon.LatLng[] = generateGreatCirclePoints(turnEndPoint, landingStartPoint, 150);
    const arrivalArc: mapCommon.LatLng[] = generateQuadraticBezierPoints(landingStartPoint, arrivalControlPoint, landingEndPoint, 300);
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
