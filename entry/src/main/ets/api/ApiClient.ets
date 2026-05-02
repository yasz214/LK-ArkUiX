import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import { Constants } from '../common/Constants';
import { RequestData } from '../models/DataModels';
import { FileLog } from '../utils/FileLog';

const TAG = 'ApiClient';


const DEBUG_LOG_ENABLED: boolean = false;

export interface BaseBody {
  platform: string;
  client: string;
  sign: string;
  ver_name: string;
  ver_code: number;
  gz: number;
  d: RequestData;
}

const ApiClient: AxiosInstance = axios.create({
  baseURL: Constants.BASE_URL,
  timeout: 10000,
  headers: {
    'user-agent': Constants.HEADER_USER_AGENT,
    'content-type': 'application/json; charset=UTF-8',
    'accept-encoding': 'gzip',
    'host': 'api.lightnovel.fun'
  }
});


export function logApiResponse(url: string, response: AxiosResponse): void {
  if (!DEBUG_LOG_ENABLED) return;
  FileLog.i(TAG, `响应 ${url}: status=${response.status}`);
  try {
    let dataStr = JSON.stringify(response.data);
    FileLog.i(TAG, `响应数据: ${dataStr.substring(0, 800)}`);
    if (dataStr.length > 800) {
      FileLog.i(TAG, `响应数据(续): ${dataStr.substring(800, 1600)}`);
    }
  } catch (e) {
    FileLog.e(TAG, '序列化响应数据失败');
  }
}


function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve: Function) => {
    setTimeout(() => { resolve(); }, ms);
  });
}


export async function apiRequestWithRetry<T>(config: AxiosRequestConfig): Promise<AxiosResponse<T>> {
  const maxRetries = 2;
  let lastError: Error = new Error('unknown');
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await ApiClient.request<T>(config);
    } catch (e) {
      lastError = e as Error;
      if (attempt < maxRetries) {
        let backoffMs = Math.pow(2, attempt) * 1000; 
        FileLog.w(TAG, `请求失败，${backoffMs}ms 后第 ${attempt + 1} 次重试: ${lastError.message}`);
        await delay(backoffMs);
      }
    }
  }
  throw lastError;
}

export function createBaseBody(data: RequestData): BaseBody {
  
  let currentKey = AppStorage.get<string>('security_key');
  if (currentKey && currentKey !== '') {
    data.security_key = currentKey;
  }

  let body: BaseBody = {
    platform: Constants.PLATFORM,
    client: Constants.CLIENT,
    sign: "",
    ver_name: Constants.VER_NAME,
    ver_code: Constants.VER_CODE,
    gz: 0,
    d: data
  };

  return body;
}

export default ApiClient;
