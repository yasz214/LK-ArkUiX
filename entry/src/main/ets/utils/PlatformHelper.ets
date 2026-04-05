

import bridge from '@arkui-x.bridge';
import { FileLog } from './FileLog';

const TAG = 'PlatformHelper';

let platformChecked: boolean = false;
let isAndroidPlatform: boolean = false;

function detectPlatform(): void {
  if (platformChecked) return;
  platformChecked = true;

  try {
    
    
    bridge.createBridge('BrowserBridge');
    isAndroidPlatform = true;
    FileLog.i(TAG, '平台检测结果: Android (ArkUI-X)');
  } catch (e) {
    isAndroidPlatform = false;
    FileLog.i(TAG, '平台检测结果: HarmonyOS');
  }
}

export class PlatformHelper {
  
  static isAndroid(): boolean {
    detectPlatform();
    return isAndroidPlatform;
  }

  
  static isHarmonyOS(): boolean {
    detectPlatform();
    return !isAndroidPlatform;
  }
}
