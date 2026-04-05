import ApiClient, { createBaseBody, BaseBody, logApiResponse } from '../api/ApiClient';
import { ApiResponse, NovelGroup, ArticleData, SearchResultData, UserInfoData, RequestData, RecaptchaData,
  HistoryResponseData,
  HistoryItem,
  SearchArticle,
  SearchCollection,
  SeriesInfoData,
  SeriesEditor,
  SeriesArticle,
  TaskListData,
  TaskCompleteResult,
  CheckInResult,
  GroupMainData,
  CategoryData,
  CategoryArticleResponse,
  CategoryArticle,
  CategoryArticlePageInfo,
  SearchTag,
  NotifyUnreadData,
  ReplyMessageResponse,
  ReplyMessageItem,
  SysMessageResponse,
  SysMessageItem,
  GuildMessageResponse,
  GuildMessageItem,
  RecaptchaGenerateData,
  ArticleInteraction,
  AuthorInfo,
  CommentResponse,
  CommentItem,
  CommentReply,
  CommentUserInfo,
  CommentPageInfo,
  UserLevel,
  UserProfileData,
  UserProfileLevel,
  UserProfileLevelEntry,
  UserArticleResponse,
  UserArticleItem,
  UserArticlePageInfo,
  UserBalance,
  FollowedArticle,
  FollowedArticleAuthor,
  FollowedArticlePageInfo,
  FollowedArticleResponse} from '../models/DataModels';
import { AxiosResponse } from '@ohos/axios';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileLog } from '../utils/FileLog';
import { PreferenceManager } from '../utils/PreferenceManager';

const TAG = 'NovelRepo';
const DOMAIN = 0x0001;

export interface ArticleDetailResult {
  data: ArticleData;
  rawJson: string;
}

export interface MessageData {
  message: string;
}

export class NovelRepository {
  
  static async getRecommends(): Promise<NovelGroup[]> {
    let req = new RequestData();
    req.class = 0;
    req.page = 1;
    req.pageSize = 20;
    const body = createBaseBody(req);

    const response = await ApiClient.post<ApiResponse<NovelGroup[]>,
    AxiosResponse<ApiResponse<NovelGroup[]>, BaseBody>,
    BaseBody>('/api/recom/get-recommends', body);

    if (response.data.code === 0 && response.data.data) {
      return response.data.data;
    }
    throw new Error(response.data.msg || 'Failed to fetch recommends');
  }

  
  static async getArticleDetail(aid: number): Promise<ArticleDetailResult> {
    let req = new RequestData();
    req.aid = aid;
    req.simple = 0;
    
    req.uid = NovelRepository.extractUid();
    const body = createBaseBody(req);

    const response = await ApiClient.post<ApiResponse<ArticleData>,
    AxiosResponse<ApiResponse<ArticleData>, BaseBody>,
    BaseBody>('/api/article/get-detail', body);

    if (response.data.code === 0 && response.data.data) {
      const result: ArticleDetailResult = {
        data: response.data.data,
        rawJson: JSON.stringify(response.data)
      };
      return result;
    }
    throw new Error(response.data.msg || 'Failed to fetch article details');
  }

  
  static async searchNovels(keyword: string, page: number = 1): Promise<SearchResultData> {
    let req = new RequestData();
    req.q = keyword;
    req.type = 0;
    req.page = page;
    req.page_size = 20;
    
    req.uid = NovelRepository.extractUid();
    const body = createBaseBody(req);

    const response = await ApiClient.post<ApiResponse<SearchResultData>,
    AxiosResponse<ApiResponse<SearchResultData>, BaseBody>,
    BaseBody>('/api/search/search-result', body);

    if (response.data.code === 0 && response.data.data) {
      let data = response.data.data;

      
      let needReparse = false;
      if (data.articles && data.articles.length > 0) {
        let sample = data.articles[0];
        FileLog.i(TAG, `searchNovels 首条文章诊断: aid=${sample.aid}, title=${sample.title}, cover=${sample.cover}`);
        if (sample.cover === undefined || sample.title === undefined) {
          needReparse = true;
          FileLog.w(TAG, `searchNovels: 检测到 articles 属性丢失!`);
        }
      }
      if (data.collections && data.collections.length > 0) {
        let sample = data.collections[0];
        FileLog.i(TAG, `searchNovels 首条合集诊断: sid=${sample.sid}, name=${sample.name}, cover=${sample.cover}`);
        if (sample.cover === undefined || sample.name === undefined) {
          needReparse = true;
          FileLog.w(TAG, `searchNovels: 检测到 collections 属性丢失!`);
        }
      }

      if (needReparse) {
        FileLog.i(TAG, `searchNovels: 启动 JSON 手动重建...`);
        try {
          let rawStr = JSON.stringify(response.data.data);
          let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;
          let result = new SearchResultData();

          let rawArticles = rawObj['articles'] as Record<string, Object>[];
          if (rawArticles && Array.isArray(rawArticles)) {
            let rebuiltArticles: SearchArticle[] = [];
            for (let i = 0; i < rawArticles.length; i++) {
              let raw = rawArticles[i];
              let a = new SearchArticle();
              a.uid = (raw['uid'] as number) ?? 0;
              a.aid = (raw['aid'] as number) ?? 0;
              a.title = (raw['title'] as string) ?? '';
              a.cover = (raw['cover'] as string) ?? '';
              a.author = (raw['author'] as string) ?? '';
              a.hits = (raw['hits'] as number) ?? 0;
              rebuiltArticles.push(a);
            }
            result.articles = rebuiltArticles;
            FileLog.i(TAG, `searchNovels: 重建 ${rebuiltArticles.length} 篇文章`);
          }

          let rawCollections = rawObj['collections'] as Record<string, Object>[];
          if (rawCollections && Array.isArray(rawCollections)) {
            let rebuiltCollections: SearchCollection[] = [];
            for (let i = 0; i < rawCollections.length; i++) {
              let raw = rawCollections[i];
              let c = new SearchCollection();
              c.sid = (raw['sid'] as number) ?? 0;
              c.name = (raw['name'] as string) ?? '';
              c.author = (raw['author'] as string) ?? '';
              c.cover = (raw['cover'] as string) ?? '';
              c.highlighted_name = (raw['highlighted_name'] as string) ?? '';
              rebuiltCollections.push(c);
            }
            result.collections = rebuiltCollections;
            FileLog.i(TAG, `searchNovels: 重建 ${rebuiltCollections.length} 个合集`);
          }

          return result;
        } catch (parseErr) {
          FileLog.e(TAG, `searchNovels: JSON手动重建失败: ${(parseErr as Error).message}`);
        }
      }

      return data;
    }
    throw new Error(response.data.msg || 'Search failed');
  }

  
  static async sendEmailCode(email: string, recaptchaToken: string = ''): Promise<string> {
    let req = new RequestData();
    req.email = email;
    req.type = 100;
    let recap = new RecaptchaData();
    recap.action = "user/register";
    recap.token = recaptchaToken;
    req.recaptcha = recap;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    FileLog.i(TAG, `sendEmailCode body JSON: ${bodyStr.substring(0, 500)}`);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"email"') < 0) {
      FileLog.w(TAG, 'sendEmailCode: email 序列化丢失！手动补入');
      dRecord['email'] = email;
    }
    if (bodyStr.indexOf('"type"') < 0) {
      FileLog.w(TAG, 'sendEmailCode: type 序列化丢失！手动补入');
      dRecord['type'] = 100;
    }
    if (bodyStr.indexOf('"recaptcha"') < 0) {
      FileLog.w(TAG, 'sendEmailCode: recaptcha 序列化丢失！手动补入');
      let recapObj: Record<string, string> = { 'action': 'user/register', 'token': recaptchaToken };
      dRecord['recaptcha'] = recapObj;
    } else if (bodyStr.indexOf('"action"') < 0 || bodyStr.indexOf('"token"') < 0) {
      
      FileLog.w(TAG, 'sendEmailCode: recaptcha 内部属性丢失！手动重建');
      let recapObj: Record<string, string> = { 'action': 'user/register', 'token': recaptchaToken };
      dRecord['recaptcha'] = recapObj;
    }

    const response = await ApiClient.post<ApiResponse<MessageData>,
    AxiosResponse<ApiResponse<MessageData>, BaseBody>,
    BaseBody>('/api/captcha/email', body);

