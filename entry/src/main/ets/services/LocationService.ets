/**
 * LocationService.ets
 * Focus Flight 位置权限申请与定位匹配服务
 */

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { Airport, findNearestAirport } from '../models/AirportModel';

const DOMAIN = 0x0000;

export class LocationService {
  /**
   * 申请位置权限并自动匹配最近的出发机场
   */
  static async requestLocationAndGetNearestAirport(customContext?: common.UIAbilityContext): Promise<Airport | null> {
    try {
      hilog.info(DOMAIN, 'LocationService', 'Starting location permission check...');
      
      // 1. 获取合法的 UIAbilityContext
      const context: common.UIAbilityContext | undefined = customContext || AppStorage.get<common.UIAbilityContext>('abilityContext');
      
      const permissions: Array<Permissions> = [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ];

      const atManager = abilityAccessCtrl.createAtManager();

      if (context) {
        hilog.info(DOMAIN, 'LocationService', 'Found valid UIAbilityContext, requesting permissions from user...');
        const grantStatus = await atManager.requestPermissionsFromUser(context, permissions);
        hilog.info(DOMAIN, 'LocationService', `requestPermissionsFromUser result: ${JSON.stringify(grantStatus.authResults)}`);
        
        const isGranted = grantStatus.authResults.some((result: number) => result === 0);
        if (!isGranted) {
          hilog.warn(DOMAIN, 'LocationService', 'User denied location permission request');
          return null;
        }
      } else {
        hilog.warn(DOMAIN, 'LocationService', 'No UIAbilityContext found in AppStorage or argument');
      }

      hilog.info(DOMAIN, 'LocationService', 'Location permission confirmed. Getting current location...');

      // 2. 调起位置服务获取单次定位
      const requestInfo: geoLocationManager.SingleLocationRequest = {
        locatingTimeoutMs: 8000,
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED
      };

      const location = await geoLocationManager.getCurrentLocation(requestInfo);
      if (location && location.latitude !== undefined && location.longitude !== undefined) {
        hilog.info(DOMAIN, 'LocationService', `Location obtained: lat=${location.latitude}, lon=${location.longitude}`);
        const nearest = findNearestAirport(location.latitude, location.longitude);
        hilog.info(DOMAIN, 'LocationService', `Matched nearest airport: ${nearest.name} (${nearest.code})`);
        
        // 保存当前定位的最近机场到 AppStorage (用于本次航班选择)
        AppStorage.setOrCreate('nearestAirport', nearest);

        // 3. 永久固化用户的首次母港签发机场 (如果首次已记录，后续改变定位这里绝不覆盖更新)
        if (context) {
          await LocationService.persistInitialIssueAirportIfEmpty(context, nearest);
        }
        return nearest;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'LocationService', `LocationService error: ${JSON.stringify(err)}`);
    }

    return null;
  }

  /**
   * 确保并固化用户的首次母港签发机场 (一旦首次记录，终生不再变更)
   */
  static async persistInitialIssueAirportIfEmpty(context: common.Context, airport: Airport): Promise<string> {
    try {
      const pref = await preferences.getPreferences(context, 'focus_passport_prefs');
      const existing = await pref.get('initial_issue_airport', '');
      if (!existing || typeof existing !== 'string' || existing.length === 0) {
        const airportName = `${airport.city || airport.name}机场 (${airport.code})`;
        await pref.put('initial_issue_airport', airportName);
        await pref.flush();
        AppStorage.setOrCreate('initialIssueAirportName', airportName);
        return airportName;
      } else {
        AppStorage.setOrCreate('initialIssueAirportName', existing as string);
        return existing as string;
      }
    } catch (e) {
      const airportName = `${airport.city || airport.name}机场 (${airport.code})`;
      AppStorage.setOrCreate('initialIssueAirportName', airportName);
      return airportName;
    }
  }

  /**
   * 获取用户首次签发母港机场名称 (优先从持久化首选项读取)
   */
  static async getInitialIssueAirportName(context?: common.Context): Promise<string> {
    try {
      const memory = AppStorage.get<string>('initialIssueAirportName');
      if (memory && memory.length > 0) {
        return memory;
      }
      const ctx = context || AppStorage.get<common.UIAbilityContext>('abilityContext');
      if (ctx) {
        const pref = await preferences.getPreferences(ctx, 'focus_passport_prefs');
        const existing = await pref.get('initial_issue_airport', '');
        if (existing && typeof existing === 'string' && existing.length > 0) {
          AppStorage.setOrCreate('initialIssueAirportName', existing);
          return existing;
        }
      }
    } catch (e) { }
    return '成都双流 (CTU)';
  }
}
