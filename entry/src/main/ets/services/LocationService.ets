/**
 * LocationService.ets
 * Focus Flight 位置权限申请与定位匹配服务
 */

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
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
        
        // 保存定位所得的最近机场到 AppStorage
        AppStorage.setOrCreate('nearestAirport', nearest);
        return nearest;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'LocationService', `LocationService error: ${JSON.stringify(err)}`);
    }

    return null;
  }
}
