import { Airport, findAirportByCode, POPULAR_AIRPORTS, getDistanceKm } from './AirportModel';

/**
 * RouteModel.ts
 * Focus Flight 全球经典精品航线数据库 (Classic Routes Database)
 */

export interface ClassicRoute {
  id: string;
  routeName: string;      // 航线名称 (如 京沪黄金商务干线)
  category: string;       // 分类 (如 国内干线 / 亚洲精品 / 跨洲远洋)
  originAirport: Airport; // 起点机场
  destAirport: Airport;   // 终点机场
  recommendedFlightNo: string; // 推荐执飞航班号
  airlineName: string;   // 航空公司名称
  aircraftType: string;  // 推荐机型
  suggestedFocusMinutes: number; // 建议专注时长 (分钟)
  distanceKm: number;     // 大圆距离 (KM)
  tag: string;            // 航线标签 (如 最繁忙 / 史诗远航 / 商务首选)
}

export const CLASSIC_ROUTES_DATABASE: ClassicRoute[] = [
  // 1. 国内黄金干线
  {
    id: 'route_pek_sha',
    routeName: '京沪黄金商务干线',
    category: '国内干线',
    originAirport: findAirportByCode('SHA') || POPULAR_AIRPORTS[3],
    destAirport: findAirportByCode('PEK') || POPULAR_AIRPORTS[0],
    recommendedFlightNo: 'MU5137',
    airlineName: '中国东方航空',
    aircraftType: '波音 777-300ER',
    suggestedFocusMinutes: 45,
    distanceKm: 1100,
    tag: '🔥 商务首选'
  },
  {
    id: 'route_ctu_pek',
    routeName: '成京蜀道天航线',
    category: '国内干线',
    originAirport: findAirportByCode('CTU') || POPULAR_AIRPORTS[7],
    destAirport: findAirportByCode('PEK') || POPULAR_AIRPORTS[0],
    recommendedFlightNo: '3U8888',
    airlineName: '四川航空',
    aircraftType: '空客 A350-900 (熊猫涂装)',
    suggestedFocusMinutes: 60,
    distanceKm: 1556,
    tag: '🐼 熊猫客机'
  },
  {
    id: 'route_can_pkx',
    routeName: '粤京南北大动脉',
    category: '国内干线',
    originAirport: findAirportByCode('CAN') || POPULAR_AIRPORTS[4],
    destAirport: findAirportByCode('PKX') || POPULAR_AIRPORTS[1],
    recommendedFlightNo: 'CZ3101',
    airlineName: '中国南方航空',
    aircraftType: '空客 A350-900',
    suggestedFocusMinutes: 60,
    distanceKm: 1950,
    tag: '⚡ 大湾区枢纽'
  },
  {
    id: 'route_pvg_szx',
    routeName: '沪深科技走廊航线',
    category: '国内干线',
    originAirport: findAirportByCode('SHA') || POPULAR_AIRPORTS[3],
    destAirport: findAirportByCode('SZX') || POPULAR_AIRPORTS[5],
    recommendedFlightNo: 'HO1251',
    airlineName: '吉祥航空',
    aircraftType: '波音 787-9 (彩绘机)',
    suggestedFocusMinutes: 45,
    distanceKm: 1210,
    tag: '💻 科技精英'
  },
  {
    id: 'route_xmn_pek',
    routeName: '鹭岛京华海峡航线',
    category: '国内干线',
    originAirport: findAirportByCode('XMN') || POPULAR_AIRPORTS[13],
    destAirport: findAirportByCode('PEK') || POPULAR_AIRPORTS[0],
    recommendedFlightNo: 'MF8101',
    airlineName: '厦门航空',
    aircraftType: '波音 787-9 梦想客机',
    suggestedFocusMinutes: 45,
    distanceKm: 1720,
    tag: '🌊 鹭岛清风'
  },

  // 2. 亚洲精品航线
  {
    id: 'route_pvg_hnd',
    routeName: '沪东霓虹空中走廊',
    category: '亚洲精品',
    originAirport: findAirportByCode('PVG') || POPULAR_AIRPORTS[2],
    destAirport: findAirportByCode('HND') || POPULAR_AIRPORTS[22],
    recommendedFlightNo: 'JL088',
    airlineName: '日本航空',
    aircraftType: '波音 787-9',
    suggestedFocusMinutes: 90,
    distanceKm: 1780,
    tag: '🗼 东京夜景'
  },
  {
    id: 'route_hkg_pvg',
    routeName: '港沪香江金融快线',
    category: '亚洲精品',
    originAirport: findAirportByCode('HKG') || POPULAR_AIRPORTS[19],
    destAirport: findAirportByCode('PVG') || POPULAR_AIRPORTS[2],
    recommendedFlightNo: 'CX368',
    airlineName: '国泰航空',
    aircraftType: '空客 A330-300',
    suggestedFocusMinutes: 60,
    distanceKm: 1250,
    tag: '🌃 维港晨光'
  },
  {
    id: 'route_pvg_sin',
    routeName: '沪新狮城赤道快线',
    category: '亚洲精品',
    originAirport: findAirportByCode('PVG') || POPULAR_AIRPORTS[2],
    destAirport: findAirportByCode('SIN') || POPULAR_AIRPORTS[25],
    recommendedFlightNo: 'SQ833',
    airlineName: '新加坡航空',
    aircraftType: '空客 A380-800',
    suggestedFocusMinutes: 120,
    distanceKm: 3800,
    tag: '✈️ 旗舰 A380'
  },

  // 3. 跨洲远洋航线
  {
    id: 'route_ctu_cdg',
    routeName: '成巴天府浪漫欧亚航线',
    category: '跨洲远洋',
    originAirport: findAirportByCode('CTU') || POPULAR_AIRPORTS[7],
    destAirport: findAirportByCode('CDG') || POPULAR_AIRPORTS[27],
    recommendedFlightNo: 'CA933',
    airlineName: '中国国际航空',
    aircraftType: '空客 A350-900',
    suggestedFocusMinutes: 120,
    distanceKm: 8250,
    tag: '🍷 跨洲飞跃'
  },
  {
    id: 'route_pvg_lhr',
    routeName: '沪伦日不落洲际极光线',
    category: '跨洲远洋',
    originAirport: findAirportByCode('PVG') || POPULAR_AIRPORTS[2],
    destAirport: findAirportByCode('LHR') || POPULAR_AIRPORTS[26],
    recommendedFlightNo: 'BA168',
    airlineName: '英国航空',
    aircraftType: '波音 787-10',
    suggestedFocusMinutes: 120,
    distanceKm: 9200,
    tag: '🕰️ 泰晤士河'
  },
  {
    id: 'route_pvg_jfk',
    routeName: '沪纽太平洋跨大洋航线',
    category: '跨洲远洋',
    originAirport: findAirportByCode('PVG') || POPULAR_AIRPORTS[2],
    destAirport: findAirportByCode('JFK') || POPULAR_AIRPORTS[28],
    recommendedFlightNo: 'MU587',
    airlineName: '中国东方航空',
    aircraftType: '波音 777-300ER',
    suggestedFocusMinutes: 120,
    distanceKm: 11800,
    tag: '🌎 穿越日界线'
  }
];
