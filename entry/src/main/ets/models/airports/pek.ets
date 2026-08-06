import { AirportRunwayConfig, TakeoffRunway } from '../AirportRunwayConfig';

/**
 * 北京首都国际机场 (PEK) 精修跑道数据配置
 */
export const pekAirportConfig: AirportRunwayConfig = {
  airportCode: 'PEK',
  airportName: '北京首都国际机场',
  runwayAngle: 18, // 北京首都国际机场 01/19 跑道角度
  runways: [
    {
      name: '01/19',
      corners: [
        { latitude: 40.070000, longitude: 116.600000 },
        { latitude: 40.090000, longitude: 116.610000 },
        { latitude: 40.089500, longitude: 116.611000 },
        { latitude: 40.069500, longitude: 116.601000 }
      ]
    }
  ],
  takeoffRunway: {
    runwayName: '01',
    start: { latitude: 40.079857, longitude: 116.603114 }, // PEK 降落进近/巡航衔接起点
    end: { latitude: 40.091200, longitude: 116.615000 },   // PEK 降落接地终点
    cameraRatio: 0.046
  } as TakeoffRunway
};
