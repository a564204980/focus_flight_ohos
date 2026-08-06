import { mapCommon } from '@kit.MapKit';

/**
 * GeodesicUtils.ets
 * 地球测地线 / 大圆航线算法工具 (Great Circle / Slerp Interpolation)
 * 包含跑道 ICAO 战术灯光标线几何插值计算函数 (ZebraStripes, TouchdownZone, PAPI, RunwayPoint)
 */

export type LatLngPoint = mapCommon.LatLng;

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
 * 🌀 工业级三阶贝塞尔曲线插值算法 (Cubic Bézier Interpolation)
 * 专门用于消除航线在跑道拉起/高空转向处的折角，生成圆润自然的切线光滑弧线
 * @param p0 弧线起点
 * @param p1 第一控制点 (切线控制)
 * @param p2 第二控制点 (切线控制)
 * @param p3 弧线终点
 * @param numPoints 细分采样点密度
 */
export function generateCubicBezierPoints(
  p0: LatLngPoint,
  p1: LatLngPoint,
  p2: LatLngPoint,
  p3: LatLngPoint,
  numPoints: number = 50
): Array<mapCommon.LatLng> {
  const points: Array<mapCommon.LatLng> = [];
  for (let i = 0; i <= numPoints; i++) {
    const t = i / numPoints;
    const mt = 1 - t;
    const mt2 = mt * mt;
    const mt3 = mt2 * mt;
    const t2 = t * t;
    const t3 = t2 * t;

    const lat = mt3 * p0.latitude + 3 * mt2 * t * p1.latitude + 3 * mt * t2 * p2.latitude + t3 * p3.latitude;
    const lon = mt3 * p0.longitude + 3 * mt2 * t * p1.longitude + 3 * mt * t2 * p2.longitude + t3 * p3.longitude;
    points.push({ latitude: lat, longitude: lon });
  }
  return points;
}

/**
 * 🌀 工业级二次贝塞尔倒角弧线插值算法 (Quadratic Bézier Fillet Arc)
 * 采用起点 p0、折角顶点 v、终点 p2 进行单凸包约束插值，100% 保证绝对圆润相切且无任何过冲或死角折边
 */
export function generateQuadraticBezierPoints(
  p0: LatLngPoint,
  v: LatLngPoint,
  p2: LatLngPoint,
  numPoints: number = 40
): Array<mapCommon.LatLng> {
  const points: Array<mapCommon.LatLng> = [];
  for (let i = 0; i <= numPoints; i++) {
    const t = i / numPoints;
    const mt = 1 - t;
    const lat = mt * mt * p0.latitude + 2 * mt * t * v.latitude + t * t * p2.latitude;
    const lon = mt * mt * p0.longitude + 2 * mt * t * v.longitude + t * t * p2.longitude;
    points.push({ latitude: lat, longitude: lon });
  }
  return points;
}

/**
 * 🌀 工业开源级 Chaikin 拐角切削圆润算法 (Chaikin's Corner Cutting Algorithm)
 * Turf.js / OpenLayers 等开源 GIS 库标准的折线圆润化算法
 * 将任何尖锐死角与硬折角递归切削为极其光滑、圆润的大弧度流线型弯道
 * @param inputPoints 骨架控制点集
 * @param iterations 迭代平滑细化轮次 (默认 4 次)
 */
