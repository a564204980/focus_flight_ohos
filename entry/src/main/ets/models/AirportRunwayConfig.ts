import { mapCommon } from '@kit.MapKit';

/**
 * 跑道四角经纬度多边形数据结构
 * [P0 (入口左), P1 (末端左), P2 (末端右), P3 (入口右)]
 */
export interface RunwayPolygon {
  name?: string; // 跑道编号（如 "02L/20R"、"02R/20L"）
  corners: [mapCommon.LatLng, mapCommon.LatLng, mapCommon.LatLng, mapCommon.LatLng];
}

/**
 * 机场跑道完整配置接口
 */
export interface AirportRunwayConfig {
  airportCode: string;
  airportName: string;
  runways: RunwayPolygon[];
}

/**
 * ✈️ 全局精修机场跑道地理数据库
 * 向更多机场（如 PEK, SHA, PKX 等）扩展跑道只需在此配置集中增加条目即可
 */
export const CUSTOM_AIRPORT_RUNWAYS: Record<string, AirportRunwayConfig> = {
  'CTU': {
    airportCode: 'CTU',
    airportName: '成都双流国际机场',
    runways: [
      {
        name: '02L/20R',
        corners: [
          { latitude: 30.560833, longitude: 103.941889 }, // P0: 入口左角
          { latitude: 30.591398, longitude: 103.956138 }, // P1: 末端左角
          { latitude: 30.591245, longitude: 103.956647 }, // P2: 末端右角
          { latitude: 30.560623, longitude: 103.942425 }  // P3: 入口右角
        ]
      },
      {
        name: '02R/20L',
        corners: [
          { latitude: 30.560229, longitude: 103.943749 }, // P0: 入口左角
          { latitude: 30.592609, longitude: 103.958881 }, // P1: 末端左角
          { latitude: 30.592465, longitude: 103.959298 }, // P2: 末端右角
          { latitude: 30.560064, longitude: 103.944281 }  // P3: 入口右角
        ]
      }
    ]
  }
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
