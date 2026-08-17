import { AirportRunwayConfig, TakeoffRunway } from '../AirportRunwayConfig';

/**
 * 泸州云龙机场 (LZO) 精修跑道地理网格数据 (依据用户实测 4 角点精准拟合)
 */
export const lzoAirportConfig: AirportRunwayConfig = {
  airportCode: 'LZO',
  airportName: '泸州云龙机场',
  runwayAngle: 253, // 泸州 25 跑道朝向约 253 度
  runways: [
    {
      name: '07/25',
      corners: [
        { latitude: 29.032173, longitude: 105.487926 }, // P0: 东北入口左角 (点2)
        { latitude: 29.023607, longitude: 105.456622 }, // P1: 西南末端左角 (点3)
        { latitude: 29.023158, longitude: 105.456774 }, // P2: 西南末端右角 (点4)
        { latitude: 29.031701, longitude: 105.488075 }  // P3: 东北入口右角 (点1)
      ]
    }
  ],
  takeoffRunway: {
    runwayName: '25',
    start: { latitude: 29.031937, longitude: 105.488001 },
    end: { latitude: 29.023383, longitude: 105.456698 },
    cameraRatio: 0.5
  }
};
