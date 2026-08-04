import { AbilityConstant, ConfigurationConstant, UIAbility, Want, errorManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { LocationService } from '../services/LocationService';


const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 注册全局未捕获异常 Observer，接管三方 SDK 内部发出的非致命异步异常，防止应用崩溃闪退
    try {
      let observer: errorManager.ErrorObserver = {
        onUnhandledException(errMsg: string) {
          hilog.warn(DOMAIN, 'AppError', 'Unhandled exception caught: %{public}s', errMsg);
        },
        onException(err: Error) {
          hilog.warn(DOMAIN, 'AppError', 'Exception caught: %{public}s, stack: %{public}s', err.message, err.stack || '');
        }
      };
      errorManager.on('error', observer);
    } catch (e) {
      hilog.error(DOMAIN, 'AppError', 'Failed to register errorManager observer');
    }



    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      AppStorage.setOrCreate('abilityContext', this.context);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      // 内容加载完成后开启窗口沉浸式全屏与导航栏暗色沉浸
      windowStage.getMainWindow().then((windowClass) => {
        if (windowClass) {
          windowClass.setWindowLayoutFullScreen(true);
          windowClass.setWindowBackgroundColor('#020617');
          windowClass.setWindowSystemBarProperties({
            statusBarColor: '#00000000',
            navigationBarColor: '#00000000',
            statusBarContentColor: '#FFFFFF',
            navigationBarContentColor: '#FFFFFF'
          });
        }
      }).catch((error: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to setWindowLayoutFullScreen: %{public}s', JSON.stringify(error));
      });

      // 主动唤起位置权限预热申请
      LocationService.requestLocationAndGetNearestAirport(this.context);
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}