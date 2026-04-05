import { UIAbility, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { T2SEngine } from '../utils/T2SEngine';
import { NativeArticleParser } from '../utils/NativeArticleParser';
import { PreferenceManager } from '../utils/PreferenceManager';
import { FileLog } from '../utils/FileLog';
import { ImageCacheManager } from '../utils/ImageCacheManager';
import { FontManager } from '../utils/FontManager';

const DOMAIN = 0x0001;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private themeSwitchTimer: number = -1;

  onCreate(): void {
    hilog.info(DOMAIN, TAG, '====== EntryAbility onCreate ======');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (this.themeSwitchTimer !== -1) {
      clearTimeout(this.themeSwitchTimer);
    }

    this.themeSwitchTimer = setTimeout(() => {
      try {
        let isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        
        let userPref = AppStorage.get<number>('appColorMode') || 0;
        let actualDark = false;
        if (userPref === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
          actualDark = true;
        } else if (userPref === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
          actualDark = false;
        } else {
          
          actualDark = isDark;
        }
        AppStorage.setOrCreate('isActualDarkMode', actualDark);
        if (this.mainWindow) {
          let sysBarProps: window.SystemBarProperties = {
            statusBarContentColor: isDark ? '#FFFFFF' : '#182431',
            navigationBarContentColor: isDark ? '#FFFFFF' : '#182431'
          };
          this.mainWindow.setWindowSystemBarProperties(sysBarProps).catch((err: Error) => {
            hilog.error(DOMAIN, TAG, 'Async error setting window properties: %{public}s', err.message);
          });
        }
      } catch (exception) {
        hilog.error(DOMAIN, TAG, 'Failed to update window properties');
      }
    }, 250);
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, '====== onWindowStageCreate 开始 ======');

    await PreferenceManager.init(this.context);
    FileLog.init();
    
    let savedDebugMode = PreferenceManager.getBooleanSync('debug_mode', false);
    FileLog.setEnabled(savedDebugMode);
    FileLog.i(TAG, '====== 应用启动 onWindowStageCreate ======');
    hilog.info(DOMAIN, TAG, 'PreferenceManager 初始化完成');

    let savedMode = await PreferenceManager.getNumber('appColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    let savedAutoSimp = await PreferenceManager.getBoolean('autoSimp', true);
    let savedSecurityKey = await PreferenceManager.getString('security_key', '');

    hilog.info(DOMAIN, TAG, '从磁盘读取 security_key 长度=%{public}d', savedSecurityKey.length);
    FileLog.i(TAG, `从磁盘读取 security_key 长度=${savedSecurityKey.length}`);
    hilog.info(DOMAIN, TAG, '从磁盘读取 appColorMode=%{public}d', savedMode);

    
    let savedUserInfoStr = await PreferenceManager.getString('userInfo', '');
    let savedUserInfo: Object | null = null;
    if (savedUserInfoStr && savedUserInfoStr !== '') {
      try {
        savedUserInfo = JSON.parse(savedUserInfoStr);
        hilog.info(DOMAIN, TAG, '从磁盘成功解析 userInfo');
      } catch (e) {
        hilog.error(DOMAIN, TAG, '解析 userInfo 失败');
      }
    }

    AppStorage.setOrCreate('appColorMode', savedMode);
    AppStorage.setOrCreate('autoSimp', savedAutoSimp);
    AppStorage.setOrCreate('security_key', savedSecurityKey);
    
    AppStorage.setOrCreate('userInfo', savedUserInfo);

    
    let savedUseNativeParser = await PreferenceManager.getBoolean('useNativeParser', true);
    let savedUseNativeT2S = await PreferenceManager.getBoolean('useNativeT2S', true);
    AppStorage.setOrCreate('useNativeParser', savedUseNativeParser);
    AppStorage.setOrCreate('useNativeT2S', savedUseNativeT2S);

    
    let isActualDark = false;
    if (savedMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      isActualDark = true;
    } else if (savedMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      isActualDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    AppStorage.setOrCreate('isActualDarkMode', isActualDark);

    
    let verifyKey = AppStorage.get<string>('security_key') || '';
    hilog.info(DOMAIN, TAG, 'AppStorage 验证 security_key 长度=%{public}d', verifyKey.length);

    try {
      this.context.getApplicationContext().setColorMode(savedMode);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to set initial color mode');
    }

    setTimeout(() => {
      T2SEngine.init(this.context);
      NativeArticleParser.init();
    }, 200);

    
    ImageCacheManager.init(this.context);

    
    FontManager.init();
    let savedFont = await PreferenceManager.getString('custom_reading_font', '');
    AppStorage.setOrCreate('custom_reading_font', savedFont);
    FileLog.i(TAG, `字体偏好: custom_reading_font="${savedFont}"`);

    try {
      this.mainWindow = windowStage.getMainWindowSync();
      this.mainWindow.setWindowLayoutFullScreen(true);

      let isDark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      let sysBarProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#182431',
        navigationBarContentColor: isDark ? '#FFFFFF' : '#182431'
      };
      this.mainWindow.setWindowSystemBarProperties(sysBarProps);
      hilog.info(DOMAIN, TAG, '窗口系统栏设置完成, isDark=%{public}s', isDark.toString());
    } catch (exception) {
      hilog.error(DOMAIN, TAG, 'Failed to set window properties');
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) return;
      
      
      FileLog.i(TAG, '页面加载完成，开始注册用户字体...');
      FontManager.initUserFonts(this.context.filesDir).then(() => {
        FileLog.i(TAG, `用户字体注册完成, 已注册: ${FontManager.getAvailableFontNames().join(', ') || '无'}`);
      });
    });
  }

  onWindowStageDestroy(): void {
    this.mainWindow = null;
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'App 进入前台');
  }
  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'App 进入后台');
  }
}
