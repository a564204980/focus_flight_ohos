import { mapCommon } from '@kit.MapKit';

export interface RouteDistanceProfile {
  physicalDistances: Float64Array;
  rawTotalPhysicalDist: number;
  cumulativeDistances: Float64Array;
  totalRouteDistance: number;
}

export class FlightRouteEngine {
  /**
   * 预计算物理地理距离（Haversine）与起降阶段非线性速度加权剖面
   */
  public static buildDistanceProfile(points: mapCommon.LatLng[]): RouteDistanceProfile {
    const deg2rad = Math.PI / 180;
    const len = points.length;
    const physicalDistances = new Float64Array(len);
    physicalDistances[0] = 0;
    let rawTotalPhysicalDist = 0;

    for (let i = 1; i < len; i++) {
      const p1 = points[i - 1];
      const p2 = points[i];
      const dLat = (p2.latitude - p1.latitude) * deg2rad;
      const dLon = (p2.longitude - p1.longitude) * deg2rad;
      const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(p1.latitude * deg2rad) * Math.cos(p2.latitude * deg2rad) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2);
      const d = 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)); // km
      rawTotalPhysicalDist += d;
      physicalDistances[i] = rawTotalPhysicalDist;
    }

    const cumulativeDistances = new Float64Array(len);
    cumulativeDistances[0] = 0;
    let totalRouteDistance = 0;

    for (let i = 1; i < len; i++) {
      const segPhysDist = physicalDistances[i] - physicalDistances[i - 1];
      const ratio = rawTotalPhysicalDist > 0 ? physicalDistances[i] / rawTotalPhysicalDist : 0;

      let weight = 1.0;
      if (ratio <= 0.04) {
        weight = 3.2;
      } else if (ratio < 0.08) {
        const t = (ratio - 0.04) / 0.04;
        weight = 3.2 - (3.2 - 1.0) * (0.5 - 0.5 * Math.cos(Math.PI * t));
      } else if (ratio <= 0.92) {
        weight = 1.0;
      } else if (ratio < 0.96) {
        const t = (ratio - 0.92) / 0.04;
        weight = 1.0 + (3.2 - 1.0) * (0.5 - 0.5 * Math.cos(Math.PI * t));
      } else {
        weight = 3.2;
      }

      totalRouteDistance += (segPhysDist * weight);
      cumulativeDistances[i] = totalRouteDistance;
    }

    return {
      physicalDistances,
      rawTotalPhysicalDist,
      cumulativeDistances,
      totalRouteDistance
    };
  }

  /**
   * Catmull-Rom 样条平滑插值函数
   */
  public static getSmoothPosition(points: mapCommon.LatLng[], idx: number): mapCommon.LatLng {
    const maxIdx = points.length - 1;
    if (idx <= 0) return points[0];
    if (idx >= maxIdx) return points[maxIdx];

    const i = Math.floor(idx);
    const t = idx - i;

    const p0 = points[Math.max(0, i - 1)];
    const p1 = points[i];
    const p2 = points[Math.min(maxIdx, i + 1)];
    const p3 = points[Math.min(maxIdx, i + 2)];

    const t2 = t * t;
    const t3 = t2 * t;

    const lat = 0.5 * (
      (2 * p1.latitude) +
      (-p0.latitude + p2.latitude) * t +
      (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t2 +
      (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t3
    );

    const lng = 0.5 * (
      (2 * p1.longitude) +
      (-p0.longitude + p2.longitude) * t +
      (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t2 +
      (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t3
    );

    return { latitude: lat, longitude: lng };
  }

  /**
   * 计算两个经纬度点之间的航向角 (0~360度)
   */
  public static calculateHeadingAngle(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const dLat = lat2 - lat1;
    const dLon = (lon2 - lon1) * Math.cos(lat1 * Math.PI / 180);
    const rad = Math.atan2(dLon, dLat);
    const deg = rad * 180 / Math.PI;
    return (deg + 360) % 360;
  }
}