export function chaikinSmoothPath(
  inputPoints: Array<mapCommon.LatLng>,
  iterations: number = 4
): Array<mapCommon.LatLng> {
  if (inputPoints.length < 3) {
    return inputPoints;
  }

  let points = inputPoints;

  for (let iter = 0; iter < iterations; iter++) {
    const nextPoints: Array<mapCommon.LatLng> = [];
    nextPoints.push(points[0]);

    for (let i = 0; i < points.length - 1; i++) {
      const p0 = points[i];
      const p1 = points[i + 1];

      const q: mapCommon.LatLng = {
        latitude: 0.75 * p0.latitude + 0.25 * p1.latitude,
        longitude: 0.75 * p0.longitude + 0.25 * p1.longitude
      };

      const r: mapCommon.LatLng = {
        latitude: 0.25 * p0.latitude + 0.75 * p1.latitude,
        longitude: 0.25 * p0.longitude + 0.75 * p1.longitude
      };

      nextPoints.push(q);
      nextPoints.push(r);
    }

    nextPoints.push(points[points.length - 1]);
    points = nextPoints;
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

/**
 * 生成跑道直飞起飞与顺畅拐弯切入航线的点集序列
 * @param origin 起飞点 (跑道南端)
 * @param runwayEnd 跑道北端出口点
 * @param dest 目标机场
 * @param numPoints 总采样点数
 */
export function generateRunwayDepartureRoute(
  origin: LatLngPoint,
  runwayEnd: LatLngPoint,
  dest: LatLngPoint,
  numPoints: number = 600
): Array<mapCommon.LatLng> {
  const points: Array<mapCommon.LatLng> = [];

  // 1. 跑道直线段点数占比 (占总点数的 8%)
  const runwaySegmentPoints = Math.round(numPoints * 0.08);
  for (let i = 0; i < runwaySegmentPoints; i++) {
    const t = i / runwaySegmentPoints;
    points.push({
      latitude: origin.latitude + (runwayEnd.latitude - origin.latitude) * t,
      longitude: origin.longitude + (runwayEnd.longitude - origin.longitude) * t
    });
  }

  // 2. 高空大圆巡航航线 (从跑道北端 -> 目的地)
  const cruisePoints = generateGreatCirclePoints(runwayEnd, dest, numPoints - runwaySegmentPoints);

  // 3. 跑道末端大半径极度圆润离场弯道 (使用三次贝塞尔 Cubic Bezier 生成大弧度圆润弯道)
  const turnPointCount = Math.round(numPoints * 0.15);
  if (cruisePoints.length > turnPointCount) {
    const pStart = runwayEnd;
    const pEnd = cruisePoints[turnPointCount];

    // 第一控制点 P1：沿跑道中线向前冲出 1.5 倍延伸矢量，保证从跑道头出来的切线绝对平滑
    const p1: LatLngPoint = {
      latitude: runwayEnd.latitude + (runwayEnd.latitude - origin.latitude) * 1.5,
      longitude: runwayEnd.longitude + (runwayEnd.longitude - origin.longitude) * 1.5
    };

    // 第二控制点 P2：引导弧线优雅切入大圆巡航航线
    const p2: LatLngPoint = {
      latitude: pEnd.latitude - (pEnd.latitude - runwayEnd.latitude) * 0.4,
      longitude: pEnd.longitude - (pEnd.longitude - runwayEnd.longitude) * 0.4
    };

    // 替换折角区，生成极致大弧度、优美圆润的三次贝塞尔离场彩虹弧线
    for (let i = 0; i < turnPointCount; i++) {
      const t = i / turnPointCount;
      const invT = 1.0 - t;
      const lat = invT * invT * invT * pStart.latitude +
                  3 * invT * invT * t * p1.latitude +
                  3 * invT * t * t * p2.latitude +
                  t * t * t * pEnd.latitude;
      const lon = invT * invT * invT * pStart.longitude +
                  3 * invT * invT * t * p1.longitude +
                  3 * invT * t * t * p2.longitude +
                  t * t * t * pEnd.longitude;
      points.push({ latitude: lat, longitude: lon });
    }

    // 拼接剩余高空大圆巡航线
    for (let i = turnPointCount; i < cruisePoints.length; i++) {
      points.push(cruisePoints[i]);
    }
  } else {
    points.push(...cruisePoints);
  }

  return points;
}

/**
 * 根据指定的偏置距离（米），将一条线段（经纬度坐标）平移
 * @param p1 起点
 * @param p2 终点
 * @param offsetMeters 偏移量（正数为右侧偏移，负数为左侧偏移）
 */
export function calculateParallelOffsetLine(
  p1: LatLngPoint,
  p2: LatLngPoint,
  offsetMeters: number
): [mapCommon.LatLng, mapCommon.LatLng] {
  const earthRadius = 6378137.0; // 地球半径(米)
  
  const toRad = (deg: number): number => (deg * Math.PI) / 180.0;
  const toDeg = (rad: number): number => (rad * 180.0) / Math.PI;

  const lat1 = toRad(p1.latitude);
  const lon1 = toRad(p1.longitude);
  const lat2 = toRad(p2.latitude);
  const lon2 = toRad(p2.longitude);

  const dLon = lon2 - lon1;
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  const brng = Math.atan2(y, x);

  // 偏移方位角 (向右偏 90 度，即 PI/2)
  const offsetBrng = brng + (Math.PI / 2);
  const angularDistance = offsetMeters / earthRadius;

  // 使用经纬度球面偏移公式推算新起点
  const newLat1 = Math.asin(Math.sin(lat1) * Math.cos(angularDistance) +
    Math.cos(lat1) * Math.sin(angularDistance) * Math.cos(offsetBrng));
  const newLon1 = lon1 + Math.atan2(Math.sin(offsetBrng) * Math.sin(angularDistance) * Math.cos(lat1),
    Math.cos(angularDistance) - Math.sin(lat1) * Math.sin(newLat1));

  // 使用经纬度球面偏移公式推算新终点
  const newLat2 = Math.asin(Math.sin(lat2) * Math.cos(angularDistance) +
    Math.cos(lat2) * Math.sin(angularDistance) * Math.cos(offsetBrng));
  const newLon2 = lon2 + Math.atan2(Math.sin(offsetBrng) * Math.sin(angularDistance) * Math.cos(lat2),
    Math.cos(angularDistance) - Math.sin(lat2) * Math.sin(newLat2));

  return [
    { latitude: toDeg(newLat1), longitude: toDeg(newLon1) },
    { latitude: toDeg(newLat2), longitude: toDeg(newLon2) }
  ];
}

/**
 * 双线性插值计算跑道矩形/四边形区域内的某点经纬度
 * @param polygon 跑道四角经纬度 [P0 (StartLeft), P1 (EndLeft), P2 (EndRight), P3 (StartRight)]
 * @param u 横向比例 (0 为左侧边，1 为右侧边，<0 为左侧外部，>1 为右侧外部)
 * @param v 纵向比例 (0 为入口端，1 为末端)
 */
export function interpolateRunwayPoint(
  polygon: Array<mapCommon.LatLng>,
  u: number,
  v: number
): mapCommon.LatLng {
  const p0 = polygon[0];
  const p1 = polygon[1];
  const p2 = polygon[2];
  const p3 = polygon[3];

  const startPtLat = p0.latitude + u * (p3.latitude - p0.latitude);
  const startPtLon = p0.longitude + u * (p3.longitude - p0.longitude);

  const endPtLat = p1.latitude + u * (p2.latitude - p1.latitude);
  const endPtLon = p1.longitude + u * (p2.longitude - p1.longitude);

  return {
    latitude: startPtLat + v * (endPtLat - startPtLat),
    longitude: startPtLon + v * (endPtLon - startPtLon)
  };
}

/**
 * 生成跑道入口斑马线标志 (Threshold Stripes) 坐标对集合
 */
export function generateThresholdZebraStripes(
  polygon: Array<mapCommon.LatLng>,
  stripeCount: number = 10
): Array<[mapCommon.LatLng, mapCommon.LatLng]> {
  const stripes: Array<[mapCommon.LatLng, mapCommon.LatLng]> = [];
  const vStart = 0.015;
  const vEnd = 0.055;

  for (let i = 0; i < stripeCount; i++) {
    const u = (i + 0.5) / stripeCount;
    // 避开中线 0.44 ~ 0.56
    if (u >= 0.44 && u <= 0.56) {
      continue;
    }
    const pStart = interpolateRunwayPoint(polygon, u, vStart);
    const pEnd = interpolateRunwayPoint(polygon, u, vEnd);
    stripes.push([pStart, pEnd]);
  }
  return stripes;
}

/**
 * 生成跑道接地带标志 (Touchdown Zone Markings) 坐标对集合
 */
export function generateTouchdownZoneMarkings(
  polygon: Array<mapCommon.LatLng>
): Array<[mapCommon.LatLng, mapCommon.LatLng]> {
  const markings: Array<[mapCommon.LatLng, mapCommon.LatLng]> = [];
  const uLeft = 0.25;
  const uRight = 0.75;
  const vPositions = [0.10, 0.18, 0.26];
  const lengthV = 0.04;

  for (let v of vPositions) {
    // 左侧接地带标线对
    markings.push([
      interpolateRunwayPoint(polygon, uLeft - 0.08, v),
      interpolateRunwayPoint(polygon, uLeft - 0.08, v + lengthV)
    ]);
    markings.push([
      interpolateRunwayPoint(polygon, uLeft + 0.08, v),
      interpolateRunwayPoint(polygon, uLeft + 0.08, v + lengthV)
    ]);

    // 右侧接地带标线对
    markings.push([
      interpolateRunwayPoint(polygon, uRight - 0.08, v),
      interpolateRunwayPoint(polygon, uRight - 0.08, v + lengthV)
    ]);
    markings.push([
      interpolateRunwayPoint(polygon, uRight + 0.08, v),
      interpolateRunwayPoint(polygon, uRight + 0.08, v + lengthV)
    ]);
  }
  return markings;
}

/**
 * 生成 PAPI 进近灯 4 颗灯珠点位坐标 (跑道入口左侧阵列)
 */
export function generatePAPILightPoints(
  polygon: Array<mapCommon.LatLng>
): Array<mapCommon.LatLng> {
  const points: Array<mapCommon.LatLng> = [];
  const uOffsets = [-0.08, -0.13, -0.18, -0.23];
  const vPos = 0.06;

  for (let u of uOffsets) {
    points.push(interpolateRunwayPoint(polygon, u, vPos));
  }
  return points;
}

export interface RunwayEdgeBeads {
  leftBeads: Array<mapCommon.LatLng>;
  rightBeads: Array<mapCommon.LatLng>;
}

/**
 * 生成跑道两侧高密度边缘暖金灯珠阵列 (Runway Edge Light Beads) 坐标集合
 * @param polygon 跑道四角经纬度
 * @param countPerSide 每侧灯珠数量，默认 24 颗
 */
export function generateRunwayEdgeLightBeads(
  polygon: Array<mapCommon.LatLng>,
  countPerSide: number = 24
): RunwayEdgeBeads {
  const leftBeads: Array<mapCommon.LatLng> = [];
  const rightBeads: Array<mapCommon.LatLng> = [];

  for (let i = 0; i <= countPerSide; i++) {
    const v = 0.02 + (i / countPerSide) * 0.96;
    leftBeads.push(interpolateRunwayPoint(polygon, 0.0, v));
    rightBeads.push(interpolateRunwayPoint(polygon, 1.0, v));
  }

  const res: RunwayEdgeBeads = { leftBeads: leftBeads, rightBeads: rightBeads };
  return res;
}

/**
 * 线性插值计算两点间指定比例的经纬度点
 */
export function interpolateLatLng(start: LatLngPoint, end: LatLngPoint, ratio: number): LatLngPoint {
  return {
    latitude: start.latitude + (end.latitude - start.latitude) * ratio,
    longitude: start.longitude + (end.longitude - start.longitude) * ratio
  };
}

/**
 * ✈️ 物理级地图镜头对齐计算器 (Physical Map Camera Anchor Calculator)
 * 根据跑道起点/终点坐标以及屏幕 UI 偏移 (offsetY px)，精准计算地图镜头 Target 坐标。
 * 确保跑道起点 (start) 100% 精准落于屏幕指定的 UI 偏移位置（如 planeY = 170px 飞机正底下）。
 *
 * @param start 跑道起点经纬度 (P1)
 * @param end 跑道终点经纬度 (P2)
 * @param offsetYPx 屏幕中心向下的像素偏移量 (如 170px)
 * @param zoom 地图缩放级别，默认 17.2
 */
export function calculateCameraTargetForAnchor(
  start: LatLngPoint,
  end: LatLngPoint,
  offsetYPx: number = 170,
  zoom: number = 17.2
): LatLngPoint {
  const bearing = calculateBearing(start, end);
  const bearingRad = (bearing * Math.PI) / 180.0;

  // 17.2 缩放级别下，赤道 m/px ≈ 156543.03392 * cos(lat) / (2^zoom)
  const latRad = (start.latitude * Math.PI) / 180.0;
  const metersPerPixel = (156543.03392 * Math.cos(latRad)) / Math.pow(2, zoom);

  // 沿跑道方向向上移动的物理距离（米）
  const distMeters = offsetYPx * metersPerPixel;

  // 转换为地理经纬度偏移（地球半径 R ≈ 6,371,000 米）
  const R = 6371000.0;
  const dLat = (distMeters * Math.cos(bearingRad)) / R * (180.0 / Math.PI);
  const dLon = (distMeters * Math.sin(bearingRad)) / (R * Math.cos(latRad)) * (180.0 / Math.PI);

  return {
    latitude: start.latitude + dLat,
    longitude: start.longitude + dLon
  };
}


