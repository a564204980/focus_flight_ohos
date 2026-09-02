import { map, mapCommon } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
import { getCustomRunwaysForAirport, getCustomTaxiwaysForAirport, CUSTOM_AIRPORT_RUNWAYS, AirportRunwayConfig } from '../models/AirportRunwayConfig';
import { Airport, findAirportByCode } from '../models/AirportModel';
import { ctuAirportConfig } from '../models/airports/ctu';
import { pekAirportConfig } from '../models/airports/pek';
import {
  generateThresholdZebraStripes,
  generateTouchdownZoneMarkings,
  interpolateRunwayPoint,
  generatePAPILightPoints,
  generateGreatCirclePoints,
  generateQuadraticBezierPoints,
  generateCubicBezierPoints,
  chaikinSmoothPath,
  LatLngPoint,
  interpolateLatLng
} from './GeodesicUtils';
import { ProceduralFlightEngine } from './ProceduralFlightEngine';

export interface RouteStyleConfig {
  id: string;
  name: string;
  subtitle: string;
  badge: string;
  themeColor: string;
  colors: number[];
  widths: number[];
  previewColors: string[];
}

export interface TrailEffectConfig {
  id: string;
  name: string;
  subtitle: string;
  badge: string;
  themeColor: string;
  icon: string;
  colors?: number[];
  widths?: number[];
  previewColors?: string[];
}

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
   * ✈️ 绘制机场滑行道网络 (已按需求隐藏)
   */
  public static async drawTaxiways(
    controller: map.MapComponentController,
    taxiwayPoints: Array<mapCommon.LatLng>
  ): Promise<void> {
    // 隐藏滑行道线
    return;
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
  public static async drawUnflownPreviewRoute(controller: map.MapComponentController, destAirport?: Airport, isRoaming?: boolean): Promise<void> {
    const allPoints = MapRenderHelper.getFullFlightPathPoints(destAirport, isRoaming);
    if (!allPoints || allPoints.length < 2) return;

    // 漫游模式下展示前瞻约 600 个点 (约 45~60 分钟视界)，固定航线展示全程
    const previewPoints = isRoaming ? allPoints.slice(0, Math.min(600, allPoints.length)) : allPoints;

    // 1. 半透明天蓝外光晕
    await controller.addPolyline({
      points: previewPoints,
      width: 8,
      color: 0x2238BDF8,
      zIndex: 800
    });

    // 2. 稳固待解锁实心导引线
    await controller.addPolyline({
      points: previewPoints,
      width: 3,
      color: 0x44CBD5E1,
      zIndex: 801
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
        for (let x = 0; x < width; x++) {
          const normX = x / width;
          let band = spectrum[spectrum.length - 1];
          for (let k = 0; k < spectrum.length; k++) {
            if (normX <= spectrum[k].maxRatio) {
              band = spectrum[k];
              break;
            }
          }
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

  // ✈️ 5 款个性化航线光带/航线风格配置
  public static readonly ROUTE_STYLES_CONFIG: Record<string, RouteStyleConfig> = {
    'rainbow': {
      id: 'rainbow',
      name: '彩虹光谱',
      subtitle: '6色平行流光',
      badge: '治愈流光',
      themeColor: '#AF52DE',
      colors: [0xFFAF52DE, 0xFF0A84FF, 0xFF34C759, 0xFFFFCC00, 0xFFFF9500, 0xFFFF3B30],
      widths: [12.0, 14.0, 14.0, 14.0, 14.0, 12.0],
      previewColors: ['#AF52DE', '#0A84FF', '#34C759', '#FFCC00', '#FF9500', '#FF3B30']
    },
    'aurora': {
      id: 'aurora',
      name: '极光天际',
      subtitle: '青翠紫蓝流光',
      badge: '梦幻极光',
      themeColor: '#00FF88',
      colors: [0xDD00FF88, 0xEE00F5D4, 0xEE00BBF9, 0xDD7209B7, 0x00000000, 0x00000000],
      widths: [14.0, 16.0, 16.0, 14.0, 0, 0],
      previewColors: ['#00FF88', '#00F5D4', '#00BBF9', '#7209B7']
    },
    'ocean': {
      id: 'ocean',
      name: '蔚蓝天路',
      subtitle: '深海透光流线',
      badge: '清爽海风',
      themeColor: '#0284C7',
      colors: [0x8838BDF8, 0xEE0284C7, 0x880369A1, 0x00000000, 0x00000000, 0x00000000],
      widths: [10.0, 16.0, 10.0, 0, 0, 0],
      previewColors: ['#38BDF8', '#0284C7', '#0369A1']
    },
    'blaze': {
      id: 'blaze',
      name: '炽热航路',
      subtitle: '日落暖阳流光',
      badge: '极速破晓',
      themeColor: '#F97316',
      colors: [0x88FB923C, 0xEEF97316, 0x88EA580C, 0x00000000, 0x00000000, 0x00000000],
      widths: [10.0, 16.0, 10.0, 0, 0, 0],
      previewColors: ['#FB923C', '#F97316', '#EA580C']
    },
    'classic': {
      id: 'classic',
      name: '经典航线',
      subtitle: '纯正民航导航',
      badge: '极简航空',
      themeColor: '#64748B',
      colors: [0x99CBD5E1, 0xFFFFFFFF, 0x99CBD5E1, 0x00000000, 0x00000000, 0x00000000],
      widths: [6.0, 12.0, 6.0, 0, 0, 0],
      previewColors: ['#CBD5E1', '#FFFFFF', '#CBD5E1']
    }
  };

  // 💫 5 款专属机尾物理喷气粒子/尾迹特效配置
  public static readonly TRAIL_EFFECTS_CONFIG: Record<string, TrailEffectConfig> = {
    'bubbles': {
      id: 'bubbles',
      name: '梦幻气泡',
      subtitle: '马卡龙水漾透光',
      icon: '',
      badge: '解压水漾',
      themeColor: '#EC4899'
    },
    'stardust': {
      id: 'stardust',
      name: '星光粉尘',
      subtitle: '碎金星辉微光',
      icon: '',
      badge: '闪耀星屑',
      themeColor: '#F59E0B'
    },
    'melody': {
      id: 'melody',
      name: '律动音符',
      subtitle: '心流旋律波形',
      icon: '',
      badge: '心流音律',
      themeColor: '#6366F1'
    },
    'contrail': {
      id: 'contrail',
      name: '凝结尾迹',
      subtitle: '高空双发真实水汽',
      icon: '',
      badge: '纯净双流',
      themeColor: '#0EA5E9'
    },
    'none': {
      id: 'none',
      name: '纯净无尾',
      subtitle: '无额外机尾粒子',
      icon: '',
      badge: '清爽通透',
      themeColor: '#94A3B8'
    }
  };

  // 默认单向 6 色平行彩虹光带颜色 (向下兼容)
  public static readonly RAINBOW_PARALLEL_COLORS: number[] = [
    0xFFAF52DE, // 0: 🟣 梦幻紫
    0xFF0A84FF, // 1: 🔵 蔚蓝蓝
    0xFF34C759, // 2: 🟢 清新绿
    0xFFFFCC00, // 3: 🟡 阳光黄
    0xFFFF9500, // 4: 🟠 活力橙
    0xFFFF3B30  // 5: 🔴 热情红
  ];

  public static getRouteConfig(routeId: string): RouteStyleConfig {
    return MapRenderHelper.ROUTE_STYLES_CONFIG[routeId] || MapRenderHelper.ROUTE_STYLES_CONFIG['rainbow'];
  }

  public static getTrailConfig(trailId: string): TrailEffectConfig {
    return MapRenderHelper.TRAIL_EFFECTS_CONFIG[trailId] || MapRenderHelper.TRAIL_EFFECTS_CONFIG['bubbles'];
  }

  /**
   * 🌈 根据航线点集生成具有物理特性的单向平行航线光带
   * @param basePoints 原始航线已飞过点集合
   * @param zoomLevel 当前相机缩放等级 (默认 17.0)
   * @param routeId 航线风格类型 ('rainbow' | 'aurora' | 'ocean' | 'blaze' | 'classic')
   */
  public static generateParallelRainbowStripes(
    basePoints: mapCommon.LatLng[],
    zoomLevel: number = 17.0,
    routeId: string = 'rainbow'
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
    const meterPerPixel = 156543.03392 * Math.cos(lat0 * Math.PI / 180) / Math.pow(2, zoomLevel);

    // 🌟 根据航线风格计算专属物理偏移分布：
    let offsetsPx: number[];
    if (routeId === 'aurora') {
      offsetsPx = [-7.5, -2.5, 2.5, 7.5, 0, 0];
    } else if (routeId === 'ocean' || routeId === 'blaze' || routeId === 'classic') {
      offsetsPx = [-4.5, 0, 4.5, 0, 0, 0];
    } else {
      // 经典 6 色彩虹
      offsetsPx = [-5.71, -3.43, -1.14, 1.14, 3.43, 5.71];
    }
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
    // 顶端微延伸 2.5 像素深埋于机翼与机身内部，被机翼遮盖
    const tipAdvancePx = 2.5;

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
  public static async setupRunwaysAndRoutes(controller: map.MapComponentController, destAirport?: Airport, isRoaming?: boolean): Promise<void> {
    const customRunwayPolygons = getCustomRunwaysForAirport('CTU');
    if (customRunwayPolygons) {
      for (const corners of customRunwayPolygons) {
        await MapRenderHelper.drawSingleRunway(controller, corners);
      }
    }

    const customTaxiwaySegments = getCustomTaxiwaysForAirport('CTU');
    if (customTaxiwaySegments) {
      for (const segment of customTaxiwaySegments) {
        await MapRenderHelper.drawTaxiways(controller, segment);
      }
    }

    // 绘制目标目的地机场的精修跑道 (漫游模式下不绘制单一终点机场跑道)
    if (!isRoaming && destAirport && destAirport.code && destAirport.code !== 'CTU' && destAirport.code !== 'ROAM') {
      const destRunwayPolygons = getCustomRunwaysForAirport(destAirport.code);
      if (destRunwayPolygons) {
        for (const corners of destRunwayPolygons) {
          await MapRenderHelper.drawSingleRunway(controller, corners);
        }
      }
      const destTaxiwaySegments = getCustomTaxiwaysForAirport(destAirport.code);
      if (destTaxiwaySegments) {
        for (const segment of destTaxiwaySegments) {
          await MapRenderHelper.drawTaxiways(controller, segment);
        }
      }
    }

    await MapRenderHelper.drawUnflownPreviewRoute(controller, destAirport, isRoaming);
  }

  private static cachedRoamingPoints: mapCommon.LatLng[] | undefined = undefined;
  private static lastRoamingSeedTime: number = 0;

  /**
   * ✈️ 获取完整的全程飞行航线点集（普通航班为三阶段点集，漫游模式为动态程序化大圆航迹）
   * @param destAirport 目标目的地机场 (如未提供，则自动从 AppStorage 读取或默认使用北京首都 PEK)
   * @param isRoaming 是否为漫游自由探索模式
   */
  public static getFullFlightPathPoints(destAirport?: Airport, isRoaming?: boolean): mapCommon.LatLng[] {
    // 🌟 若处于漫游模式，直接调用动态程序化航迹生成引擎！
    if (isRoaming || (destAirport && destAirport.code === 'ROAM')) {
      const now = Date.now();
      if (!MapRenderHelper.cachedRoamingPoints || (now - MapRenderHelper.lastRoamingSeedTime > 300000)) {
        MapRenderHelper.lastRoamingSeedTime = now;
        MapRenderHelper.cachedRoamingPoints = ProceduralFlightEngine.generateRoamingTrajectory(43200, (now % 10000));
      }
      return MapRenderHelper.cachedRoamingPoints;
    }

    const ctuStart = getCtuRunwayStart();
    const ctuEnd = getCtuRunwayEnd();

    // 解析目标目的地机场
    let targetDest: Airport | undefined = destAirport;
    if (!targetDest) {
      const storedDest = AppStorage.get<Airport>('selectedDestinationAirport');
      if (storedDest) {
        targetDest = storedDest;
      }
    }
    if (!targetDest) {
      const storedCode = AppStorage.get<string>('selectedDestinationCode');
      if (storedCode) {
        targetDest = findAirportByCode(storedCode);
      }
    }
    if (!targetDest) {
      targetDest = findAirportByCode('PEK');
    }

    let destStart: LatLngPoint;
    let destEnd: LatLngPoint;

    const customConfig: AirportRunwayConfig | undefined = targetDest ? CUSTOM_AIRPORT_RUNWAYS[targetDest.code] : undefined;
    if (customConfig && customConfig.takeoffRunway) {
      destStart = { latitude: customConfig.takeoffRunway.start.latitude, longitude: customConfig.takeoffRunway.start.longitude };
      destEnd = { latitude: customConfig.takeoffRunway.end.latitude, longitude: customConfig.takeoffRunway.end.longitude };
    } else if (targetDest && targetDest.code === 'PEK') {
      destStart = getPekRunwayStart();
      destEnd = getPekRunwayEnd();
    } else if (targetDest && targetDest.lat !== undefined && targetDest.lon !== undefined) {
      const dLat = Number(targetDest.lat);
      const dLon = Number(targetDest.lon);
      destStart = { latitude: dLat, longitude: dLon };
      if (targetDest.runwayEndLat !== undefined && targetDest.runwayEndLon !== undefined) {
        destEnd = { latitude: Number(targetDest.runwayEndLat), longitude: Number(targetDest.runwayEndLon) };
      } else {
        // 计算标准着陆跑道延伸点 (沿航线朝向延伸约 2.5km)
        destEnd = { latitude: dLat + 0.015, longitude: dLon + 0.015 };
      }
    } else {
      destStart = getPekRunwayStart();
      destEnd = getPekRunwayEnd();
    }

    // 1. 跑道滑跑拉升段 (直线沿跑道 202.5°)
    const turnStartPoint = interpolateLatLng(ctuStart, ctuEnd, 0.65);
    const taxiSegment: mapCommon.LatLng[] = generateGreatCirclePoints(ctuStart, turnStartPoint, 20);

    // 2. 离场平滑切线转弯段 (使用三阶贝塞尔切线连续曲线，彻底消除硬折角和直角)
    // 跑道延伸控制点 C0 (确保与跑道直线 100% 相切)
    const c0 = interpolateLatLng(ctuStart, ctuEnd, 2.2);

    // 巡航衔接点 P3 与巡航切线控制点 C1 (位于大圆航线起端约 30km 处，确保与高空巡航线 100% 平滑相切)
    const ctuVertex: mapCommon.LatLng = { latitude: ctuStart.latitude, longitude: ctuStart.longitude };
    const destVertex: mapCommon.LatLng = { latitude: destStart.latitude, longitude: destStart.longitude };

    const cruiseStartPoint = interpolateLatLng(ctuVertex, destVertex, 0.04);
    const c1 = interpolateLatLng(cruiseStartPoint, ctuVertex, 0.5);

    const departureArc: mapCommon.LatLng[] = generateCubicBezierPoints(turnStartPoint, c0, c1, cruiseStartPoint, 250);

    // 3. 高空大圆巡航段
    const landingStartPoint = interpolateLatLng(ctuVertex, destVertex, 0.96);
    const cruiseSegment: mapCommon.LatLng[] = generateGreatCirclePoints(cruiseStartPoint, landingStartPoint, 200);

    // 4. 进近降落平滑切线弧线 (对齐跑道中线并在跑道 20% 接地带平滑触地)
    const touchdownPoint = interpolateLatLng(destVertex, destEnd, 0.20);
    const a0 = interpolateLatLng(landingStartPoint, destVertex, 0.5);
    const a1 = interpolateLatLng(destVertex, destEnd, -0.6);

    const arrivalArc: mapCommon.LatLng[] = generateCubicBezierPoints(landingStartPoint, a0, a1, touchdownPoint, 250);

    // 5. 跑道着陆滑行减速段 (沿跑道中线滑行，在跑道长度的 80% 处彻底停稳)
    const runwayStopPoint = interpolateLatLng(destVertex, destEnd, 0.80);
    const landingSegment: mapCommon.LatLng[] = generateGreatCirclePoints(touchdownPoint, runwayStopPoint, 60);

    const rawPoints = taxiSegment
      .concat(departureArc.slice(1))
      .concat(cruiseSegment.slice(1))
      .concat(arrivalArc.slice(1))
      .concat(landingSegment.slice(1));

    // 使用 Chaikin 平滑算法消除任何残留微小硬折角
    return chaikinSmoothPath(rawPoints, 2);
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
