import { mapCommon } from '@kit.MapKit';

export interface RouteDistanceProfile {
  physicalDistances: Float64Array;
  rawTotalPhysicalDist: number;
  cumulativeDistances: Float64Array;
  totalRouteDistance: number;
}

export class FlightRouteEngine {
  /**
   * 预计算物理地理距离（Haversine）与起降阶段非线性速度加权剖面 (漫游模式下保持真实物理等速)
   */
  public static buildDistanceProfile(points: mapCommon.LatLng[], isRoaming: boolean = false): RouteDistanceProfile {
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
      const curDist = physicalDistances[i];
      const remainingDist = rawTotalPhysicalDist - curDist;

      let weight = 1.0;
      // 🛫 起飞阶段：前 2.5km 跑道滑跑 (4.0x 加权 -> 平均 200 km/h)，2.5km~15km 爬升平滑加速过渡至 800 km/h 巡航
      if (curDist <= 2.5) {
        weight = 4.0;
      } else if (curDist < 15.0) {
        const t = (curDist - 2.5) / 12.5;
        weight = 1.0 + (4.0 - 1.0) * (0.5 + 0.5 * Math.cos(Math.PI * t));
      }

      // 🛬 落地阶段（仅限非漫游的固定航线）：最后 15km 进近减速与接地滑跑
      if (!isRoaming && rawTotalPhysicalDist > 30.0) {
        if (remainingDist <= 2.5) {
          weight = 5.0; // 跑道滑跑减速阶段赋予充分时间
        } else if (remainingDist < 15.0) {
          const t = (15.0 - remainingDist) / 12.5;
          weight = 1.0 + (4.0 - 1.0) * (0.5 - 0.5 * Math.cos(Math.PI * t));
        }
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

    const p1 = points[i];
    const p2 = points[Math.min(maxIdx, i + 1)];

    // 采用严格线性插值 (Linear Interpolation)：
    // 因为 buildDistanceProfile 已经是基于真实物理距离映射的 rawIndex，
    // 如果用 Catmull-Rom，t 参数在段内会导致速度非线性变化（忽快忽慢），从而产生视觉步进感。
    // 对于高密度航线（如起飞 25 个点，转弯 120 个点），线性插值足以保证轨迹平滑，且速度绝对均匀！
    const lat = p1.latitude + (p2.latitude - p1.latitude) * t;
    const lng = p1.longitude + (p2.longitude - p1.longitude) * t;

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
