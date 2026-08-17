import { AirportRunwayConfig, TakeoffRunway } from '../AirportRunwayConfig';

/**
 * 甘孜康定机场 (KGT) 精修跑道地理网格数据 (西北 15 跑道降落滑跑至东南 33 跑道头)
 */
export const kgtAirportConfig: AirportRunwayConfig = {
  airportCode: 'KGT',
  airportName: '甘孜康定机场',
  runwayAngle: 149, // 康定机场 15 跑道朝向约 149 度
  runways: [
    {
      name: '15/33',
      corners: [
        { latitude: 30.155854, longitude: 101.729973 }, // P0: 西北入口左角
        { latitude: 30.125046, longitude: 101.750974 }, // P1: 东南末端左角
        { latitude: 30.124840, longitude: 101.750572 }, // P2: 东南末端右角
        { latitude: 30.155648, longitude: 101.729571 }  // P3: 西北入口右角
      ]
    }
  ],
  takeoffRunway: {
    runwayName: '15',
    start: { latitude: 30.155751, longitude: 101.729772 },
    end: { latitude: 30.124943, longitude: 101.750773 },
    cameraRatio: 0.5
  }
};
