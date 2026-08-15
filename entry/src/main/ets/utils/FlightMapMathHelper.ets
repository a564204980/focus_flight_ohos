import { map, mapCommon } from '@kit.MapKit';
import { Airport, POPULAR_AIRPORTS, findAirportByCode, getDistanceKm } from '../models/AirportModel';

export interface ScreenVpPoint {
  x: number;
  y: number;
}

export interface RulerFiveMinUnit {
  minutes: number;
  isMajor: boolean;
}

export interface AirportMarkerEntry {
  marker: map.Marker;
  code: string;
}

export interface MapAirportNode {
  airport: Airport;
  xPct: number;
  yPct: number;
  isUnlocked?: boolean;
}


// ─────────────────────────────────────────────
// 刻度尺常量与静态数据
// ─────────────────────────────────────────────

/** 每个小刻度格子的宽度 (vp) */
export const RULER_SUB_WIDTH: number = 8;
/** 每个 5 分钟步进的总宽度 (vp)：1 主刻度 + 3 紧凑小刻度 = 4 * 8 = 32vp */
export const RULER_STEP_WIDTH: number = 32;

/** 15 ~ 240 分钟，按 5 分钟步进的刻度列表 */
export const RULER_FIVE_MIN_UNITS: RulerFiveMinUnit[] = [];
for (let m = 15; m <= 240; m += 5) {
  RULER_FIVE_MIN_UNITS.push({
    minutes: m,
    isMajor: m % 15 === 0
  });
}

// ─────────────────────────────────────────────
// 纯数学算法函数
// ─────────────────────────────────────────────

/**
 * 分段线性插值（Knot 曲线）
 */
export function lerpByKnots(minutes: number, times: number[], values: number[]): number {
  if (minutes <= times[0]) return values[0];
  if (minutes >= times[times.length - 1]) return values[values.length - 1];
  for (let i = 0; i < times.length - 1; i++) {
    if (minutes >= times[i] && minutes <= times[i + 1]) {
      const t = (minutes - times[i]) / (times[i + 1] - times[i]);
      return values[i] + t * (values[i + 1] - values[i]);
    }
  }
  return values[values.length - 1];
}

/** 根据专注分钟数返回最大可达飞行距离 (km) */
export function getMaxFlightDistanceKm(minutes: number): number {
  const times = [15, 25, 45, 60, 90, 120, 180, 240];
  const maxDists = [420, 850, 1650, 2300, 3800, 5800, 9500, 12000];
  return lerpByKnots(minutes, times, maxDists);
}

/** 根据专注分钟数返回最小可达飞行距离 (km) */
export function getMinFlightDistanceKm(minutes: number): number {
  const times = [15, 25, 45, 60, 90, 120, 180, 240];
  const minDists = [80, 350, 700, 1100, 1800, 2800, 4800, 6500];
  return lerpByKnots(minutes, times, minDists);
}

/**
 * 连续视界缩放算法：自适应对齐 155vp 稳定雷达圈，
 * 确保对应分钟数的候选目的地全员容纳在雷达圈内
 */
export function getContinuousZoomLevel(minutes: number): number {
  const maxDist = getMaxFlightDistanceKm(minutes);
  const targetZoom = Math.log2(20893.5 / maxDist);
  return Math.max(1.2, Math.min(5.6, targetZoom));
}

export function getCenteredCameraLatitude(originLat: number, zoom: number = 2.0): number {
  const degPerPixel = 360.0 / (256.0 * Math.pow(2, zoom));
  const offsetDeg = 20.0 * degPerPixel;
  return originLat - offsetDeg;
}

/** 计算两点正北方位角 (°) */
export function getBearingDeg(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const dLon = (lon2 - lon1) * Math.PI / 180.0;
  const y = Math.sin(dLon) * Math.cos(lat2 * Math.PI / 180.0);
  const x = Math.cos(lat1 * Math.PI / 180.0) * Math.sin(lat2 * Math.PI / 180.0) -
            Math.sin(lat1 * Math.PI / 180.0) * Math.cos(lat2 * Math.PI / 180.0) * Math.cos(dLon);
  return (Math.atan2(y, x) * 180.0 / Math.PI + 360.0) % 360.0;
}

