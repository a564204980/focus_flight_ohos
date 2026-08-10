// @ts-ignore
import { util } from '@kit.ArkTS';
// @ts-ignore
import { common } from '@kit.AbilityKit';

/**
 * AirportModel.ts
 * Focus Flight 机场模型与地理定位算法
 */

export interface Airport {
  code: string;       // 三字码 (如 PEK)
  name: string;       // 机场名称 (如 北京首都国际机场)
  city: string;       // 城市名 (如 北京)
  lat: number;        // 纬度 (起飞起点)
  lon: number;        // 经度 (起飞起点)
  runwayEndLat?: number; // 跑道第二个坐标点 (跑道末端/离场点纬度)
  runwayEndLon?: number; // 跑道第二个坐标点 (跑道末端/离场点经度)
  country?: string;   // 国家代码 (如 CN, US)
  type?: string;      // 机场等级 (如 large_airport, medium_airport)
  [key: string]: string | number | undefined;
}

import { FULL_AIRPORTS_LIST } from './AllAirportsData';

/**
 * 常用与枢纽机场全量数据库 (涵盖全国250+座民航运输机场 + 全球100+座核心都市机场)
 */
export const POPULAR_AIRPORTS: Airport[] = FULL_AIRPORTS_LIST;

/**
 * 机场全量数据仓储单例类
 */
export class AirportRepository {
  private static cachedAirports: Airport[] = [];
  private static isLoading: boolean = false;

  /**
   * 从 rawfile/data/airports.json 异步加载 5165 个全量客运机场
   */
  public static async loadAirports(context: common.Context): Promise<Airport[]> {
    if (AirportRepository.cachedAirports.length > 0) {
      return AirportRepository.cachedAirports;
    }
    if (AirportRepository.isLoading) {
      return POPULAR_AIRPORTS;
    }
    AirportRepository.isLoading = true;

    try {
      const rm = context.resourceManager;
      const content = await rm.getRawFileContent('data/airports.json');
      const textDecoder = util.TextDecoder.create('utf-8');
      const jsonStr = textDecoder.decodeToString(content);
      const parsed = JSON.parse(jsonStr) as Airport[];
      if (parsed && parsed.length > 0) {
        AirportRepository.cachedAirports = parsed;
      } else {
        AirportRepository.cachedAirports = POPULAR_AIRPORTS;
      }
    } catch (e) {
      console.error('Failed to load rawfile data/airports.json, fallback to POPULAR_AIRPORTS');
      AirportRepository.cachedAirports = POPULAR_AIRPORTS;
    } finally {
      AirportRepository.isLoading = false;
    }

    return AirportRepository.cachedAirports;
  }

  /**
   * 获取所有已知机场 (优先返回全量库，未加载则返回热门列表)
   */
  public static getAllAirports(): Airport[] {
    return AirportRepository.cachedAirports.length > 0 ? AirportRepository.cachedAirports : POPULAR_AIRPORTS;
  }
}

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
  const list = AirportRepository.getAllAirports();
  let nearestAirport = list[0];

  for (const airport of list) {
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
  const list = AirportRepository.getAllAirports();
  const found = list.find(a => a.code === code);
  if (!found) return undefined;
  
  const popular = POPULAR_AIRPORTS.find(a => a.code === code);
  if (popular) {
    return { ...found, ...popular };
  }
  return found;
}

// 示例已被解锁的初始核心枢纽城市集合
const UNLOCKED_SET: Set<string> = new Set(['CTU', 'TFU', 'MIG', 'PEK', 'PVG', 'CAN', 'SZX', 'HND', 'HKG']);

/**
 * 校验机场是否已被解锁打卡
 */
export function isAirportUnlocked(code: string): boolean {
  return UNLOCKED_SET.has(code);
}

/**
 * 解锁新机场城市并颁发印章
 */
export function unlockAirportCode(code: string): void {
  if (code) {
    UNLOCKED_SET.add(code);
  }
}

/**
 * 获取已解锁机场总数
 */
export function getUnlockedCount(): number {
  return UNLOCKED_SET.size;
}

/**
 * 根据机场三字码与地名生成古风水墨特色印章全称
 */
export function getAirportStampTitle(code: string, cityName?: string): string {
  const airport = findAirportByCode(code);
  const city = cityName || airport?.city || code;

  const stampMap: Record<string, string> = {
    'BZX': '【巴中恩阳 · 巴山水墨印章 🏵️】',
    'MIG': '【绵阳南郊 · 越王古楼印章 🏯】',
    'JZH': '【九寨黄龙 · 翠海叠瀑印章 🏔️】',
    'CTU': '【成都双流 · 锦官古蜀印章 🐼】',
    'TFU': '【成都天府 · 太阳神鸟印章 🦅】',
    'PEK': '【北京首都 · 帝都长城印章 🏯】',
    'PKX': '【北京大兴 · 凤凰展翅印章 🪶】',
    'PVG': '【上海浦东 · 东方明珠印章 🌆】',
    'KHG': '【喀什古城 · 丝路风情印章 🐫】',
    'LXA': '【拉萨贡嘎 · 圣地雪域印章 🏔️】',
    'HND': '【东京羽田 · 富士樱花印章 🌸】',
    'CAN': '【广州白云 · 羊城粤韵印章 🍵】',
    'SZX': '【深圳宝安 · 鹏城海浪印章 🌊】',
    'CKG': '【重庆江北 · 雾都山水印章 🌶️】',
    'XIY': '【西安咸阳 · 古都兵马印章 ⚔️】',
    'LZO': '【泸州云龙 · 酒城水墨印章 🍶】',
    'YBP': '【宜宾五粮 · 竹海叙府印章 🎋】',
    'LZG': '【阆中古城 · 汉风三国印章 📜】',
    'NAO': '【南充高坪 · 丝绸源点印章 🧵】'
  };

  if (stampMap[code]) {
    return stampMap[code];
  }
  return `【${city} · 古风水墨地标印章 🏵️】`;
}
