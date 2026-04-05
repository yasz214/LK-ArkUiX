export class NovelItem {
  id: number = 0;
  type: number = 0;
  title: string = '';
  action_type: number = 0;
  
  action_params?: number | string = 0;
  pic_url: string = '';
  parent_group_name?: string = '';
  hits?: number = 0;
}

export class NovelGroup {
  gid: number = 0;
  type: number = 0;
  title: string = '';
  items: NovelItem[] = [];
}

export class ArticleData {
  aid: number = 0;
  uid?: number = 0;
  title: string = '';
  summary?: string = '';
  content: string = '';
}

export class ApiResponse<T> {
  code: number = -1;
  data?: T;
  msg?: string = '';
}

export class RecaptchaData {
  action: string = '';
  token: string = '';
}


export class RequestData {
  class?: number;
  page?: number;
  pageSize?: number;
  page_size?: number;
  aid?: number;
  fid?: number;
  simple?: number;
  security_key?: string;
  email?: string;
  type?: number;
  recaptcha?: RecaptchaData; 
  username?: string;
  captcha?: number;
  nickname?: string;
  password?: string;
  q?: string;
  uid?: number;
  sid?: number;
  id?: number;            
  parent_gid?: number;    
  gid?: number;           
  content?: string;       
  act?: number;           
  pid?: number;           
  tid?: number;           
  r_rid?: number;         
  r_uid?: number;         
}


export class SearchCollection {
  sid: number = 0;
  name: string = '';
  author: string = '';
  cover: string = '';
  highlighted_name?: string = '';
}


export class SearchArticle {
  uid: number = 0;
  aid: number = 0;
  title: string = '';
  cover: string = '';
  author: string = '';
  hits: number = 0;
}


export class SearchResultData {
  collections?: SearchCollection[];
  articles?: SearchArticle[];
}


export class RichSpan {
  text: string = '';
  bold: boolean = false;
  italic: boolean = false;
  underline: boolean = false;
  lineThrough: boolean = false;
  color: string = '';      
  fontSize: number = 0;    
  linkUrl: string = '';    
}

export class ContentItem {
  type: 'text' | 'image' | 'link' = 'text';
  value: string = '';      
  url?: string = '';
  spans: RichSpan[] = [];  
}

export class CachedArticle {
  title: string = '';
  rawContent: string = '';
  parsedItems: ContentItem[] = [];
  
  simpTitle?: string = '';
  simpItems?: ContentItem[] = [];
}

export class UserInfoData {
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  security_key: string = '';
  level?: UserLevel;
  balance?: UserBalance;
}

export class UserBalance {
  coin: number = 0;
  balance: number = 0;
}

export class UserLevel {
  level: number = 0;
  name: string = '';
  exp: number = 0;
}

export class HistoryItem {
  aid: number = 0;
  title: string = '';
  cover: string = '';
  author?: string = '';
  time?: string = '';
  last_time?: string = ''; 
  sid?: number = 0;        
}

export class HistoryResponseData {
  list: HistoryItem[] = [];
}

export class SeriesInfoData {
  sid: number = 0;
  name: string = '';
  author: string = '';
  intro: string = '';
  banner: string = '';
  cover: string = '';
  cover_type: number = 0;
  rate: number = 0;
  rates: number = 0;
  hits: number = 0;
  likes: number = 0;
  score: number = 0;
  last_time: string = '';
  gid: number = 0;
  parent_gid: number = 0;
  editors: SeriesEditor[] = [];
  articles: SeriesArticle[] = [];
  
  list?: SearchArticle[];
  items?: SearchArticle[];
  data?: SearchArticle[];
}

export class SeriesEditor {
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  passer: number = 0;
}

export class SeriesArticle {
  order: number = 0;
  aid: number = 0;
  title: string = '';
  banner: string = '';
  cover: string = '';
  hits: number = 0;
  comments: number = 0;
  cover_type: number = 0;
  time: string = '';
  last_time: string = '';
}