    if (response.data.code === 0 && response.data.data) {
      return response.data.data.message || '发送成功';
    }
    throw new Error(response.data.msg || 'Send failed');
  }

  
  static async register(email: string, code: number, nickname: string, pass: string): Promise<UserInfoData> {
    let req = new RequestData();
    req.username = email;
    req.captcha = code;
    req.nickname = nickname;
    req.password = pass;
    req.type = 2;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    FileLog.i(TAG, `register body JSON: ${bodyStr.substring(0, 500)}`);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"username"') < 0) {
      FileLog.w(TAG, 'register: username 序列化丢失！手动补入');
      dRecord['username'] = email;
    }
    if (bodyStr.indexOf('"captcha"') < 0) {
      FileLog.w(TAG, 'register: captcha 序列化丢失！手动补入');
      dRecord['captcha'] = code;
    }
    if (bodyStr.indexOf('"nickname"') < 0) {
      FileLog.w(TAG, 'register: nickname 序列化丢失！手动补入');
      dRecord['nickname'] = nickname;
    }
    if (bodyStr.indexOf('"password"') < 0) {
      FileLog.w(TAG, 'register: password 序列化丢失！手动补入');
      dRecord['password'] = pass;
    }
    if (bodyStr.indexOf('"type"') < 0) {
      dRecord['type'] = 2;
    }

    const response = await ApiClient.post<ApiResponse<UserInfoData>,
    AxiosResponse<ApiResponse<UserInfoData>, BaseBody>,
    BaseBody>('/api/user/register', body);

    if (response.data.code === 0 && response.data.data) {
      let user = response.data.data;

      
      if (!user.security_key || user.security_key === '') {
        try {
          let rawObj = JSON.parse(JSON.stringify(response.data.data)) as Record<string, Object>;
          let rawKey = rawObj['security_key'] as string;
          if (rawKey && rawKey !== '') {
            user.security_key = rawKey;
          }
        } catch (e) {}
      }
      if (!user.security_key || user.security_key === '') {
        try {
          let fullJson = JSON.stringify(response.data);
          let marker = '"security_key":"';
          let startIdx = fullJson.indexOf(marker);
          if (startIdx >= 0) {
            let valueStart = startIdx + marker.length;
            let endIdx = fullJson.indexOf('"', valueStart);
            if (endIdx > valueStart) {
              user.security_key = fullJson.substring(valueStart, endIdx);
            }
          }
        } catch (e) {}
      }

      return user;
    }
    throw new Error(response.data.msg || 'Register failed');
  }

  
  static async login(email: string, pass: string): Promise<UserInfoData> {
    let req = new RequestData();
    req.username = email;
    req.password = pass;
    const body = createBaseBody(req);

    FileLog.i(TAG, `发起登录请求: email=${email}`);
    const response = await ApiClient.post<ApiResponse<UserInfoData>,
    AxiosResponse<ApiResponse<UserInfoData>, BaseBody>,
    BaseBody>('/api/user/login', body);

    logApiResponse('/api/user/login', response);
    FileLog.i(TAG, `login 响应 code=${response.data.code}`);

    if (response.data.code === 0 && response.data.data) {
      let user = response.data.data;

      
      
      if (!user.security_key || user.security_key === '') {
        try {
          let rawStr = JSON.stringify(response.data.data);
          let rawObj = JSON.parse(rawStr) as Record<string, Object>;
          let rawKey = rawObj['security_key'] as string;
          if (rawKey && rawKey !== '') {
            user.security_key = rawKey;
            FileLog.i(TAG, `login: 从 JSON.parse 兜底提取 security_key 成功, 长度=${rawKey.length}`);
          }
        } catch (e) {
          FileLog.e(TAG, 'login: JSON.parse 兜底提取失败');
        }
      }

      
      if (!user.security_key || user.security_key === '') {
        try {
          let fullJson = JSON.stringify(response.data);
          let marker = '"security_key":"';
          let startIdx = fullJson.indexOf(marker);
          if (startIdx >= 0) {
            let valueStart = startIdx + marker.length;
            let endIdx = fullJson.indexOf('"', valueStart);
            if (endIdx > valueStart) {
              let extracted = fullJson.substring(valueStart, endIdx);
              user.security_key = extracted;
              FileLog.i(TAG, `login: 从字符串截取兜底提取 security_key 成功, 长度=${extracted.length}`);
            }
          }
        } catch (e) {
          FileLog.e(TAG, 'login: 字符串截取兜底提取失败');
        }
      }

      FileLog.i(TAG, `login 最终 security_key 长度=${(user.security_key || '').length}`);
      return user;
    }
    throw new Error(response.data.msg || 'Login failed');
  }

  
  private static extractUid(): number | undefined {
    let key = AppStorage.get<string>('security_key') || '';
    let parts = key.split(':');
    if (parts.length >= 2) {
      return parseInt(parts[1]);
    }
    return undefined;
  }

  
  static async getUserInfo(): Promise<UserInfoData> {
    let req = new RequestData();
    req.uid = NovelRepository.extractUid();
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<UserInfoData>,
    AxiosResponse<ApiResponse<UserInfoData>, BaseBody>,
    BaseBody
    >('/api/user/info', body);

    if (response.data.code === 0 && response.data.data) {
      return response.data.data;
    }
    throw new Error(response.data.msg || 'Failed to fetch user info');
  }

  
  static async getHistory(page: number = 1): Promise<HistoryItem[]> {
    let req = new RequestData();
    req.uid = NovelRepository.extractUid();
    req.page = page;
    req.type = 1; 
    req.class = 1;
    req.page_size = 20;
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<HistoryResponseData>,
    AxiosResponse<ApiResponse<HistoryResponseData>, BaseBody>,
    BaseBody
    >('/api/history/get-history', body);

    if (response.data.code === 0 && response.data.data) {
      return response.data.data.list || [];
    }
    return [];
  }

  
  static async getCollections(page: number = 1): Promise<HistoryItem[]> {
    let req = new RequestData();
    req.uid = NovelRepository.extractUid();
    req.page = page;
    req.type = 1; 
    req.class = 1;
    req.page_size = 20;
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<HistoryResponseData>,
    AxiosResponse<ApiResponse<HistoryResponseData>, BaseBody>,
    BaseBody
    >('/api/history/get-collections', body);

    if (response.data.code === 0 && response.data.data) {
      return response.data.data.list || [];
    }
    return [];
  }

  
  static async getSeriesDetail(sid: number, page: number = 1): Promise<SeriesInfoData> {
    let req = new RequestData();
    req.uid = NovelRepository.extractUid();
    req.sid = sid;
    req.page = page;
    req.page_size = 50;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"sid"') < 0) dRecord['sid'] = sid;

    const response = await ApiClient.post<
    ApiResponse<SeriesInfoData>,
    AxiosResponse<ApiResponse<SeriesInfoData>, BaseBody>,
    BaseBody
    >('/api/series/get-info', body);

    if (response.data.code === 0 && response.data.data) {
      let rawStr = JSON.stringify(response.data.data);
      let raw: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;

      
      let info = new SeriesInfoData();
      info.sid = (raw['sid'] as number) ?? 0;
      info.name = (raw['name'] as string) ?? '';
      info.author = (raw['author'] as string) ?? '';
      info.intro = (raw['intro'] as string) ?? '';
      info.banner = (raw['banner'] as string) ?? '';
      info.cover = (raw['cover'] as string) ?? '';
      info.cover_type = (raw['cover_type'] as number) ?? 0;
      info.rate = (raw['rate'] as number) ?? 0;
      info.rates = (raw['rates'] as number) ?? 0;
      info.hits = (raw['hits'] as number) ?? 0;
      info.likes = (raw['likes'] as number) ?? 0;
      info.score = (raw['score'] as number) ?? 0;
      info.last_time = (raw['last_time'] as string) ?? '';
      info.gid = (raw['gid'] as number) ?? 0;
      info.parent_gid = (raw['parent_gid'] as number) ?? 0;

      
      let rawEditors = raw['editors'] as Record<string, Object>[];
      if (rawEditors && Array.isArray(rawEditors)) {
        for (let re of rawEditors) {
          let editor = new SeriesEditor();
          editor.uid = (re['uid'] as number) ?? 0;
          editor.nickname = (re['nickname'] as string) ?? '';
          editor.avatar = (re['avatar'] as string) ?? '';
          editor.passer = (re['passer'] as number) ?? 0;
          info.editors.push(editor);
        }
      }

      
      let rawArticles = raw['articles'] as Record<string, Object>[];
      if (rawArticles && Array.isArray(rawArticles)) {
        for (let ra of rawArticles) {
          let article = new SeriesArticle();
          article.order = (ra['order'] as number) ?? 0;
          article.aid = (ra['aid'] as number) ?? 0;
          article.title = (ra['title'] as string) ?? '';
          article.banner = (ra['banner'] as string) ?? '';
          article.cover = (ra['cover'] as string) ?? '';
          article.hits = (ra['hits'] as number) ?? 0;
          article.comments = (ra['comments'] as number) ?? 0;
          article.cover_type = (ra['cover_type'] as number) ?? 0;
          article.time = (ra['time'] as string) ?? '';
          article.last_time = (ra['last_time'] as string) ?? '';
          info.articles.push(article);
        }
      }

      FileLog.i(TAG, `getSeriesDetail: sid=${sid}, name=${info.name}, author=${info.author}, articles=${info.articles.length}, editors=${info.editors.length}`);
      return info;
    } else {
      FileLog.w(TAG, `getSeriesDetail: code=${response.data.code}, msg=${response.data.msg || ''}`);
    }
    return new SeriesInfoData();
  }
  
  static async addHistory(aid: number): Promise<void> {
    
    let key = AppStorage.get<string>('security_key');
    if (!key) return;

    let req = new RequestData();
    
    req.fid = aid;   
    req.class = 1;   
    

    let body = createBaseBody(req);

    body.gz = 1;

    try {
      let response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/history/add-history', body);

      if (response.data.code !== 0) {
        hilog.error(DOMAIN, TAG, '阅读历史同步后端拒绝: %{public}s', response.data.msg || '');
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '阅读历史同步网络异常');
    }
  }

  

  
  static async getTaskList(): Promise<TaskListData | null> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return null;

    let req = new RequestData();
    const body = createBaseBody(req);

    try {
      const response = await ApiClient.post<
      ApiResponse<TaskListData>,
      AxiosResponse<ApiResponse<TaskListData>, BaseBody>,
      BaseBody
      >('/api/task/list', body);

      if (response.data.code === 0 && response.data.data) {
        return response.data.data;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '获取任务列表失败');
    }
    return null;
  }

  
  static async completeTask(taskId: number): Promise<TaskCompleteResult | null> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return null;

    let req = new RequestData();
    req.id = taskId;
    const body = createBaseBody(req);

    try {
      const response = await ApiClient.post<
      ApiResponse<TaskCompleteResult>,
      AxiosResponse<ApiResponse<TaskCompleteResult>, BaseBody>,
      BaseBody
      >('/api/task/complete', body);

      if (response.data.code === 0 && response.data.data) {
        let result = response.data.data;
        
        if (result.coin === undefined || result.exp === undefined) {
          try {
            let rawStr = JSON.stringify(response.data);
            hilog.info(DOMAIN, TAG, '[签到] 原始响应: %{public}s', rawStr);
            let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;
            let rawData = rawObj['data'] as Record<string, number>;
            if (rawData) {
              if (result.coin === undefined || result.coin === 0) {
                result.coin = rawData['coin'] ?? 0;
              }
              if (result.exp === undefined || result.exp === 0) {
                result.exp = rawData['exp'] ?? 0;
              }
              if (result.balance === undefined || result.balance === 0) {
                result.balance = rawData['balance'] ?? 0;
              }
            }
          } catch (parseErr) {
            hilog.error(DOMAIN, TAG, '[签到] Android JSON兜底解析失败');
          }
        }
        return result;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '完成任务 %{public}d 失败', taskId);
    }
    return null;
  }

  
  static async dailyCheckIn(): Promise<CheckInResult> {
    let res = new CheckInResult();
    let key = AppStorage.get<string>('security_key');
    if (!key) {
      res.message = '未登录，跳过签到';
      return res;
    }

    
    let today = new Date();
    let todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;

    try {
      let lastCheckIn = await PreferenceManager.getString('last_checkin_date', '');
      if (lastCheckIn === todayStr) {
        hilog.info(DOMAIN, TAG, '[签到] 今日已签到（磁盘记录），跳过');
        res.alreadyDone = true;
        res.message = '今日已签到';
        return res;
      }
    } catch (e) {}

    try {
      
      let taskList = await NovelRepository.getTaskList();
      if (taskList) {
        
        if (taskList.items && taskList.items.length > 0) {
          for (let i = 0; i < taskList.items.length; i++) {
            let item = taskList.items[i];
            if (item.id === 8 && item.status === 1) {
              
              await PreferenceManager.putString('last_checkin_date', todayStr);
              hilog.info(DOMAIN, TAG, '[签到] 服务端确认今日已签到，跳过');
              res.alreadyDone = true;
              res.message = '今日已签到';
              return res;
            }
          }
        }
        
        if (taskList.id === 8 && taskList.status === 1) {
          await PreferenceManager.putString('last_checkin_date', todayStr);
          hilog.info(DOMAIN, TAG, '[签到] 服务端确认今日已签到(顶层)，跳过');
          res.alreadyDone = true;
          res.message = '今日已签到';
          return res;
        }
      }

      
      let result = await NovelRepository.completeTask(8);
      if (result && (result.coin > 0 || result.exp > 0)) {
        
        await PreferenceManager.putString('last_checkin_date', todayStr);
        res.success = true;
        res.coin = result.coin;
        res.exp = result.exp;
        res.message = `签到成功！获得 ${result.coin} 铜币, ${result.exp} 经验`;
        hilog.info(DOMAIN, TAG, '[签到] %{public}s', res.message);
        return res;
      } else {
        
        await PreferenceManager.putString('last_checkin_date', todayStr);
        hilog.info(DOMAIN, TAG, '[签到] 接口返回无奖励，可能已签到');
        res.alreadyDone = true;
        res.message = '今日已签到';
        return res;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '[签到] 签到异常');
      res.message = '签到出错';
      return res;
    }
  }

  

  
  static async getGroupMain(): Promise<GroupMainData[]> {
    let req = new RequestData();
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<GroupMainData[]>,
    AxiosResponse<ApiResponse<GroupMainData[]>, BaseBody>,
    BaseBody
    >('/api/group/main', body);

    if (response.data.code === 0 && response.data.data) {
      let data = response.data.data;

      
      if (data.length > 0) {
        let sample = data[0];
        FileLog.i(TAG, `getGroupMain 首个分组诊断: gid=${sample.gid}, name=${sample.name}, logo=${sample.logo}, cover_type=${sample.cover_type}`);
        if (sample.name === undefined || sample.gid === undefined) {
          FileLog.w(TAG, `getGroupMain: 检测到属性丢失! 启动 JSON 手动重建...`);
          try {
            let rawStr = JSON.stringify(response.data.data);
            FileLog.i(TAG, `getGroupMain raw JSON(前500字): ${rawStr.substring(0, 500)}`);
            let rawArr: Record<string, Object>[] = JSON.parse(rawStr) as Record<string, Object>[];
            let rebuiltList: GroupMainData[] = [];
            for (let i = 0; i < rawArr.length; i++) {
              let raw = rawArr[i];
              let g = new GroupMainData();
              g.gid = (raw['gid'] as number) ?? 0;
              g.name = (raw['name'] as string) ?? '';
              g.logo = (raw['logo'] as string) ?? '';
              g.cover_type = (raw['cover_type'] as number) ?? 0;
              g.last_time = (raw['last_time'] as string) ?? '';
              
              rebuiltList.push(g);
            }
            FileLog.i(TAG, `getGroupMain: 手动重建成功, ${rebuiltList.length} 个分组`);
            return rebuiltList;
          } catch (parseErr) {
            FileLog.e(TAG, `getGroupMain: JSON手动重建失败: ${(parseErr as Error).message}`);
          }
        }
      }

      return data;
    }
    throw new Error(response.data.msg || '获取分区失败');
  }

  
  static async getCategories(parentGid: number): Promise<CategoryData[]> {
    let req = new RequestData();
    req.parent_gid = parentGid;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    FileLog.i(TAG, `getCategories body JSON: ${bodyStr.substring(0, 500)}`);
    if (bodyStr.indexOf('parent_gid') < 0) {
      FileLog.w(TAG, 'parent_gid 序列化丢失！手动补入');
      (body.d as Record<string, string | number | Object>)['parent_gid'] = parentGid;
      FileLog.i(TAG, `补入后 body JSON: ${JSON.stringify(body).substring(0, 500)}`);
    }

    FileLog.i(TAG, `getCategories 请求: parent_gid=${parentGid}, security_key长度=${(body.d.security_key || '').length}`);

    const response = await ApiClient.post<
    ApiResponse<CategoryData[]>,
    AxiosResponse<ApiResponse<CategoryData[]>, BaseBody>,
    BaseBody
    >('/api/category/get-categories', body);

    FileLog.i(TAG, `getCategories 响应: code=${response.data.code}, msg=${response.data.msg || ''}, data类型=${typeof response.data.data}, data=${JSON.stringify(response.data.data).substring(0, 300)}`);

    if (response.data.code === 0 && response.data.data) {
      
      let rawData = response.data.data;
      let dataArray: CategoryData[] = [];

      if (Array.isArray(rawData)) {
        dataArray = rawData;
      } else {
        
        try {
          let rawStr = JSON.stringify(response.data.data);
          let reparsed: Object = JSON.parse(rawStr);
          if (Array.isArray(reparsed)) {
            dataArray = reparsed as CategoryData[];
          }
        } catch (e) {}
        if (dataArray.length === 0) {
          FileLog.w(TAG, `getCategories: data 不是数组，返回空`);
          return [];
        }
      }

      
      if (dataArray.length > 0) {
        let sample = dataArray[0];
        FileLog.i(TAG, `getCategories 首个分类诊断: gid=${sample.gid}, name=${sample.name}`);
        if (sample.name === undefined || sample.gid === undefined) {
          FileLog.w(TAG, `getCategories: 检测到属性丢失! 启动手动重建...`);
          try {
            let rawStr = JSON.stringify(rawData);
            let rawArr: Record<string, Object>[] = JSON.parse(rawStr) as Record<string, Object>[];
            let rebuiltList: CategoryData[] = [];
            for (let i = 0; i < rawArr.length; i++) {
              let raw = rawArr[i];
              let c = new CategoryData();
              c.gid = (raw['gid'] as number) ?? 0;
              c.name = (raw['name'] as string) ?? '';
              c.pic = (raw['pic'] as string) ?? '';
              c.last_time = (raw['last_time'] as string) ?? '';
              rebuiltList.push(c);
            }
            FileLog.i(TAG, `getCategories: 手动重建成功, ${rebuiltList.length} 个分类`);
            return rebuiltList;
          } catch (parseErr) {
            FileLog.e(TAG, `getCategories: JSON手动重建失败`);
          }
        }
      }

      return dataArray;
    }
    throw new Error(response.data.msg || '获取分类失败');
  }

  
  static async getArticlesByCategory(parentGid: number, gid: number, page: number = 1, pageSize: number = 40): Promise<CategoryArticleResponse> {
    let req = new RequestData();
    req.parent_gid = parentGid;
    req.gid = gid;
    req.page = page;
    req.pageSize = pageSize;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    FileLog.i(TAG, `getArticlesByCategory body JSON: ${bodyStr.substring(0, 500)}`);
    if (bodyStr.indexOf('parent_gid') < 0 || bodyStr.indexOf('"gid"') < 0) {
      FileLog.w(TAG, 'parent_gid 或 gid 序列化丢失！手动补入');
      let d = body.d as Record<string, string | number | Object>;
      d['parent_gid'] = parentGid;
      d['gid'] = gid;
    }

    FileLog.i(TAG, `getArticlesByCategory 请求: parent_gid=${parentGid}, gid=${gid}, page=${page}`);

    const response = await ApiClient.post<
    ApiResponse<CategoryArticleResponse>,
    AxiosResponse<ApiResponse<CategoryArticleResponse>, BaseBody>,
    BaseBody
    >('/api/category/get-article-by-cate', body);

    FileLog.i(TAG, `getArticlesByCategory 响应: code=${response.data.code}`);

    if (response.data.code === 0 && response.data.data) {
      let data = response.data.data;

      
      
      let needReparse = false;
      if (data.list && data.list.length > 0) {
        let sample = data.list[0];
        FileLog.i(TAG, `getArticlesByCategory 首条文章诊断: aid=${sample.aid}, title=${sample.title}, cover=${sample.cover}, banner=${sample.banner}, cover_type=${sample.cover_type}, avatar=${sample.avatar}, author=${sample.author}, hits=${sample.hits}`);
        
        if (sample.cover === undefined || sample.title === undefined || sample.cover_type === undefined) {
          needReparse = true;
          FileLog.w(TAG, `getArticlesByCategory: 检测到属性丢失! cover=${sample.cover}, title=${sample.title}, cover_type=${sample.cover_type}`);
        }
      } else {
        FileLog.i(TAG, `getArticlesByCategory: list为空或不存在, data keys=${Object.keys(data)}`);
        
        if (!data.list || !Array.isArray(data.list)) {
          needReparse = true;
          FileLog.w(TAG, `getArticlesByCategory: data.list 不存在或不是数组!`);
        }
      }

      if (needReparse) {
        FileLog.i(TAG, `getArticlesByCategory: 启动 JSON 手动重建...`);
        try {
          let rawStr = JSON.stringify(response.data.data);
          FileLog.i(TAG, `getArticlesByCategory raw JSON(前500字): ${rawStr.substring(0, 500)}`);
          let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;
          let rawList = rawObj['list'] as Record<string, Object>[];
          let rawPageInfo = rawObj['page_info'] as Record<string, number>;

          let result = new CategoryArticleResponse();

          if (rawList && Array.isArray(rawList)) {
            let rebuiltList: CategoryArticle[] = [];
            for (let i = 0; i < rawList.length; i++) {
              let raw = rawList[i];
              let article = new CategoryArticle();
              article.aid = (raw['aid'] as number) ?? 0;
              article.banner = (raw['banner'] as string) ?? '';
              article.cover = (raw['cover'] as string) ?? '';
              article.title = (raw['title'] as string) ?? '';
              article.uid = (raw['uid'] as number) ?? 0;
              article.hits = (raw['hits'] as number) ?? 0;
              article.time = (raw['time'] as string) ?? '';
              article.last_time = (raw['last_time'] as string) ?? '';
              article.comments = (raw['comments'] as number) ?? 0;
              article.sid = (raw['sid'] as number) ?? 0;
              article.gid = (raw['gid'] as number) ?? 0;
              article.group_name = (raw['group_name'] as string) ?? '';
              article.cover_type = (raw['cover_type'] as number) ?? 0;
              article.author = (raw['author'] as string) ?? '';
              article.avatar = (raw['avatar'] as string) ?? '';
              article.is_top = (raw['is_top'] as number) ?? 0;
              article.series_name = (raw['series_name'] as string) ?? '';
              rebuiltList.push(article);
            }
            result.list = rebuiltList;
            FileLog.i(TAG, `getArticlesByCategory: 手动重建成功, ${rebuiltList.length} 篇文章`);

            if (rebuiltList.length > 0) {
              let s = rebuiltList[0];
              FileLog.i(TAG, `getArticlesByCategory 重建后首条: aid=${s.aid}, title=${s.title}, cover=${s.cover}, banner=${s.banner}, cover_type=${s.cover_type}`);
            }
          }

          if (rawPageInfo) {
            let pi = new CategoryArticlePageInfo();
            pi.count = rawPageInfo['count'] ?? 0;
            pi.size = rawPageInfo['size'] ?? 0;
            pi.cur = rawPageInfo['cur'] ?? 0;
            pi.has_next = rawPageInfo['has_next'] ?? 0;
            pi.has_prev = rawPageInfo['has_prev'] ?? 0;
            pi.next = rawPageInfo['next'] ?? 0;
            pi.prev = rawPageInfo['prev'] ?? 0;
            result.page_info = pi;
          }

          return result;
        } catch (parseErr) {
          FileLog.e(TAG, `getArticlesByCategory: JSON手动重建失败: ${(parseErr as Error).message}`);
        }
      }

      
      if (data.page_info) {
        FileLog.i(TAG, `getArticlesByCategory page_info: count=${data.page_info.count}, has_next=${data.page_info.has_next}, next=${data.page_info.next}`);
      }
      return data;
    }
    throw new Error(response.data.msg || '获取文章列表失败');
  }

  

  
  static async getSearchTags(): Promise<SearchTag[]> {
    let req = new RequestData();
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<SearchTag[]>,
    AxiosResponse<ApiResponse<SearchTag[]>, BaseBody>,
    BaseBody
    >('/api/search/get-search-tags', body);

    if (response.data.code === 0 && response.data.data) {
      return response.data.data;
    }
    return [];
  }

  

  
  static async getNotifyUnread(): Promise<NotifyUnreadData | null> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return null;

    let req = new RequestData();
    const body = createBaseBody(req);

    try {
      const response = await ApiClient.post<
      ApiResponse<NotifyUnreadData>,
      AxiosResponse<ApiResponse<NotifyUnreadData>, BaseBody>,
      BaseBody
      >('/api/notify/unread', body);

      if (response.data.code === 0 && response.data.data) {
        return response.data.data;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '获取未读通知失败');
    }
    return null;
  }

  
  static async getReplyMessages(page: number = 1): Promise<ReplyMessageResponse> {
    let req = new RequestData();
    req.page = page;
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<ReplyMessageResponse>,
    AxiosResponse<ApiResponse<ReplyMessageResponse>, BaseBody>,
    BaseBody
    >('/api/msg/get-reply-msg', body);

    if (response.data.code === 0 && response.data.data) {
      let data = response.data.data;
      
      
      if (data.messages && data.messages.length > 0) {
        data.list = data.messages;
      } else if (!data.list || data.list.length === 0) {
        
        try {
          let rawStr = JSON.stringify(response.data.data);
          let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;
          let rawMessages = rawObj['messages'] as Record<string, Object>[];
          if (rawMessages && Array.isArray(rawMessages) && rawMessages.length > 0) {
            let rebuiltList: ReplyMessageItem[] = [];
            for (let i = 0; i < rawMessages.length; i++) {
              let raw = rawMessages[i];
              let item = new ReplyMessageItem();
              item.id = (raw['id'] as number) ?? 0;
              item.uid = (raw['uid'] as number) ?? 0;
              item.nickname = (raw['nickname'] as string) ?? '';
              item.avatar = (raw['avatar'] as string) ?? '';
              item.content = (raw['content'] as string) ?? '';
              item.time = (raw['time'] as string) ?? '';
              item.aid = (raw['aid'] as number) ?? 0;
              item.title = (raw['title'] as string) ?? '';
              rebuiltList.push(item);
            }
            data.list = rebuiltList;
            FileLog.i(TAG, `getReplyMessages: 从 messages 手动重建 ${rebuiltList.length} 条`);
          }
        } catch (e) {
          FileLog.e(TAG, `getReplyMessages: JSON手动重建失败`);
        }
      }
      return data;
    }
    return new ReplyMessageResponse();
  }

  
  static async getSysMessages(page: number = 1): Promise<SysMessageResponse> {
    let req = new RequestData();
    req.page = page;
    req.pageSize = 20;
    const body = createBaseBody(req);

    
    const response = await ApiClient.post<
    ApiResponse<SysMessageItem[]>,
    AxiosResponse<ApiResponse<SysMessageItem[]>, BaseBody>,
    BaseBody
    >('/api/sys-msg/get-sys-msg', body);

    let result = new SysMessageResponse();
    if (response.data.code === 0 && response.data.data) {
      let rawArray = response.data.data;

      if (Array.isArray(rawArray) && rawArray.length > 0) {
        
        let rebuiltList: SysMessageItem[] = [];
        try {
          let rawStr = JSON.stringify(rawArray);
          let rawArr: Record<string, Object>[] = JSON.parse(rawStr) as Record<string, Object>[];
          for (let i = 0; i < rawArr.length; i++) {
            let raw = rawArr[i];
            let item = new SysMessageItem();
            item.id = (raw['id'] as number) ?? 0;
            item.title = (raw['title'] as string) ?? '';
            item.content = (raw['msg'] as string) ?? '';  
            item.msg = (raw['msg'] as string) ?? '';
            item.time = (raw['time'] as string) ?? '';
            item.is_read = (raw['is_read'] as number) ?? 0;
            rebuiltList.push(item);
          }
        } catch (e) {
          
          for (let i = 0; i < rawArray.length; i++) {
            let rawItem = rawArray[i];
            let item = new SysMessageItem();
            item.id = rawItem.id ?? 0;
            item.title = rawItem.title ?? '';
            item.content = rawItem.msg || rawItem.content || '';
            item.msg = rawItem.msg ?? '';
            item.time = rawItem.time ?? '';
            item.is_read = rawItem.is_read ?? 0;
            rebuiltList.push(item);
          }
        }
        result.list = rebuiltList;
        FileLog.i(TAG, `getSysMessages: 成功解析 ${rebuiltList.length} 条系统通知`);
      }
    }
    return result;
  }

  
  static async getGuildMessages(page: number = 1): Promise<GuildMessageResponse> {
    let req = new RequestData();
    req.page = page;
    const body = createBaseBody(req);

    const response = await ApiClient.post<
    ApiResponse<GuildMessageResponse>,
    AxiosResponse<ApiResponse<GuildMessageResponse>, BaseBody>,
    BaseBody
    >('/api/msg/get-guild-reply', body);

    if (response.data.code === 0 && response.data.data) {
      let data = response.data.data;
      
      if (data.messages && data.messages.length > 0) {
        data.list = data.messages;
      } else if (!data.list || data.list.length === 0) {
        
        try {
          let rawStr = JSON.stringify(response.data.data);
          let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;
          let rawMessages = rawObj['messages'] as Record<string, Object>[];
          if (rawMessages && Array.isArray(rawMessages) && rawMessages.length > 0) {
            let rebuiltList: GuildMessageItem[] = [];
            for (let i = 0; i < rawMessages.length; i++) {
              let raw = rawMessages[i];
              let item = new GuildMessageItem();
              item.id = (raw['id'] as number) ?? 0;
              item.uid = (raw['uid'] as number) ?? 0;
              item.nickname = (raw['nickname'] as string) ?? '';
              item.avatar = (raw['avatar'] as string) ?? '';
              item.content = (raw['content'] as string) ?? '';
              item.time = (raw['time'] as string) ?? '';
              rebuiltList.push(item);
            }
            data.list = rebuiltList;
            FileLog.i(TAG, `getGuildMessages: 从 messages 手动重建 ${rebuiltList.length} 条`);
          }
        } catch (e) {
          FileLog.e(TAG, `getGuildMessages: JSON手动重建失败`);
        }
      }
      return data;
    }
    return new GuildMessageResponse();
  }

  

  
  static async generateRecaptchaToken(): Promise<string> {
    let req = new RequestData();
    const body = createBaseBody(req);

    try {
      const response = await ApiClient.post<
      ApiResponse<RecaptchaGenerateData>,
      AxiosResponse<ApiResponse<RecaptchaGenerateData>, BaseBody>,
      BaseBody
      >('/api/captcha/recaptcha-generate', body);

      if (response.data.code === 0 && response.data.data) {
        let token = response.data.data.token;
        FileLog.i(TAG, `generateRecaptchaToken: token长度=${(token || '').length}`);
        if (token && token !== '') {
          return token;
        }
        
        FileLog.w(TAG, 'generateRecaptchaToken: token 为空，尝试从 JSON 手动提取');
      }
      
      try {
        let rawStr = JSON.stringify(response.data);
        let marker = '"token":"';
        let startIdx = rawStr.indexOf(marker);
        if (startIdx >= 0) {
          let valueStart = startIdx + marker.length;
          let endIdx = rawStr.indexOf('"', valueStart);
          if (endIdx > valueStart) {
            return rawStr.substring(valueStart, endIdx);
          }
        }
      } catch (e) {}
    } catch (e) {
      hilog.error(DOMAIN, TAG, '生成 reCAPTCHA token 失败');
    }
    return '';
  }

  

  
  static async getArticleInteraction(aid: number): Promise<ArticleInteraction | null> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return null;

    let req = new RequestData();
    req.aid = aid;
    req.uid = NovelRepository.extractUid();
    const body = createBaseBody(req);

    try {
      const response = await ApiClient.post<
      ApiResponse<ArticleInteraction>,
      AxiosResponse<ApiResponse<ArticleInteraction>, BaseBody>,
      BaseBody
      >('/api/article/get-detail', body);

      if (response.data.code === 0 && response.data.data) {
        let rawStr = JSON.stringify(response.data.data);
        let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;

        let interaction = new ArticleInteraction();
        interaction.hits = (rawObj['hits'] as number) ?? 0;
        interaction.likes = (rawObj['likes'] as number) ?? 0;
        interaction.coins = (rawObj['coins'] as number) ?? 0;
        interaction.favorites = (rawObj['favorites'] as number) ?? 0;
        interaction.comments = (rawObj['comments'] as number) ?? 0;
        interaction.already_like = (rawObj['already_like'] as number) ?? 0;
        interaction.already_fav = (rawObj['already_fav'] as number) ?? 0;
        interaction.already_follow = (rawObj['already_follow'] as number) ?? 0;
        interaction.already_coin = (rawObj['already_coin'] as number) ?? 0;

        
        let rawAuthor = rawObj['author'] as Record<string, Object>;
        if (rawAuthor) {
          let author = new AuthorInfo();
          author.uid = (rawAuthor['uid'] as number) ?? 0;
          author.nickname = (rawAuthor['nickname'] as string) ?? '';
          author.avatar = (rawAuthor['avatar'] as string) ?? '';
          author.passer = (rawAuthor['passer'] as number) ?? 0;
          author.sign = (rawAuthor['sign'] as string) ?? '';
          author.followers = (rawAuthor['followers'] as number) ?? 0;
          author.articles = (rawAuthor['articles'] as number) ?? 0;
          
          let rawLevel = rawAuthor['level'] as Record<string, Object>;
          if (rawLevel) {
            let level = new UserLevel();
            level.level = (rawLevel['level'] as number) ?? 0;
            level.name = (rawLevel['name'] as string) ?? '';
            level.exp = (rawLevel['exp'] as number) ?? 0;
            author.level = level;
          }
          interaction.author = author;
        }

        
        interaction.time = (rawObj['time'] as string) ?? '';

        FileLog.i(TAG, `getArticleInteraction: aid=${aid}, likes=${interaction.likes}, already_like=${interaction.already_like}, already_fav=${interaction.already_fav}, author=${interaction.author.nickname}, time=${interaction.time}`);
        return interaction;
      }
    } catch (e) {
      FileLog.e(TAG, `getArticleInteraction 失败: ${(e as Error).message}`);
    }
    return null;
  }

  
  static async getComments(aid: number, page: number = 1, pageSize: number = 20): Promise<CommentResponse> {
    let req = new RequestData();
    req.aid = aid;
    req.page = page;
    req.page_size = pageSize;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    if (bodyStr.indexOf('"aid"') < 0) {
      (body.d as Record<string, string | number | Object>)['aid'] = aid;
    }

    try {
      const response = await ApiClient.post<
      ApiResponse<CommentResponse>,
      AxiosResponse<ApiResponse<CommentResponse>, BaseBody>,
      BaseBody
      >('/api/discuss/get-topic', body);

      if (response.data.code === 0 && response.data.data) {
        
        let rawStr = JSON.stringify(response.data.data);
        let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;

        let result = new CommentResponse();

        
        let rawPageInfo = rawObj['page_info'] as Record<string, number>;
        if (rawPageInfo) {
          let pi = new CommentPageInfo();
          pi.count = rawPageInfo['count'] ?? 0;
          pi.size = rawPageInfo['size'] ?? 20;
          pi.cur = rawPageInfo['cur'] ?? 1;
          pi.has_next = rawPageInfo['has_next'] ?? 0;
          pi.has_prev = rawPageInfo['has_prev'] ?? 0;
          pi.next = rawPageInfo['next'] ?? 0;
          pi.prev = rawPageInfo['prev'] ?? 0;
          result.page_info = pi;
        }

        
        let rawList = rawObj['list'] as Record<string, Object>[];
        if (rawList && Array.isArray(rawList)) {
          result.list = NovelRepository.rebuildCommentItems(rawList);
        }

        
        let rawHots = rawObj['hots'] as Record<string, Object>[];
        if (rawHots && Array.isArray(rawHots)) {
          result.hots = NovelRepository.rebuildCommentItems(rawHots);
        }

        FileLog.i(TAG, `getComments: aid=${aid}, page=${page}, total=${result.page_info.count}, list=${result.list.length}, hots=${result.hots.length}`);
        return result;
      }
    } catch (e) {
      FileLog.e(TAG, `getComments 失败: ${(e as Error).message}`);
    }
    return new CommentResponse();
  }

  
  private static rebuildCommentItems(rawArr: Record<string, Object>[]): CommentItem[] {
    let items: CommentItem[] = [];
    for (let i = 0; i < rawArr.length; i++) {
      let raw = rawArr[i];
      let item = new CommentItem();
      item.tid = (raw['tid'] as number) ?? 0;
      item.pid = (raw['pid'] as number) ?? 0;
      item.uid = (raw['uid'] as number) ?? 0;
      item.time = (raw['time'] as string) ?? '';
      item.last_time = (raw['last_time'] as string) ?? '';
      item.content = (raw['content'] as string) ?? '';
      item.likes = (raw['likes'] as number) ?? 0;
      item.replies = (raw['replies'] as number) ?? 0;

      
      let rawUser = raw['user_info'] as Record<string, Object>;
      if (rawUser) {
        let user = new CommentUserInfo();
        user.uid = (rawUser['uid'] as number) ?? 0;
        user.nickname = (rawUser['nickname'] as string) ?? '';
        user.avatar = (rawUser['avatar'] as string) ?? '';
        user.passer = (rawUser['passer'] as number) ?? 0;
        let rawLevel = rawUser['level'] as Record<string, Object>;
        if (rawLevel) {
          let level = new UserLevel();
          level.level = (rawLevel['level'] as number) ?? 0;
          level.name = (rawLevel['name'] as string) ?? '';
          level.exp = (rawLevel['exp'] as number) ?? 0;
          user.level = level;
        }
        item.user_info = user;
      }

      
      let rawReplies = raw['reply_list'] as Record<string, Object>[];
      if (rawReplies && Array.isArray(rawReplies)) {
        let replies: CommentReply[] = [];
        for (let j = 0; j < rawReplies.length; j++) {
          let rr = rawReplies[j];
          let reply = new CommentReply();
          reply.tid = (rr['tid'] as number) ?? 0;
          reply.rid = (rr['rid'] as number) ?? 0;
          reply.pid = (rr['pid'] as number) ?? 0;
          reply.r_rid = (rr['r_rid'] as number) ?? 0;
          reply.r_uid = (rr['r_uid'] as number) ?? 0;
          reply.uid = (rr['uid'] as number) ?? 0;
          reply.likes = (rr['likes'] as number) ?? 0;
          reply.time = (rr['time'] as string) ?? '';
          reply.content = (rr['content'] as string) ?? '';
          let rrUser = rr['user_info'] as Record<string, Object>;
          if (rrUser) {
            let replyUser = new CommentUserInfo();
            replyUser.uid = (rrUser['uid'] as number) ?? 0;
            replyUser.nickname = (rrUser['nickname'] as string) ?? '';
            replyUser.avatar = (rrUser['avatar'] as string) ?? '';
            replyUser.passer = (rrUser['passer'] as number) ?? 0;
            let rl = rrUser['level'] as Record<string, Object>;
            if (rl) {
              let lv = new UserLevel();
              lv.level = (rl['level'] as number) ?? 0;
              lv.name = (rl['name'] as string) ?? '';
              lv.exp = (rl['exp'] as number) ?? 0;
              replyUser.level = lv;
            }
            reply.user_info = replyUser;
          }
          
          let rrRUser = rr['r_user_info'] as Record<string, Object>;
          if (rrRUser) {
            let rUser = new CommentUserInfo();
            rUser.uid = (rrRUser['uid'] as number) ?? 0;
            rUser.nickname = (rrRUser['nickname'] as string) ?? '';
            rUser.avatar = (rrRUser['avatar'] as string) ?? '';
            rUser.passer = (rrRUser['passer'] as number) ?? 0;
            let rrLv = rrRUser['level'] as Record<string, Object>;
            if (rrLv) {
              let lv2 = new UserLevel();
              lv2.level = (rrLv['level'] as number) ?? 0;
              lv2.name = (rrLv['name'] as string) ?? '';
              lv2.exp = (rrLv['exp'] as number) ?? 0;
              rUser.level = lv2;
            }
            reply.r_user_info = rUser;
          }
          replies.push(reply);
        }
        item.reply_list = replies;
      }

      items.push(item);
    }
    return items;
  }

  
  private static rebuildCommentUserInfo(rawUser: Record<string, Object>): CommentUserInfo {
    let user = new CommentUserInfo();
    user.uid = (rawUser['uid'] as number) ?? 0;
    user.nickname = (rawUser['nickname'] as string) ?? '';
    user.avatar = (rawUser['avatar'] as string) ?? '';
    user.passer = (rawUser['passer'] as number) ?? 0;
    let rawLevel = rawUser['level'] as Record<string, Object>;
    if (rawLevel) {
      let level = new UserLevel();
      level.level = (rawLevel['level'] as number) ?? 0;
      level.name = (rawLevel['name'] as string) ?? '';
      level.exp = (rawLevel['exp'] as number) ?? 0;
      user.level = level;
    }
    return user;
  }

  
  static async postComment(aid: number, content: string): Promise<boolean> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return false;

    let req = new RequestData();
    req.aid = aid;
    req.content = content;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"content"') < 0) {
      dRecord['content'] = content;
    }
    if (bodyStr.indexOf('"aid"') < 0) {
      dRecord['aid'] = aid;
    }

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/discuss/post-topic', body);

      FileLog.i(TAG, `postComment: aid=${aid}, code=${response.data.code}, msg=${response.data.msg || ''}`);
      return response.data.code === 0;
    } catch (e) {
      FileLog.e(TAG, `postComment 失败: ${(e as Error).message}`);
    }
    return false;
  }

  
  static async toggleLike(aid: number): Promise<boolean> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return false;

    let req = new RequestData();
    req.aid = aid;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    if (bodyStr.indexOf('"aid"') < 0) {
      (body.d as Record<string, string | number | Object>)['aid'] = aid;
    }

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/article/like', body);

      FileLog.i(TAG, `toggleLike: aid=${aid}, code=${response.data.code}, msg=${response.data.msg || ''}`);
      return response.data.code === 0;
    } catch (e) {
      FileLog.e(TAG, `toggleLike 失败: ${(e as Error).message}`);
    }
    return false;
  }

  
  static async toggleFavorite(aid: number): Promise<boolean> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return false;

    let req = new RequestData();
    req.fid = aid;
    req.class = 1;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"fid"') < 0) {
      dRecord['fid'] = aid;
    }
    if (bodyStr.indexOf('"class"') < 0) {
      dRecord['class'] = 1;
    }

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/history/add-collection', body);

      FileLog.i(TAG, `toggleFavorite: aid=${aid}, code=${response.data.code}, msg=${response.data.msg || ''}`);
      return response.data.code === 0;
    } catch (e) {
      FileLog.e(TAG, `toggleFavorite 失败: ${(e as Error).message}`);
    }
    return false;
  }

  
  static async toggleFollow(uid: number, act: number): Promise<boolean> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return false;

    let req = new RequestData();
    req.uid = uid;
    req.act = act; 
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"uid"') < 0) {
      dRecord['uid'] = uid;
    }
    if (bodyStr.indexOf('"act"') < 0) {
      dRecord['act'] = act;
    }

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/user/follow', body);

      FileLog.i(TAG, `toggleFollow: uid=${uid}, act=${act}, code=${response.data.code}, msg=${response.data.msg || ''}`);
      return response.data.code === 0;
    } catch (e) {
      FileLog.e(TAG, `toggleFollow 失败: ${(e as Error).message}`);
    }
    return false;
  }

  
  static async getUserProfile(uid: number): Promise<UserProfileData> {
    let req = new RequestData();
    req.uid = uid;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    if (bodyStr.indexOf('"uid"') < 0) {
      (body.d as Record<string, string | number | Object>)['uid'] = uid;
    }

    const response = await ApiClient.post<
    ApiResponse<UserProfileData>,
    AxiosResponse<ApiResponse<UserProfileData>, BaseBody>,
    BaseBody
    >('/api/user/info', body);

    if (response.data.code === 0 && response.data.data) {
      let rawStr = JSON.stringify(response.data.data);
      let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;

      let profile = new UserProfileData();
      profile.uid = (rawObj['uid'] as number) ?? 0;
      profile.nickname = (rawObj['nickname'] as string) ?? '';
      profile.avatar = (rawObj['avatar'] as string) ?? '';
      profile.passer = (rawObj['passer'] as number) ?? 0;
      profile.gender = (rawObj['gender'] as number) ?? 0;
      profile.sign = (rawObj['sign'] as string) ?? '';
      profile.status = (rawObj['status'] as number) ?? 0;
      profile.banner = (rawObj['banner'] as string) ?? '';
      profile.ban_end_date = (rawObj['ban_end_date'] as string) ?? '';
      profile.following = (rawObj['following'] as number) ?? 0;
      profile.comments = (rawObj['comments'] as number) ?? 0;
      profile.favorites = (rawObj['favorites'] as number) ?? 0;
      profile.articles = (rawObj['articles'] as number) ?? 0;
      profile.followers = (rawObj['followers'] as number) ?? 0;
      profile.followed = (rawObj['followed'] as number) ?? 0;
      profile.blocked = (rawObj['blocked'] as number) ?? 0;

      
      let rawLevel = rawObj['level'] as Record<string, Object>;
      if (rawLevel) {
        let level = new UserProfileLevel();
        level.level = (rawLevel['level'] as number) ?? 0;
        level.name = (rawLevel['name'] as string) ?? '';
        level.exp = (rawLevel['exp'] as number) ?? 0;
        level.next_exp = (rawLevel['next_exp'] as number) ?? 0;
        profile.level = level;
      }

      
      let rawAllLevel = rawObj['all_level'] as Record<string, Object>[];
      if (rawAllLevel && Array.isArray(rawAllLevel)) {
        let entries: UserProfileLevelEntry[] = [];
        for (let item of rawAllLevel) {
          let entry = new UserProfileLevelEntry();
          entry.level = (item['level'] as number) ?? 0;
          entry.name = (item['name'] as string) ?? '';
          entry.exp = (item['exp'] as number) ?? 0;
          entries.push(entry);
        }
        profile.all_level = entries;
      }

      
      let rawBalance = rawObj['balance'] as Record<string, number>;
      if (rawBalance) {
        let balance = new UserBalance();
        balance.coin = rawBalance['coin'] ?? 0;
        balance.balance = rawBalance['balance'] ?? 0;
        profile.balance = balance;
      }

      FileLog.i(TAG, `getUserProfile: uid=${uid}, nickname=${profile.nickname}, level=${profile.level.level}`);
      return profile;
    }
    throw new Error(response.data.msg || 'Failed to fetch user profile');
  }

  
  static async getUserArticles(uid: number, page: number = 1, type: number = 0, articleClass: number = 0): Promise<UserArticleResponse> {
    let req = new RequestData();
    req.uid = uid;
    req.page = page;
    req.type = type;
    req.class = articleClass;
    req.page_size = 20;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"uid"') < 0) dRecord['uid'] = uid;
    if (bodyStr.indexOf('"type"') < 0) dRecord['type'] = type;
    if (bodyStr.indexOf('"class"') < 0) dRecord['class'] = articleClass;

    try {
      const response = await ApiClient.post<
      ApiResponse<UserArticleResponse>,
      AxiosResponse<ApiResponse<UserArticleResponse>, BaseBody>,
      BaseBody
      >('/api/user/get-articles', body);

      if (response.data.code === 0 && response.data.data) {
        let rawStr = JSON.stringify(response.data.data);
        let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;

        let result = new UserArticleResponse();

        
        let rawPageInfo = rawObj['page_info'] as Record<string, number>;
        if (rawPageInfo) {
          let pi = new UserArticlePageInfo();
          pi.count = rawPageInfo['count'] ?? 0;
          pi.size = rawPageInfo['size'] ?? 0;
          pi.cur = rawPageInfo['cur'] ?? 0;
          pi.has_next = rawPageInfo['has_next'] ?? 0;
          pi.has_prev = rawPageInfo['has_prev'] ?? 0;
          pi.next = rawPageInfo['next'] ?? 0;
          pi.prev = rawPageInfo['prev'] ?? 0;
          result.page_info = pi;
        }

        
        let rawList = rawObj['list'] as Record<string, Object>[];
        if (rawList && Array.isArray(rawList)) {
          let items: UserArticleItem[] = [];
          for (let raw of rawList) {
            let item = new UserArticleItem();
            item.aid = (raw['aid'] as number) ?? 0;
            item.banner = (raw['banner'] as string) ?? '';
            item.comments = (raw['comments'] as number) ?? 0;
            item.gid = (raw['gid'] as number) ?? 0;
            item.group_name = (raw['group_name'] as string) ?? '';
            item.parent_gid = (raw['parent_gid'] as number) ?? 0;
            item.hits = (raw['hits'] as number) ?? 0;
            item.time = (raw['time'] as string) ?? '';
            item.title = (raw['title'] as string) ?? '';
            item.uid = (raw['uid'] as number) ?? 0;
            item.cover = (raw['cover'] as string) ?? '';
            item.cover_type = (raw['cover_type'] as number) ?? 0;
            item.sid = (raw['sid'] as number) ?? 0;
            item.coins = (raw['coins'] as number) ?? 0;
            items.push(item);
          }
          result.list = items;
        }

        FileLog.i(TAG, `getUserArticles: uid=${uid}, type=${type}, count=${result.page_info.count}, loaded=${result.list.length}`);
        return result;
      }
    } catch (e) {
      FileLog.e(TAG, `getUserArticles 失败: ${(e as Error).message}`);
    }
    return new UserArticleResponse();
  }

  
  static async postReply(aid: number, tid: number, content: string, r_rid: number = 0, r_uid: number = 0): Promise<boolean> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return false;

    let req = new RequestData();
    req.aid = aid;
    req.tid = tid;
    req.r_rid = r_rid;
    req.r_uid = r_uid;
    req.content = content;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"aid"') < 0) dRecord['aid'] = aid;
    if (bodyStr.indexOf('"tid"') < 0) dRecord['tid'] = tid;
    if (bodyStr.indexOf('"r_rid"') < 0) dRecord['r_rid'] = r_rid;
    if (bodyStr.indexOf('"r_uid"') < 0) dRecord['r_uid'] = r_uid;
    if (bodyStr.indexOf('"content"') < 0) dRecord['content'] = content;

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/discuss/post-reply', body);

      FileLog.i(TAG, `postReply: aid=${aid}, tid=${tid}, r_rid=${r_rid}, code=${response.data.code}`);
      return response.data.code === 0;
    } catch (e) {
      FileLog.e(TAG, `postReply 失败: ${(e as Error).message}`);
    }
    return false;
  }

  
  
  
  
  
  static async getReplies(tid: number, page: number = 1, pageSize: number = 20): Promise<CommentReply[]> {
    let req = new RequestData();
    req.tid = tid;
    req.page = page;
    req.page_size = pageSize;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"tid"') < 0) dRecord['tid'] = tid;
    if (bodyStr.indexOf('"page"') < 0) dRecord['page'] = page;
    if (bodyStr.indexOf('"page_size"') < 0) dRecord['page_size'] = pageSize;
    dRecord['rid'] = 0;

    
    let finalBodyStr = JSON.stringify(body);
    FileLog.i(TAG, `getReplies 请求体: ${finalBodyStr.substring(0, 500)}`);

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/discuss/get-reply', body);

      
      let rawResponseStr = JSON.stringify(response.data);
      FileLog.i(TAG, `getReplies 响应: code=${response.data.code}, 响应体(前500字): ${rawResponseStr.substring(0, 500)}`);

      
      if (response.data.data) {
        let rawStr = JSON.stringify(response.data.data);
        FileLog.i(TAG, `getReplies 原始响应 (前500字): ${rawStr.substring(0, 500)}`);
        let rawObj: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>;

        
        let rawReplyList = rawObj['reply_list'] as Record<string, Object>[];
        let replies: CommentReply[] = [];

        if (rawReplyList && Array.isArray(rawReplyList)) {
          for (let raw of rawReplyList) {
            let reply = new CommentReply();
            reply.tid = (raw['tid'] as number) ?? tid;
            reply.rid = (raw['rid'] as number) ?? 0;
            reply.pid = (raw['pid'] as number) ?? 0;
            reply.r_rid = (raw['r_rid'] as number) ?? 0;
            reply.r_uid = (raw['r_uid'] as number) ?? 0;
            reply.uid = (raw['uid'] as number) ?? 0;
            reply.likes = (raw['likes'] as number) ?? 0;
            reply.time = (raw['time'] as string) ?? '';
            reply.content = (raw['content'] as string) ?? '';

            let rawUserInfo = raw['user_info'] as Record<string, Object>;
            if (rawUserInfo) {
              reply.user_info = NovelRepository.rebuildCommentUserInfo(rawUserInfo);
            }

            let rawRUserInfo = raw['r_user_info'] as Record<string, Object>;
            if (rawRUserInfo) {
              reply.r_user_info = NovelRepository.rebuildCommentUserInfo(rawRUserInfo);
            }

            replies.push(reply);
          }
        }

        FileLog.i(TAG, `getReplies: tid=${tid}, 获取到 ${replies.length} 条楼中楼回复`);
        return replies;
      } else {
        FileLog.w(TAG, `getReplies: 响应无 data 字段, code=${response.data.code}, msg=${response.data.msg || ''}`);
      }
    } catch (e) {
      FileLog.e(TAG, `getReplies 失败: ${(e as Error).message}`);
    }
    return [];
  }

  
  static async getFollowedArticles(page: number = 1, pageSize: number = 20): Promise<FollowedArticleResponse> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return new FollowedArticleResponse();

    let req = new RequestData();
    req.page = page;
    req.page_size = pageSize;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    let dRecord = body.d as Record<string, string | number | Object>;
    if (bodyStr.indexOf('"page"') < 0) dRecord['page'] = page;
    if (bodyStr.indexOf('"page_size"') < 0) dRecord['page_size'] = pageSize;

    try {
      const response = await ApiClient.post<
      ApiResponse<FollowedArticleResponse>,
      AxiosResponse<ApiResponse<FollowedArticleResponse>, BaseBody>,
      BaseBody
      >('/api/recom/get-follows', body);

      if (response.data.code === 0 && response.data.data) {
        let rawStr = JSON.stringify(response.data.data);
        let result = new FollowedArticleResponse();

        
        let rawData: Object = JSON.parse(rawStr) as Object;
        let rawArticles: Record<string, Object>[];

        if (Array.isArray(rawData)) {
          
          rawArticles = rawData as Record<string, Object>[];
          
          let pi = new FollowedArticlePageInfo();
          pi.count = rawArticles.length;
          pi.size = pageSize;
          pi.cur = page;
          pi.has_next = rawArticles.length >= pageSize ? 1 : 0;
          pi.next = rawArticles.length >= pageSize ? page + 1 : 0;
          pi.has_prev = page > 1 ? 1 : 0;
          pi.prev = page > 1 ? page - 1 : 0;
          result.page_info = pi;
        } else {
          
          let rawObj = rawData as Record<string, Object>;
          let rawPageInfo = rawObj['page_info'] as Record<string, number>;
          if (rawPageInfo) {
            let pi = new FollowedArticlePageInfo();
            pi.count = rawPageInfo['count'] ?? 0;
            pi.size = rawPageInfo['size'] ?? 20;
            pi.cur = rawPageInfo['cur'] ?? 1;
            pi.has_next = rawPageInfo['has_next'] ?? 0;
            pi.has_prev = rawPageInfo['has_prev'] ?? 0;
            pi.next = rawPageInfo['next'] ?? 0;
            pi.prev = rawPageInfo['prev'] ?? 0;
            result.page_info = pi;
          }
          rawArticles = (rawObj['list'] as Record<string, Object>[]) || [];
        }

        
        if (rawArticles && rawArticles.length > 0) {
          let rebuilt: FollowedArticle[] = [];
          for (let i = 0; i < rawArticles.length; i++) {
            let raw = rawArticles[i];
            let item = new FollowedArticle();
            item.aid = (raw['aid'] as number) ?? 0;
            item.uid = (raw['uid'] as number) ?? 0;
            item.title = (raw['title'] as string) ?? '';
            item.cover = (raw['cover'] as string) ?? '';
            item.banner = (raw['banner'] as string) ?? '';
            item.hits = (raw['hits'] as number) ?? 0;
            item.comments = (raw['comments'] as number) ?? 0;
            item.likes = (raw['likes'] as number) ?? 0;
            item.coins = (raw['coins'] as number) ?? 0;
            item.favorites = (raw['favorites'] as number) ?? 0;
            item.time = (raw['time'] as string) ?? '';
            item.last_time = (raw['last_time'] as string) ?? '';
            item.sid = (raw['sid'] as number) ?? 0;
            item.gid = (raw['gid'] as number) ?? 0;
            item.group_name = (raw['group_name'] as string) ?? '';
            item.cover_type = (raw['cover_type'] as number) ?? 0;
            item.series_name = (raw['series_name'] as string) ?? '';

            
            let rawAuthor = raw['author'] as Record<string, Object>;
            if (rawAuthor) {
              let a = new FollowedArticleAuthor();
              a.uid = (rawAuthor['uid'] as number) ?? 0;
              a.nickname = (rawAuthor['nickname'] as string) ?? '';
              a.avatar = (rawAuthor['avatar'] as string) ?? '';
              a.passer = (rawAuthor['passer'] as number) ?? 0;
              let rawLevel = rawAuthor['level'] as Record<string, Object>;
              if (rawLevel) {
                let lvl = new UserLevel();
                lvl.level = (rawLevel['level'] as number) ?? 0;
                lvl.name = (rawLevel['name'] as string) ?? '';
                lvl.exp = (rawLevel['exp'] as number) ?? 0;
                a.level = lvl;
              }
              item.author = a;
            }

            rebuilt.push(item);
          }
          result.list = rebuilt;
        }

        FileLog.i(TAG, `getFollowedArticles: page=${page}, total=${result.page_info.count}, loaded=${result.list.length}`);
        return result;
      }
    } catch (e) {
      FileLog.e(TAG, `getFollowedArticles 失败: ${(e as Error).message}`);
    }
    return new FollowedArticleResponse();
  }

  
  static async toggleCommentLike(tid: number): Promise<boolean> {
    let key = AppStorage.get<string>('security_key');
    if (!key) return false;

    let req = new RequestData();
    req.tid = tid;
    const body = createBaseBody(req);

    
    let bodyStr = JSON.stringify(body);
    if (bodyStr.indexOf('"tid"') < 0) {
      (body.d as Record<string, string | number | Object>)['tid'] = tid;
    }

    try {
      const response = await ApiClient.post<
      ApiResponse<Object>,
      AxiosResponse<ApiResponse<Object>, BaseBody>,
      BaseBody
      >('/api/discuss/like', body);

      FileLog.i(TAG, `toggleCommentLike: tid=${tid}, code=${response.data.code}, msg=${response.data.msg || ''}`);
      return response.data.code === 0;
    } catch (e) {
      FileLog.e(TAG, `toggleCommentLike 失败: ${(e as Error).message}`);
    }
    return false;
  }
}