/**
 * 360° 八方位全向散射算法：
 * 在给定分钟数的航程范围内，从 8 个扇区各抽取距离最贴近黄金中心的代表性机场，
 * 最终按距离由近及远排序，返回候选列表。
 */
export function filterAndSampleCandidateAirports(
  minutes: number,
  getBearing: (lat1: number, lon1: number, lat2: number, lon2: number) => number
): Airport[] {
  const origin = findAirportByCode('CTU');
  if (!origin || origin.lat === undefined || origin.lon === undefined) {
    return POPULAR_AIRPORTS.slice(0, 6);
  }

  const maxDist = getMaxFlightDistanceKm(minutes);
  const minDist = getMinFlightDistanceKm(minutes);
  const midDist = (minDist + maxDist) / 2.0;

  const inRange = POPULAR_AIRPORTS.filter(apt => {
    if (apt.code === 'CTU' || apt.code === 'TFU' || apt.lat === undefined || apt.lon === undefined) return false;
    const dist = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
    return dist >= minDist && dist <= maxDist;
  });

  const sectors: Airport[][] = [[], [], [], [], [], [], [], []];
  inRange.forEach(apt => {
    const b = getBearing(Number(origin.lat), Number(origin.lon), Number(apt.lat), Number(apt.lon));
    const sIdx = Math.floor(b / 45.0) % 8;
    sectors[sIdx].push(apt);
  });

  const scatteredList: Airport[] = [];
  sectors.forEach(sec => {
    if (sec.length > 0) {
      sec.sort((a, b) => {
        const d1 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(a.lat), Number(a.lon));
        const d2 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(b.lat), Number(b.lon));
        return Math.abs(d1 - midDist) - Math.abs(d2 - midDist);
      });
      scatteredList.push(sec[0]);
    }
  });

  if (scatteredList.length < 6) {
    const candidates = inRange.filter(apt => !scatteredList.some(item => item.code === apt.code));
    candidates.sort((a, b) => {
      const d1 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(a.lat), Number(a.lon));
      const d2 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(b.lat), Number(b.lon));
      return Math.abs(d1 - midDist) - Math.abs(d2 - midDist);
    });
    for (let i = 0; i < candidates.length && scatteredList.length < 8; i++) {
      scatteredList.push(candidates[i]);
    }
  }

  scatteredList.sort((a, b) => {
    const d1 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(a.lat), Number(a.lon));
    const d2 = getDistanceKm(Number(origin.lat), Number(origin.lon), Number(b.lat), Number(b.lon));
    return d1 - d2;
  });

  return scatteredList.length > 0 ? scatteredList : POPULAR_AIRPORTS.slice(0, 6);
}

/**
 * 计算贝塞尔曲线路径点列表（支持跨 180° 日界线最短路径计算）
 */
export function calculateBezierCurve(
  originLat: number, originLon: number,
  targetLat: number, targetLon: number,
  totalSteps: number = 45
): mapCommon.LatLng[] {
  let dLon = targetLon - originLon;
  if (dLon > 180) {
    dLon -= 360;
  } else if (dLon < -180) {
    dLon += 360;
  }

  const dLat = targetLat - originLat;
  const midLat = (originLat + targetLat) / 2.0;
  // 控制点坐标：基于最短 dLon 和 dLat 添加垂直法线弯曲系数
  const ctrlLat = midLat - dLon * 0.12;
  const ctrlLon = originLon + dLon * 0.5 + dLat * 0.12;

  const curve: mapCommon.LatLng[] = [];
  for (let i = 0; i <= totalSteps; i++) {
    const t = i / totalSteps;
    const lat = (1 - t) * (1 - t) * originLat + 2 * (1 - t) * t * ctrlLat + t * t * targetLat;
    const rawLon = (1 - t) * (1 - t) * originLon + 2 * (1 - t) * t * ctrlLon + t * t * (originLon + dLon);

    // 标准化经度至 [-180, 180] 区间
    let normLon = rawLon;
    while (normLon > 180) normLon -= 360;
    while (normLon < -180) normLon += 360;

    curve.push({ latitude: lat, longitude: normLon });
  }
  return curve;
}
