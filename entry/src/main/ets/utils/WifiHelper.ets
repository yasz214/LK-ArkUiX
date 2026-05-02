import bridge from '@arkui-x.bridge';
import wifiManager from '@ohos.wifiManager';
import { FileLog } from './FileLog';



const TAG = 'WifiHelper';

let bridgeObj: ESObject = null;
let hasChecked: boolean = false;
let bridgeAvailable: boolean = false;

function initBridge(): boolean {
  if (hasChecked) {
    return bridgeAvailable;
  }
  hasChecked = true;

  try {
    bridgeObj = bridge.createBridge('WifiBridge');
    bridgeAvailable = true;
    FileLog.i(TAG, 'WifiBridge 初始化成功（Android 端）');
  } catch (e) {
    let err = e as Error;
    FileLog.i(TAG, `WifiBridge 不可用，将使用 wifiManager（鸿蒙端）: ${err.message}`);
    bridgeAvailable = false;
  }
  return bridgeAvailable;
}

export class WifiHelper {
  
  static async isWifiConnected(): Promise<boolean> {
    
    if (initBridge() && bridgeObj) {
      try {
        let result: ESObject = await bridgeObj.sendMessage('check');
        let resultStr = String(result);
        FileLog.i(TAG, `Bridge 返回: ${resultStr}`);
        return resultStr === 'connected';
      } catch (e) {
        let err = e as Error;
        FileLog.w(TAG, `Bridge 调用异常: ${err.message}`);
        return false;
      }
    }

    
    try {
      let connected = wifiManager.isConnected();
      FileLog.i(TAG, `wifiManager.isConnected: ${connected}`);
      return connected;
    } catch (e) {
      FileLog.w(TAG, '鸿蒙端 WiFi 检测异常');
      return false;
    }
  }

  
  static async getStatusText(): Promise<string> {
    if (initBridge() && bridgeObj) {
      try {
        let result: ESObject = await bridgeObj.sendMessage('check');
        let resultStr = String(result);
        return resultStr === 'connected' ? ' WiFi 已连接 (Bridge)' : ' WiFi 未连接 (Bridge)';
      } catch (e) {
        return `⚠️ Bridge 异常: ${(e as Error).message || '未知'}`;
      }
    }

    try {
      let connected = wifiManager.isConnected();
      return connected ? ' WiFi 已连接 (wifiManager)' : ' WiFi 未连接 (wifiManager)';
    } catch (e) {
      return `⚠️ 检测异常: ${(e as Error).message || '未知'}`;
    }
  }

  
  static isBridgeAvailable(): boolean {
    return initBridge();
  }
}
