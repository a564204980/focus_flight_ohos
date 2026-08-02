import { mapCommon } from '@kit.MapKit';

/**
 * GeodesicUtils.ts
 * 地球测地线 / 大圆航线算法工具 (Great Circle / Slerp Interpolation)
 * 用于计算三维椭球体/球面上两点间的最短测地线轨迹弧点序列
 */

export interface LatLngPoint {
  latitude: number;
  longitude: number;
}

/**
 * 根据起点和终点，基于大圆算法 (Great Circle Interpolation) 生成自然光滑的弧线点集
 * @param origin 起点 { latitude, longitude }
 * @param dest 终点 { latitude, longitude }
 * @param numPoints 插值点密度，默认 60 个点
 */
export function generateGreatCirclePoints(
  origin: LatLngPoint,
  dest: LatLngPoint,
  numPoints: number = 600
): Array<mapCommon.LatLng> {
  const points: Array<mapCommon.LatLng> = [];

  const toRad = (deg: number): number => (deg * Math.PI) / 180.0;
  const toDeg = (rad: number): number => (rad * 180.0) / Math.PI;

  const lat1 = toRad(origin.latitude);
  const lon1 = toRad(origin.longitude);
  const lat2 = toRad(dest.latitude);
  const lon2 = toRad(dest.longitude);

  // 转换为三维单位向量
  const v1 = [
    Math.cos(lat1) * Math.cos(lon1),
    Math.cos(lat1) * Math.sin(lon1),
    Math.sin(lat1)
  ];
  const v2 = [
    Math.cos(lat2) * Math.cos(lon2),
    Math.cos(lat2) * Math.sin(lon2),
    Math.sin(lat2)
  ];

  // 计算夹角 theta
  const dot = Math.min(Math.max(v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2], -1.0), 1.0);
  const theta = Math.acos(dot);

  // 如果起终点几乎重合
  if (theta < 1e-6) {
    points.push({ latitude: origin.latitude, longitude: origin.longitude });
    points.push({ latitude: dest.latitude, longitude: dest.longitude });
    return points;
  }

  const sinTheta = Math.sin(theta);

  for (let i = 0; i <= numPoints; i++) {
    const t = i / numPoints;
    const a = Math.sin((1 - t) * theta) / sinTheta;
    const b = Math.sin(t * theta) / sinTheta;

    const x = a * v1[0] + b * v2[0];
    const y = a * v1[1] + b * v2[1];
    const z = a * v1[2] + b * v2[2];

    const lat = Math.atan2(z, Math.sqrt(x * x + y * y));
    const lon = Math.atan2(y, x);

    points.push({
      latitude: toDeg(lat),
      longitude: toDeg(lon)
    });
  }

  return points;
}

/**
 * 计算两个经纬度点之间的切线方位角 (Bearing In Degrees 0..360)
 */
export function calculateBearing(start: LatLngPoint, end: LatLngPoint): number {
  const toRad = (deg: number): number => (deg * Math.PI) / 180.0;
  const toDeg = (rad: number): number => (rad * 180.0) / Math.PI;

  const lat1 = toRad(start.latitude);
  const lon1 = toRad(start.longitude);
  const lat2 = toRad(end.latitude);
  const lon2 = toRad(end.longitude);

  const dLon = lon2 - lon1;
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

  let brng = toDeg(Math.atan2(y, x));
  return (brng + 360) % 360;
}

/**
 * 角度平滑插值 (处理 0/360 度跨越问题)
 */
export function interpolateAngle(a1: number, a2: number, alpha: number): number {
  let diff = (a2 - a1) % 360;
  if (diff > 180) {
    diff -= 360;
  } else if (diff < -180) {
    diff += 360;
  }
  let result = a1 + diff * alpha;
  return (result + 360) % 360;
}

