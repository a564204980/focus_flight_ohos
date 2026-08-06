import { mapCommon } from '@kit.MapKit';
import { ctuAirportConfig } from './airports/ctu';

/**
 * 跑道四角经纬度多边形数据结构
 * [P0 (入口左), P1 (末端左), P2 (末端右), P3 (入口右)]
 */
export interface RunwayPolygon {
  name?: string; // 跑道编号（如 "02L/20R"、"02R/20L"）
  corners: [mapCommon.LatLng, mapCommon.LatLng, mapCommon.LatLng, mapCommon.LatLng];
}

/**
 * 起飞滑行跑道数据（用于地图镜头对齐与航线连线）
 * start: 滑行起点经纬度（飞机出发位置）
 * end:   滑行终点经纬度（起飞拉起位置）
 */
export interface TakeoffRunway {
  runwayName: string; // 起飞跑道编号（如 "02L"）
  start: mapCommon.LatLng;
  end: mapCommon.LatLng;
  cameraRatio?: number;
}

/**
 * 机场跑道完整配置接口
 */
export interface AirportRunwayConfig {
  airportCode: string;
  airportName: string;
  runwayAngle?: number; // 跑道专属对齐角度 (如 158 度)
  runways: RunwayPolygon[];
  taxiways?: Array<Array<mapCommon.LatLng>>;
  takeoffRunway?: TakeoffRunway; // 当前起飞跑道（用于地图锚定与航线连线）
}

/**
 * ✈️ 全局精修机场跑道地理数据库
 * 向更多机场（如 PEK, SHA, PKX 等）扩展跑道只需在 airports/ 目录下创建文件并在在此注册即可
 */
export const CUSTOM_AIRPORT_RUNWAYS: Record<string, AirportRunwayConfig> = {
  'CTU': ctuAirportConfig
};

/**
 * 根据机场代码获取对应精修跑道四角多边形数组
 * @param airportCode 机场 IATA 代码（如 'CTU'）
 * @returns 跑道四角坐标数组列表，未配置则返回 undefined
 */
export function getCustomRunwaysForAirport(airportCode: string): Array<Array<mapCommon.LatLng>> | undefined {
  const config = CUSTOM_AIRPORT_RUNWAYS[airportCode];
  if (!config || !config.runways || config.runways.length === 0) {
    return undefined;
  }
  return config.runways.map(r => [
    r.corners[0],
    r.corners[1],
    r.corners[2],
    r.corners[3]
  ]);
}

/**
 * 根据机场代码获取对应精修滑行道网络路径
 * @param airportCode 机场 IATA 代码（如 'CTU'）
 */
export function getCustomTaxiwaysForAirport(airportCode: string): Array<Array<mapCommon.LatLng>> | undefined {
  const config = CUSTOM_AIRPORT_RUNWAYS[airportCode];
  if (!config || !config.taxiways || config.taxiways.length === 0) {
    return undefined;
  }
  return config.taxiways;
}

/**
 * 获取机场当前起飞跑道的起终点坐标
 * @param airportCode 机场 IATA 代码（如 'CTU'）
 */
export function getAirportTakeoffRunway(airportCode: string): TakeoffRunway | undefined {
  const config = CUSTOM_AIRPORT_RUNWAYS[airportCode];
  return config?.takeoffRunway;
}
