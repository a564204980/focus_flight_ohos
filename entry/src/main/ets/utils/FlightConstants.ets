import { ctuAirportConfig } from '../models/airports/ctu';
import { pekAirportConfig } from '../models/airports/pek';
import { LatLngPoint } from '../utils/GeodesicUtils';

export function getCtuRunwayStart(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.start || { latitude: 30.592085, longitude: 103.958889 };
}

export function getCtuRunwayEnd(): LatLngPoint {
  return ctuAirportConfig.takeoffRunway?.end || { latitude: 30.562957, longitude: 103.945340 };
}

export const CTU_RUNWAY_BEARING: number = ctuAirportConfig.runwayAngle ?? 158;
export const CLEAN_DARK_AVIATION_STYLE_JSON: string = '[{"mapFeature":"poi","options":"all","visibility":"off"},{"mapFeature":"road","featureName":"label","visibility":"off"},{"mapFeature":"administrative","featureName":"label","visibility":"off"},{"mapFeature":"transportation","featureName":"label","visibility":"off"}]';
