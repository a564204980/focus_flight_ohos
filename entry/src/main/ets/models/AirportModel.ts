/**
 * AirportModel.ts
 * Focus Flight 机场模型与地理定位算法
 */

export interface Airport {
  code: string;       // 三字码 (如 PEK)
  name: string;       // 机场名称 (如 北京首都国际机场)
  city: string;       // 城市名 (如 北京)
  lat: number;        // 纬度
  lon: number;        // 经度
}

// 常用与枢纽机场数据库
export const POPULAR_AIRPORTS: Airport[] = [
  { code: 'PEK', name: '北京首都国际机场', city: '北京', lat: 40.0801, lon: 116.5846 },
  { code: 'PKX', name: '北京大兴国际机场', city: '北京', lat: 39.5092, lon: 116.4105 },
  { code: 'PVG', name: '上海浦东国际机场', city: '上海', lat: 31.1434, lon: 121.8052 },
  { code: 'SHA', name: '上海虹桥国际机场', city: '上海', lat: 31.1979, lon: 121.3363 },
  { code: 'CAN', name: '广州白云国际机场', city: '广州', lat: 23.3924, lon: 113.2988 },
  { code: 'SZX', name: '深圳宝安国际机场', city: '深圳', lat: 22.6393, lon: 113.8107 },
  { code: 'TFU', name: '成都天府国际机场', city: '成都', lat: 30.3217, lon: 104.4419 },
  { code: 'CTU', name: '成都双流国际机场', city: '成都', lat: 30.5785, lon: 103.9471 },
  { code: 'HGH', name: '杭州萧山国际机场', city: '杭州', lat: 30.2295, lon: 120.4344 },
  { code: 'WUH', name: '武汉天河国际机场', city: '武汉', lat: 30.7838, lon: 114.2081 },
  { code: 'XIY', name: '西安咸阳国际机场', city: '西安', lat: 34.4471, lon: 108.7516 },
  { code: 'CKG', name: '重庆江北国际机场', city: '重庆', lat: 29.7192, lon: 106.6417 },
  { code: 'NKG', name: '南京禄口国际机场', city: '南京', lat: 31.7420, lon: 118.8620 },
  { code: 'XMN', name: '厦门高崎国际机场', city: '厦门', lat: 24.5440, lon: 118.1278 },
  { code: 'TSN', name: '天津滨海国际机场', city: '天津', lat: 39.1244, lon: 117.3462 },
  { code: 'CGO', name: '郑州新郑国际机场', city: '郑州', lat: 34.5197, lon: 113.8409 },
  { code: 'TAO', name: '青岛胶东国际机场', city: '青岛', lat: 36.3475, lon: 120.0886 },
  { code: 'CSX', name: '长沙黄花国际机场', city: '长沙', lat: 28.1892, lon: 113.2196 },
  { code: 'KMG', name: '昆明长水国际机场', city: '昆明', lat: 25.1019, lon: 102.9292 },
  { code: 'HKG', name: '香港国际机场', city: '香港', lat: 22.3080, lon: 113.9185 },
  { code: 'MFM', name: '澳门国际机场', city: '澳门', lat: 22.1496, lon: 113.5916 },
  { code: 'TPE', name: '台湾桃园国际机场', city: '台北', lat: 25.0777, lon: 121.2328 },
  { code: 'HND', name: '东京羽田国际机场', city: '东京', lat: 35.5494, lon: 139.7798 },
  { code: 'NRT', name: '东京成田国际机场', city: '东京', lat: 35.7720, lon: 140.3929 },
  { code: 'ICN', name: '首尔仁川国际机场', city: '首尔', lat: 37.4602, lon: 126.4407 },
  { code: 'SIN', name: '新加坡樟宜机场', city: '新加坡', lat: 1.3644, lon: 103.9915 },
  { code: 'LHR', name: '伦敦希思罗机场', city: '伦敦', lat: 51.4700, lon: -0.4543 },
  { code: 'CDG', name: '巴黎戴高乐机场', city: '巴黎', lat: 49.0097, lon: 2.5479 },
  { code: 'JFK', name: '纽约肯尼迪国际机场', city: '纽约', lat: 40.6413, lon: -73.7781 },
  { code: 'LAX', name: '洛杉矶国际机场', city: '洛杉矶', lat: 33.9416, lon: -118.4085 }
];

/**
 * 计算球面大圆物理距离 (单位: 公里 KM)
 */
export function getDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // 地球平均半径 (KM)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

/**
 * 根据经纬度查找物理距离最近的机场
 */
export function findNearestAirport(userLat: number, userLon: number): Airport {
  let minDistance = Infinity;
  let nearestAirport = POPULAR_AIRPORTS[0];

  for (const airport of POPULAR_AIRPORTS) {
    const dist = getDistanceKm(userLat, userLon, airport.lat, airport.lon);
    if (dist < minDistance) {
      minDistance = dist;
      nearestAirport = airport;
    }
  }

  return nearestAirport;
}

/**
 * 根据机场代码查找机场
 */
export function findAirportByCode(code: string): Airport | undefined {
  return POPULAR_AIRPORTS.find(a => a.code === code);
}