export class TaskItemData {
  id: number = 0;
  text: string = '';
  status: number = 0;  
  coin: number = 0;
  exp: number = 0;
  type: number = 0;
  balance?: number = 0;
  pic_url?: string = '';
}

export class TaskListData {
  id: number = 0;
  text: string = '';
  status: number = 0;
  balance: number = 0;
  coin: number = 0;
  exp: number = 0;
  pic_url?: string = '';
  type: number = 0;
  items: TaskItemData[] = [];
}

export class TaskCompleteResult {
  exp: number = 0;
  coin: number = 0;
  balance: number = 0;
}


export class CheckInResult {
  success: boolean = false;
  alreadyDone: boolean = false;
  coin: number = 0;
  exp: number = 0;
  message: string = '';
}


export class GroupMainData {
  gid: number = 0;
  name: string = '';
  logo: string = '';
  cover_type: number = 0;
  items: GroupArticleItem[] = [];
  last_time: string = '';
}

export class GroupArticleItem {
  aid: number = 0;
  rank: number = 0;
  title: string = '';
  cover: string = '';
  banner: string = '';
  sid: number = 0;
  hits: number = 0;
  likes: number = 0;
  coins: number = 0;
  favorites: number = 0;
  comments: number = 0;
  shares: number = 0;
}

export class CategoryData {
  gid: number = 0;
  name: string = '';
  pic: string = '';
  last_time: string = '';
}

export class CategoryArticle {
  aid: number = 0;
  banner: string = '';
  cover: string = '';
  title: string = '';
  uid: number = 0;
  hits: number = 0;
  time: string = '';
  last_time: string = '';
  comments: number = 0;
  sid: number = 0;
  gid: number = 0;
  group_name: string = '';
  cover_type: number = 0;
  author: string = '';
  avatar: string = '';
  is_top: number = 0;
  series_name?: string = '';
}

export class CategoryArticlePageInfo {
  count: number = 0;
  size: number = 0;
  cur: number = 0;
  has_next: number = 0;
  has_prev: number = 0;
  next: number = 0;
  prev: number = 0;
}

export class CategoryArticleResponse {
  list: CategoryArticle[] = [];
  page_info: CategoryArticlePageInfo = new CategoryArticlePageInfo();
}


export class SearchTag {
  id: number = 0;
  alias: string = '';
}


export class NotifyUnreadData {
  reply: NotifyCount = new NotifyCount();
  sys_msg: NotifyCount = new NotifyCount();
  guild: NotifyCount = new NotifyCount();
}

export class NotifyCount {
  count: number = 0;
}


export class ReplyMessageItem {
  id: number = 0;
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  content: string = '';
  time: string = '';
  aid: number = 0;
  title: string = '';
}

export class SysMessageItem {
  id: number = 0;
  title: string = '';
  msg: string = '';       
  content: string = '';   
  time: string = '';
  is_read: number = 0;
}

export class GuildMessageItem {
  id: number = 0;
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  content: string = '';
  time: string = '';
}

export class ReplyMessageResponse {
  messages: ReplyMessageItem[] = [];
  list: ReplyMessageItem[] = [];  
}

export class SysMessageResponse {
  list: SysMessageItem[] = [];  
}

export class GuildMessageResponse {
  messages: GuildMessageItem[] = [];
  list: GuildMessageItem[] = [];  
}


export class RecaptchaGenerateData {
  action: string = '';
  token: string = '';
}


export class AuthorInfo {
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  passer: number = 0;
  sign: string = '';
  followers: number = 0;
  articles: number = 0;
  level: UserLevel = new UserLevel();
}

export class ArticleInteraction {
  hits: number = 0;
  likes: number = 0;
  coins: number = 0;
  favorites: number = 0;
  comments: number = 0;
  already_like: number = 0;
  already_fav: number = 0;
  already_follow: number = 0;
  already_coin: number = 0;
  author: AuthorInfo = new AuthorInfo();
  time: string = '';       
}


