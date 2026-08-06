import { AirportRunwayConfig, TakeoffRunway } from '../AirportRunwayConfig';

/**
 * 成都双流国际机场 (CTU) 精修跑道与滑行道地理网格数据
 */
export const ctuAirportConfig: AirportRunwayConfig = {
  airportCode: 'CTU',
  airportName: '成都双流国际机场',
  runwayAngle: 158, // 双流国际机场跑道角度设置为 158 度
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
    },
    {
      name: 'New Custom Runway',
      corners: [
        { latitude: 30.547734, longitude: 103.953626 }, // P0: 入口左角 (NE, East)
        { latitude: 30.515636, longitude: 103.938664 }, // P1: 末端左角 (SW, East)
        { latitude: 30.515866, longitude: 103.937987 }, // P2: 末端右角 (SW, West)
        { latitude: 30.547972, longitude: 103.952943 }  // P3: 入口右角 (NE, West)
      ]
    },
    {
      name: 'Another Custom Runway',
      corners: [
        { latitude: 30.550920, longitude: 103.952825 }, // P0: 入口左角 (NE, East)
        { latitude: 30.517122, longitude: 103.937192 }, // P1: 末端左角 (SW, East)
        { latitude: 30.517407, longitude: 103.936426 }, // P2: 末端右角 (SW, West)
        { latitude: 30.551098, longitude: 103.952309 }  // P3: 入口右角 (NE, West)
      ]
    }
  ],
  taxiways: [
    [
      { latitude: 30.563363, longitude: 103.943685 },
      { latitude: 30.562881, longitude: 103.944959 }
    ],
    [
      { latitude: 30.567142, longitude: 103.946957 },
      { latitude: 30.569489, longitude: 103.946516 }
    ],
    [
      { latitude: 30.570599, longitude: 103.948562 },
      { latitude: 30.572840, longitude: 103.948080 }
    ],
    [
      { latitude: 30.581883, longitude: 103.952303 },
      { latitude: 30.583203, longitude: 103.954452 }
    ],
    [
      { latitude: 30.547296, longitude: 103.951124 },
      { latitude: 30.546846, longitude: 103.952393 }
    ],
    [
      { latitude: 30.545347, longitude: 103.950243 },
      { latitude: 30.544897, longitude: 103.951471 }
    ],
    [
      { latitude: 30.534626, longitude: 103.945266 },
      { latitude: 30.532441, longitude: 103.945665 }
    ],
    [
      { latitude: 30.529803, longitude: 103.943014 },
      { latitude: 30.529732, longitude: 103.943234 },
      { latitude: 30.529793, longitude: 103.943619 },
      { latitude: 30.530565, longitude: 103.944802 }
    ],
    [
      { latitude: 30.524754, longitude: 103.940703 },
      { latitude: 30.524636, longitude: 103.940921 },
      { latitude: 30.524698, longitude: 103.941257 },
      { latitude: 30.525637, longitude: 103.942525 }
    ],
    [
      { latitude: 30.519350, longitude: 103.938219 },
      { latitude: 30.518969, longitude: 103.939393 }
    ],
    [
      { latitude: 30.517374, longitude: 103.937302 },
      { latitude: 30.516996, longitude: 103.938488 }
    ],
    [
      { latitude: 30.517629, longitude: 103.936526 },
      { latitude: 30.517730, longitude: 103.936291 },
      { latitude: 30.518209, longitude: 103.936110 },
      { latitude: 30.520644, longitude: 103.937240 },
      { latitude: 30.524305, longitude: 103.938941 },
      { latitude: 30.529649, longitude: 103.941436 },
      { latitude: 30.534560, longitude: 103.943715 },
      { latitude: 30.538072, longitude: 103.945354 },
      { latitude: 30.540423, longitude: 103.946454 },
      { latitude: 30.545190, longitude: 103.948676 },
      { latitude: 30.547777, longitude: 103.949880 },
      { latitude: 30.551947, longitude: 103.951823 },
      { latitude: 30.553977, longitude: 103.952770 },
      { latitude: 30.556682, longitude: 103.954026 },
      { latitude: 30.558177, longitude: 103.954726 },
      { latitude: 30.560542, longitude: 103.955730 },
      { latitude: 30.561895, longitude: 103.956349 },
      { latitude: 30.563592, longitude: 103.957148 }
    ],
    [
      { latitude: 30.537246, longitude: 103.946491 },
      { latitude: 30.535453, longitude: 103.946788 },
      { latitude: 30.534858, longitude: 103.946825 }
    ],
    [
      { latitude: 30.540539, longitude: 103.948022 },
      { latitude: 30.538247, longitude: 103.948399 }
    ],
    [
      { latitude: 30.534910, longitude: 103.944667 },
      { latitude: 30.535002, longitude: 103.944432 },
      { latitude: 30.535192, longitude: 103.944252 },
      { latitude: 30.535360, longitude: 103.944197 },
      { latitude: 30.535629, longitude: 103.944206 }
    ],
    [
      { latitude: 30.537370, longitude: 103.945826 },
      { latitude: 30.537414, longitude: 103.945562 },
      { latitude: 30.537638, longitude: 103.945416 },
      { latitude: 30.537850, longitude: 103.945382 },
      { latitude: 30.538165, longitude: 103.945393 }
    ],
    [
      { latitude: 30.532783, longitude: 103.939332 },
      { latitude: 30.537969, longitude: 103.941780 }
    ],
    [
      { latitude: 30.536644, longitude: 103.941171 },
      { latitude: 30.535719, longitude: 103.943826 }
    ],
    [
      { latitude: 30.540690, longitude: 103.947394 },
      { latitude: 30.540779, longitude: 103.947140 },
      { latitude: 30.540847, longitude: 103.947015 },
      { latitude: 30.540956, longitude: 103.946929 },
      { latitude: 30.541096, longitude: 103.946859 }
    ],
    [
      { latitude: 30.578403, longitude: 103.950654 },
      { latitude: 30.579570, longitude: 103.952195 },
      { latitude: 30.579647, longitude: 103.952438 },
      { latitude: 30.579631, longitude: 103.952621 },
      { latitude: 30.579545, longitude: 103.952767 }
    ],
    [
      { latitude: 30.550745, longitude: 103.952730 },
      { latitude: 30.550736, longitude: 103.952828 },
      { latitude: 30.549387, longitude: 103.956748 }
    ],
    [
      { latitude: 30.558079, longitude: 103.944124 },
      { latitude: 30.559070, longitude: 103.944597 },
      { latitude: 30.559403, longitude: 103.944747 },
      { latitude: 30.559826, longitude: 103.944950 },
      { latitude: 30.560258, longitude: 103.945150 }
    ],
    [
      { latitude: 30.560249, longitude: 103.945144 },
      { latitude: 30.562881, longitude: 103.946368 },
      { latitude: 30.565354, longitude: 103.947521 },
      { latitude: 30.565707, longitude: 103.947682 },
      { latitude: 30.566028, longitude: 103.947830 }
    ],
    [
      { latitude: 30.560762, longitude: 103.942486 },
      { latitude: 30.560673, longitude: 103.942581 },
      { latitude: 30.560632, longitude: 103.942633 },
      { latitude: 30.560338, longitude: 103.943480 },
      { latitude: 30.560244, longitude: 103.943751 }
    ],
    [
      { latitude: 30.560073, longitude: 103.944279 },
      { latitude: 30.559826, longitude: 103.944945 },
      { latitude: 30.559663, longitude: 103.945436 }
    ],
    [
      { latitude: 30.558079, longitude: 103.944122 },
      { latitude: 30.557469, longitude: 103.943844 },
      { latitude: 30.556399, longitude: 103.943350 },
      { latitude: 30.556401, longitude: 103.943348 },
      { latitude: 30.556008, longitude: 103.943206 },
      { latitude: 30.555594, longitude: 103.943127 },
      { latitude: 30.555045, longitude: 103.943142 },
      { latitude: 30.554651, longitude: 103.943235 },
      { latitude: 30.554302, longitude: 103.943384 },
      { latitude: 30.553359, longitude: 103.943844 },
      { latitude: 30.551843, longitude: 103.944610 },
      { latitude: 30.549676, longitude: 103.945694 },
      { latitude: 30.548034, longitude: 103.946519 },
      { latitude: 30.547590, longitude: 103.946777 },
      { latitude: 30.547197, longitude: 103.947070 },
      { latitude: 30.546656, longitude: 103.947598 },
      { latitude: 30.546321, longitude: 103.948027 },
      { latitude: 30.546081, longitude: 103.948411 },
      { latitude: 30.546026, longitude: 103.948506 },
      { latitude: 30.545857, longitude: 103.948743 },
      { latitude: 30.545804, longitude: 103.948957 },
      { latitude: 30.546023, longitude: 103.948514 }
    ],
   
  ],
  takeoffRunway: {
    runwayName: '02L',
    start: { latitude: 30.592085, longitude: 103.958889 }, // 02L 跑道滑行起点
    end: { latitude: 30.570222, longitude: 103.948708 },   // 02L 跑道拉起终点
    cameraRatio: 0.046  // 实机精准校正：使跑道起点 (30.561173, 103.942350) 精准对齐 planeY = 170 飞机位置
  } as TakeoffRunway
};
