import { AirportRunwayConfig, TakeoffRunway } from '../AirportRunwayConfig';

/**
 * 南充高坪机场 (NAO) 精修跑道地理网格数据
 */
export const naoAirportConfig: AirportRunwayConfig = {
  airportCode: 'NAO',
  airportName: '南充高坪机场',
  runwayAngle: 58, // 南充高坪机场 06/24 跑道朝向角度约 58 度
  runways: [
    {
      name: '06/24',
      corners: [
        { latitude: 30.789169, longitude: 106.155174 }, // P0: 西南入口左角 (精修对齐)
        { latitude: 30.802819, longitude: 106.181193 }, // P1: 东北末端左角
        { latitude: 30.802386, longitude: 106.181504 }, // P2: 东北末端右角
        { latitude: 30.788742, longitude: 106.155471 }  // P3: 西南入口右角
      ]
    }
  ],
  takeoffRunway: {
    runwayName: '06',
    start: { latitude: 30.788956, longitude: 106.155323 },
    end: { latitude: 30.802603, longitude: 106.181349 },
    cameraRatio: 0.5
  }
};