export class CommentUserInfo {
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  passer: number = 0;
  level: UserLevel = new UserLevel();
}

export class CommentReply {
  tid: number = 0;
  rid: number = 0;
  pid: number = 0;
  r_rid: number = 0;
  r_uid: number = 0;
  uid: number = 0;
  likes: number = 0;
  time: string = '';
  content: string = '';
  user_info: CommentUserInfo = new CommentUserInfo();
  r_user_info: CommentUserInfo | null = null; 
}

export class CommentItem {
  tid: number = 0;
  pid: number = 0;
  uid: number = 0;
  time: string = '';
  last_time: string = '';
  content: string = '';
  likes: number = 0;
  replies: number = 0;
  user_info: CommentUserInfo = new CommentUserInfo();
  reply_list: CommentReply[] = [];
}

export class CommentPageInfo {
  count: number = 0;
  size: number = 20;
  cur: number = 1;
  has_next: number = 0;
  has_prev: number = 0;
  next: number = 0;
  prev: number = 0;
}

export class CommentResponse {
  list: CommentItem[] = [];
  hots: CommentItem[] = [];
  page_info: CommentPageInfo = new CommentPageInfo();
}


export class UserProfileLevel {
  level: number = 0;
  name: string = '';
  exp: number = 0;
  next_exp: number = 0;
}

export class UserProfileLevelEntry {
  level: number = 0;
  name: string = '';
  exp: number = 0;
}

export class UserProfileData {
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  passer: number = 0;
  gender: number = 0;
  sign: string = '';
  status: number = 0;
  banner: string = '';
  ban_end_date: string = '';
  following: number = 0;
  comments: number = 0;
  favorites: number = 0;
  articles: number = 0;
  followers: number = 0;
  level: UserProfileLevel = new UserProfileLevel();
  followed: number = 0;   
  blocked: number = 0;    
  all_level: UserProfileLevelEntry[] = [];  
  balance: UserBalance = new UserBalance();  
}

export class UserArticleItem {
  aid: number = 0;
  banner: string = '';
  comments: number = 0;
  gid: number = 0;
  group_name: string = '';
  parent_gid: number = 0;
  hits: number = 0;
  time: string = '';
  title: string = '';
  uid: number = 0;
  cover: string = '';
  cover_type: number = 0;
  sid: number = 0;
  coins: number = 0;
}

export class UserArticlePageInfo {
  count: number = 0;
  size: number = 0;
  cur: number = 0;
  has_next: number = 0;
  has_prev: number = 0;
  next: number = 0;
  prev: number = 0;
}

export class UserArticleResponse {
  list: UserArticleItem[] = [];
  page_info: UserArticlePageInfo = new UserArticlePageInfo();
}


export class CommentReplyResponse {
  list: CommentReply[] = [];
  page_info: CommentPageInfo = new CommentPageInfo();
}


export class FollowedArticleAuthor {
  uid: number = 0;
  nickname: string = '';
  avatar: string = '';
  passer: number = 0;
  level: UserLevel = new UserLevel();
}

export class FollowedArticle {
  aid: number = 0;
  uid: number = 0;
  title: string = '';
  cover: string = '';
  banner: string = '';
  hits: number = 0;
  comments: number = 0;
  likes: number = 0;
  coins: number = 0;
  favorites: number = 0;
  time: string = '';
  last_time: string = '';
  sid: number = 0;
  gid: number = 0;
  group_name: string = '';
  cover_type: number = 0;
  series_name: string = '';
  author: FollowedArticleAuthor = new FollowedArticleAuthor();
}

export class FollowedArticlePageInfo {
  count: number = 0;
  size: number = 20;
  cur: number = 1;
  has_next: number = 0;
  has_prev: number = 0;
  next: number = 0;
  prev: number = 0;
}

export class FollowedArticleResponse {
  list: FollowedArticle[] = [];
  page_info: FollowedArticlePageInfo = new FollowedArticlePageInfo();
}