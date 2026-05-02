import { PreferenceManager } from '../utils/PreferenceManager';
import { FileLog } from '../utils/FileLog';
import common from '@ohos.app.ability.common';

const TAG = 'SessionStore';


export class SessionStore {
  private static initialized: boolean = false;
  private static eventHubCtx: common.UIAbilityContext | null = null;

  
  static async init(context: common.UIAbilityContext) {
    if (SessionStore.initialized) return;
    SessionStore.initialized = true;
    SessionStore.eventHubCtx = context;

    
    let savedKey = await PreferenceManager.getString('security_key', '');
    if (savedKey) {
      AppStorage.setOrCreate('security_key', savedKey);
      FileLog.i(TAG, `从磁盘恢复 security_key, 长度=${savedKey.length}`);
    }

    
    let autoSimp = await PreferenceManager.getBoolean('autoSimp', true);
    AppStorage.setOrCreate('autoSimp', autoSimp);

    
    let userInfoStr = await PreferenceManager.getString('userInfo', '');
    if (userInfoStr) {
      try {
        let userInfo: Object = JSON.parse(userInfoStr);
        AppStorage.setOrCreate('userInfo', userInfo);
      } catch (e) {}
    }

    
    let navbarTransparency = await PreferenceManager.getNumber('navbarTransparency', 40);
    AppStorage.setOrCreate('navbarTransparency', navbarTransparency);
    let navbarBlurRadius = await PreferenceManager.getNumber('navbarBlurRadius', 30);
    AppStorage.setOrCreate('navbarBlurRadius', navbarBlurRadius);

    
    let preloadPowerMode = await PreferenceManager.getBoolean('preloadPowerMode', false);
    AppStorage.setOrCreate('preloadPowerMode', preloadPowerMode);

    FileLog.i(TAG, `初始化完成: loggedIn=${savedKey !== ''}, autoSimp=${autoSimp}`);
  }

  

  static setSecurityKey(key: string) {
    AppStorage.setOrCreate('security_key', key);
    
    PreferenceManager.putStringImmediate('security_key', key);
    
    SessionStore.emit('auth_state_changed', key);
    FileLog.i(TAG, `security_key 已设置, 长度=${key.length}`);
  }

  static clearAuth() {
    AppStorage.setOrCreate('security_key', '');
    AppStorage.setOrCreate('userInfo', null);
    PreferenceManager.putStringImmediate('security_key', '');
    PreferenceManager.putString('userInfo', '');
    PreferenceManager.putString('cache_history', '[]');
    PreferenceManager.putString('cache_collection', '[]');
    SessionStore.emit('auth_state_changed', '');
    FileLog.i(TAG, 'Auth 已清除');
  }

  static getSecurityKey(): string {
    return AppStorage.get<string>('security_key') ?? '';
  }

  static isLoggedIn(): boolean {
    let key = SessionStore.getSecurityKey();
    return key !== '' && key.length > 0;
  }

  static getUid(): number {
    let key = SessionStore.getSecurityKey();
    if (!key) return 0;
    let parts = key.split(':');
    if (parts.length >= 2) {
      return parseInt(parts[1]);
    }
    return 0;
  }

  

  static setAutoSimp(value: boolean) {
    AppStorage.setOrCreate('autoSimp', value);
    PreferenceManager.putBoolean('autoSimp', value);
  }

  static getAutoSimp(): boolean {
    return AppStorage.get<boolean>('autoSimp') ?? true;
  }

  

  private static emit(event: string, data: string) {
    if (SessionStore.eventHubCtx) {
      try {
        SessionStore.eventHubCtx.eventHub.emit(event, data);
      } catch (e) {
        FileLog.w(TAG, `EventHub emit 失败: ${event}`);
      }
    }
  }
}
