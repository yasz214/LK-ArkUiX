import { ConfigurationConstant } from '@kit.AbilityKit';
import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { Constants } from '../common/Constants';
import { PreferenceManager, CacheStatsData } from '../utils/PreferenceManager';
import { PreloadEngine, PreloadConfig, PreloadStats, PRELOAD_STATS_ENABLED } from '../utils/PreloadEngine';
import { SegmentButton, SegmentButtonOptions, SegmentButtonItemTuple, SegmentButtonTextItem, ItemRestriction } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { FileLog } from '../utils/FileLog';
import { WifiHelper } from '../utils/WifiHelper';
import { FontManager, FontEntry } from '../utils/FontManager';
import { NativeArticleParser } from '../utils/NativeArticleParser';
import picker from '@ohos.file.picker';

@Entry
@Component
struct Settings {
  @StorageLink('appColorMode') appColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  @StorageLink('autoSimp') autoSimp: boolean = true;
  
  @StorageLink('homeLayoutMode') homeLayoutMode: string = 'grid';
  @StorageLink('categoryLayoutMode') categoryLayoutMode: string = 'grid';
  
  @State homeLayoutOptions: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: [{ text: '网格' }, { text: '列表' }] as ItemRestriction<SegmentButtonTextItem>,
    multiply: false,
    fontColor: Constants.TEXT_SECONDARY,
    selectedFontColor: Color.White,
    selectedBackgroundColor: Constants.THEME_COLOR,
    backgroundColor: Constants.BG_COLOR
  });
  @State homeSelectedIndexes: number[] = [0];
  @State categoryLayoutOptions: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: [{ text: '网格' }, { text: '列表' }] as ItemRestriction<SegmentButtonTextItem>,
    multiply: false,
    fontColor: Constants.TEXT_SECONDARY,
    selectedFontColor: Color.White,
    selectedBackgroundColor: Constants.THEME_COLOR,
    backgroundColor: Constants.BG_COLOR
  });
  @State categorySelectedIndexes: number[] = [0];

  @State cacheSizeStr: string = '0 B';
  @State cacheStats: CacheStatsData = new CacheStatsData();
  private context: common.UIAbilityContext | null = null;

  
  @State preloadEnabled: boolean = true;
  @State preloadPreset: number = 2;
  @State preloadDepth: number = 3;  
  @State preloadMaxCacheSizeMB: number = 10;
  @State preloadWifiOnly: boolean = false;
  @State preloadStats: PreloadStats = new PreloadStats();
  
  @State presetOptions: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: [{ text: '低' }, { text: '中' }, { text: '高' }] as ItemRestriction<SegmentButtonTextItem>,
    multiply: false,
    fontColor: Constants.TEXT_SECONDARY,
    selectedFontColor: Color.White,
    selectedBackgroundColor: Constants.THEME_COLOR,
    backgroundColor: Constants.BG_COLOR
  });
  @State presetSelectedIndexes: number[] = [2];
  @State depthOptions: SegmentButtonOptions = SegmentButtonOptions.capsule({
    buttons: [{ text: '浅' }, { text: '中' }, { text: '深' }] as ItemRestriction<SegmentButtonTextItem>,
    multiply: false,
    fontColor: Constants.TEXT_SECONDARY,
    selectedFontColor: Color.White,
    selectedBackgroundColor: Constants.THEME_COLOR,
    backgroundColor: Constants.BG_COLOR
  });
  @State depthSelectedIndexes: number[] = [2];

  
  @State wifiStatus: string = '未检测';

  
  @State fontEntries: FontEntry[] = [];
  @StorageLink('custom_reading_font') customReadingFont: string = '';

  
  @State useNativeParser: boolean = true;
  @State useNativeT2S: boolean = true;
  @State nativeParserAvailable: boolean = false;

  @State developer: boolean = false;
  
  @State debugMode: boolean = false;

  aboutToAppear() {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.cacheSizeStr = PreferenceManager.getCacheSizeStr();
    this.cacheStats = PreferenceManager.getCacheStats();
    this.loadPreloadConfig();
    if (PRELOAD_STATS_ENABLED) {
      this.preloadStats = PreloadEngine.getStats();
    }
    this.refreshWifiStatus();
    this.fontEntries = FontManager.getRegisteredFonts();
    
    this.nativeParserAvailable = NativeArticleParser.isNativeAvailable();
    let savedParser = AppStorage.get<boolean>('useNativeParser');
    this.useNativeParser = savedParser !== false; 
    let savedT2S = AppStorage.get<boolean>('useNativeT2S');
    this.useNativeT2S = savedT2S !== false; 
    
    this.debugMode = PreferenceManager.getBooleanSync('debug_mode', false);
    FileLog.setEnabled(this.debugMode);
    
    this.loadLayoutModes();
  }

  async loadLayoutModes() {
    let savedHome = await PreferenceManager.getString('homeLayoutMode', '');
    if (savedHome === 'grid' || savedHome === 'list') {
      this.homeLayoutMode = savedHome;
      AppStorage.setOrCreate('homeLayoutMode', savedHome);
    }
    this.homeSelectedIndexes = [this.homeLayoutMode === 'list' ? 1 : 0];

    let savedCategory = await PreferenceManager.getString('categoryLayoutMode', '');
    if (savedCategory === 'grid' || savedCategory === 'list') {
      this.categoryLayoutMode = savedCategory;
      AppStorage.setOrCreate('categoryLayoutMode', savedCategory);
    }
    this.categorySelectedIndexes = [this.categoryLayoutMode === 'list' ? 1 : 0];
  }

  loadPreloadConfig() {
    let config = PreloadEngine.getConfig();
    this.preloadEnabled = config.enabled;
    this.preloadPreset = config.preset;
    this.preloadDepth = config.depth;
    this.preloadMaxCacheSizeMB = config.maxCacheSizeMB;
    this.preloadWifiOnly = config.wifiOnly;
    
    this.presetSelectedIndexes = [this.preloadPreset]; 
    let depthIndex = this.preloadDepth - 1; 
    if (depthIndex < 0) depthIndex = 2;
    if (depthIndex > 2) depthIndex = 2;
    this.depthSelectedIndexes = [depthIndex];
  }

  async savePreloadConfig() {
    let config = new PreloadConfig();
    config.enabled = this.preloadEnabled;
    config.preset = this.preloadPreset;
    config.depth = this.preloadDepth;
    config.maxCacheSizeMB = this.preloadMaxCacheSizeMB;
    config.wifiOnly = this.preloadWifiOnly;
    PreloadConfig.applyPreset(config);
    await PreloadEngine.saveConfig(config);
  }

  private cacheLimitLabel(): string {
    if (this.preloadMaxCacheSizeMB === 0) return '永不清理';
    return `${this.preloadMaxCacheSizeMB} MB`;
  }

  private themeLabel(): string {
    if (this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) return '浅色模式';
    if (this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) return '深色模式';
    return '跟随系统';
  }

  private fontLabel(): string {
    if (this.customReadingFont && this.customReadingFont !== '') {
      return this.customReadingFont;
    }
    return '系统默认';
  }

  private setReadingFont(familyName: string) {
    this.customReadingFont = familyName;
    AppStorage.setOrCreate('custom_reading_font', familyName);
    PreferenceManager.putString('custom_reading_font', familyName);
    FileLog.i('Settings', `阅读字体已切换为: ${familyName || '系统默认'}`);
    promptAction.openToast({ message: familyName ? `已切换为 ${familyName}` : '已恢复系统默认字体' });
  }

  private setTheme(mode: number) {
    this.appColorMode = mode;
    PreferenceManager.putNumber('appColorMode', mode);
    
    if (mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      AppStorage.setOrCreate('isActualDarkMode', true);
    } else if (mode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      AppStorage.setOrCreate('isActualDarkMode', false);
    }
    
    try {
      if (this.context) {
        this.context.getApplicationContext().setColorMode(mode);
      }
    } catch (error) {
      console.error('Failed to set color mode.');
    }
  }

  private async importFontFile() {
    if (!this.context) return;
    try {
      let documentPicker = new picker.DocumentViewPicker(this.context);
      let selectOptions = new picker.DocumentSelectOptions();
      selectOptions.fileSuffixFilters = ['.ttf', '.otf'];
      selectOptions.maxSelectNumber = 1;
      let result = await documentPicker.select(selectOptions);
      if (result && result.length > 0) {
        let uri = result[0];
        FileLog.i('Settings', `DocumentPicker 返回 URI: ${uri}`);
        
        let rawName = '';

        
        if (uri.startsWith('content://')) {
          let bridgeName = await FontManager.queryFontFileName(uri);
          if (bridgeName && bridgeName.length > 0) {
            rawName = bridgeName;
            FileLog.i('Settings', `Bridge 查询到原始文件名: ${rawName}`);
          }
        }

        
        if (!rawName) {
          let parts = uri.split('/');
          rawName = parts[parts.length - 1];
          try { rawName = decodeURIComponent(rawName); } catch (e) {  }
        }

        
        let lowerName = rawName.toLowerCase();
        if (!lowerName.endsWith('.ttf') && !lowerName.endsWith('.otf')) {
          
          rawName = `font_${Date.now()}.ttf`;
          FileLog.w('Settings', `文件名无后缀，使用默认: ${rawName}`);
        }

        promptAction.openToast({ message: '正在导入字体...' });
        let familyName = await FontManager.importUserFont(uri, rawName);
        this.fontEntries = FontManager.getRegisteredFonts();
        promptAction.openToast({ message: `字体 "${familyName}" 导入成功！` });
      }
    } catch (e) {
      let err = e as Error;
      FileLog.e('Settings', `导入字体失败: ${err.message}`);
      promptAction.openToast({ message: `导入失败: ${err.message}` });
    }
  }

  private confirmDeleteFont(familyName: string) {
    promptAction.showDialog({
      title: '删除字体',
      message: `确定删除字体 "${familyName}" 吗？如果当前正在使用该字体，将恢复为系统默认。`,
      buttons: [
        { text: '取消', color: Constants.DIALOG_CANCEL },
        { text: '删除', color: '#FF3B30' }
      ]
    }).then(data => {
      if (data.index === 1) {
        FontManager.removeUserFont(familyName).then(() => {
          this.fontEntries = FontManager.getRegisteredFonts();
          this.customReadingFont = AppStorage.get<string>('custom_reading_font') || '';
          promptAction.openToast({ message: '字体已删除' });
        });
      }
    });
  }

  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }

  private refreshWifiStatus() {
    WifiHelper.getStatusText().then((text: string) => {
      this.wifiStatus = text;
    }).catch(() => {
      this.wifiStatus = '检测失败';
    });
  }

  @Builder Header(text: string) {
    Text(text).fontSize(14).fontColor(Constants.TEXT_SECONDARY).padding({ left: 16, bottom: 8, top: 16 }).width('100%')
  }

  
  @Builder MenuRow(label: string, isSelected: boolean, action: () => void) {
    Row() {
      Text(label).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
      Blank()
      if (isSelected) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18).fontColor([Constants.THEME_COLOR]).fontWeight(FontWeight.Bold)
      }
    }
    .width('100%').padding({ top: 12, bottom: 12, left: 16, right: 16 })
    .onClick(() => action())
  }

  @Builder ThemeMenu() {
    Column() {
      this.MenuRow('跟随系统', this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET,
        () => { this.setTheme(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET); })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('浅色模式', this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT,
        () => { this.setTheme(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT); })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('深色模式', this.appColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK,
        () => { this.setTheme(ConfigurationConstant.ColorMode.COLOR_MODE_DARK); })
    }.width(180).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12).padding({ top: 4, bottom: 4 })
  }

  
  private setHomeLayout(mode: string) {
    this.homeLayoutMode = mode;
    AppStorage.setOrCreate('homeLayoutMode', mode);
    PreferenceManager.putString('homeLayoutMode', mode);
  }

  
  private setCategoryLayout(mode: string) {
    this.categoryLayoutMode = mode;
    AppStorage.setOrCreate('categoryLayoutMode', mode);
    PreferenceManager.putString('categoryLayoutMode', mode);
  }

  @Builder CacheLimitMenu() {
    Column() {
      this.MenuRow('1 MB', this.preloadMaxCacheSizeMB === 1,
        () => { this.preloadMaxCacheSizeMB = 1; this.savePreloadConfig(); })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('3 MB', this.preloadMaxCacheSizeMB === 3,
        () => { this.preloadMaxCacheSizeMB = 3; this.savePreloadConfig(); })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('5 MB', this.preloadMaxCacheSizeMB === 5,
        () => { this.preloadMaxCacheSizeMB = 5; this.savePreloadConfig(); })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('10 MB（默认）', this.preloadMaxCacheSizeMB === 10,
        () => { this.preloadMaxCacheSizeMB = 10; this.savePreloadConfig(); })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('永不清理', this.preloadMaxCacheSizeMB === 0,
        () => { this.preloadMaxCacheSizeMB = 0; this.savePreloadConfig(); })
    }.width(180).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12).padding({ top: 4, bottom: 4 })
  }

  @Builder FontMenu() {
    Column() {
      this.MenuRow('系统默认', this.customReadingFont === '',
        () => { this.setReadingFont(''); })
      ForEach(FontManager.getAvailableFontNames(), (fontName: string) => {
        Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
        this.MenuRow(fontName, this.customReadingFont === fontName,
          () => { this.setReadingFont(fontName); })
      }, (fontName: string) => `fm_${fontName}`)
    }.width(200).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12).padding({ top: 4, bottom: 4 })
  }

  @Builder ParserEngineMenu() {
    Column() {
      this.MenuRow('C++（推荐）', this.useNativeParser,
        () => {
          this.useNativeParser = true;
          AppStorage.setOrCreate('useNativeParser', true);
          PreferenceManager.putBoolean('useNativeParser', true);
          promptAction.openToast({ message: '已切换为 C++ 解析器' });
        })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('ArkTS', !this.useNativeParser,
        () => {
          this.useNativeParser = false;
          AppStorage.setOrCreate('useNativeParser', false);
          PreferenceManager.putBoolean('useNativeParser', false);
          promptAction.openToast({ message: '已切换为 ArkTS 解析器' });
        })
    }.width(200).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12).padding({ top: 4, bottom: 4 })
  }

  @Builder T2SEngineMenu() {
    Column() {
      this.MenuRow('C++（推荐）', this.useNativeT2S,
        () => {
          this.useNativeT2S = true;
          AppStorage.setOrCreate('useNativeT2S', true);
          PreferenceManager.putBoolean('useNativeT2S', true);
          promptAction.openToast({ message: '已切换为 C++ 繁简转换引擎' });
        })
      Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
      this.MenuRow('ArkTS', !this.useNativeT2S,
        () => {
          this.useNativeT2S = false;
          AppStorage.setOrCreate('useNativeT2S', false);
          PreferenceManager.putBoolean('useNativeT2S', false);
          promptAction.openToast({ message: '已切换为 ArkTS 繁简转换引擎' });
        })
    }.width(220).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12).padding({ top: 4, bottom: 4 })
  }

  
  @Builder StatCard(label: string, value: string, color: string = Constants.THEME_COLOR) {
    Column() {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(color).margin({ bottom: 4 })
      Text(label).fontSize(11).fontColor(Constants.TEXT_SECONDARY)
    }
    .layoutWeight(1).padding(12).alignItems(HorizontalAlign.Center)
    .backgroundColor(Constants.THEME_TINT_BG).borderRadius(12)
  }

  build() {
    Column() {
      
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor([Constants.TEXT_PRIMARY])
        }
        .width(44).height(44).justifyContent(FlexAlign.Center).margin({ left: 8 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => router.back())

        Text("设置").fontSize(20).fontWeight(FontWeight.Bold).fontColor(Constants.TEXT_PRIMARY)
          .layoutWeight(1).padding({ right: 52 }).textAlign(TextAlign.Center)
      }
      .width('100%').height(64).padding({ top: 20 })

      List() {
        
        ListItemGroup({ header: this.Header('外观设置') }) {
          ListItem() {
            Column() {
              Row() {
                Column() {
                  Text('外观主题').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('切换浅色、深色或跟随系统主题').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                Text(this.themeLabel())
                  .fontSize(14).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                  .margin({ right: 4 })
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([Constants.TEXT_SECONDARY])
              }
              .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
              .bindMenu(this.ThemeMenu, { placement: Placement.BottomRight })

              Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

              
              Column() {
                Text('排版模式').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                Text('首页和分区页的卡片排列方式可独立设置').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })

                
                Row() {
                  Row() {
                    SymbolGlyph($r('sys.symbol.house')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
                    Text('首页').fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
                  }.layoutWeight(1)

                  SegmentButton({
                    options: this.homeLayoutOptions,
                    selectedIndexes: $homeSelectedIndexes,
                    onItemClicked: (index: number) => {
                      this.setHomeLayout(index === 0 ? 'grid' : 'list');
                    }
                  })
                  .width(140)
                }
                .width('100%').alignItems(VerticalAlign.Center).margin({ top: 12 })

                
                Row() {
                  Row() {
                    SymbolGlyph($r('sys.symbol.square_grid_2x2')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
                    Text('分区').fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
                  }.layoutWeight(1)

                  SegmentButton({
                    options: this.categoryLayoutOptions,
                    selectedIndexes: $categorySelectedIndexes,
                    onItemClicked: (index: number) => {
                      this.setCategoryLayout(index === 0 ? 'grid' : 'list');
                    }
                  })
                  .width(140)
                }
                .width('100%').alignItems(VerticalAlign.Center).margin({ top: 8 })
              }
              .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
              .alignItems(HorizontalAlign.Start)
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
          }
        }

        
        ListItemGroup({ header: this.Header('阅读设置') }) {
          ListItem() {
            Column() {
              Row() {
                Column() {
                  Text('全局繁体转简体').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('自动将繁体中文转换为简体中文显示').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.autoSimp })
                  .selectedColor(Constants.THEME_COLOR)
                  .onChange((value) => {
                    this.autoSimp = value;
                    PreferenceManager.putBoolean('autoSimp', value);
                  })
              }
              .width('100%').padding({ top: 8, bottom: 8, left: 16, right: 16 })
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
          }
        }

        
        ListItemGroup({ header: this.Header('引擎设置') }) {
          ListItem() {
            Column() {
              
              Row() {
                Column() {
                  Text('文章解析器').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text(this.nativeParserAvailable ?
                    (this.useNativeParser ? '当前使用 C++ 引擎（更快）' : '当前使用 ArkTS 引擎（兼容性好）') :
                    'C++ 引擎不可用，使用 ArkTS 引擎')
                    .fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                if (this.nativeParserAvailable) {
                  Text(this.useNativeParser ? 'C++' : 'ArkTS')
                    .fontSize(14).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                    .margin({ right: 4 })
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([Constants.TEXT_SECONDARY])
                } else {
                  Text('ArkTS').fontSize(14).fontColor(Constants.TEXT_SECONDARY)
                }
              }
              .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
              .bindMenu(this.ParserEngineMenu, { placement: Placement.BottomRight })

              if (this.autoSimp) {
                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

                
                Row() {
                  Column() {
                    Text('繁简转换引擎').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                    Text(this.useNativeT2S ? '当前使用 C++ 引擎（更快）' : '当前使用 ArkTS 引擎（兼容性好）')
                      .fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Blank()
                  Text(this.useNativeT2S ? 'C++' : 'ArkTS')
                    .fontSize(14).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                    .margin({ right: 4 })
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([Constants.TEXT_SECONDARY])
                }
                .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
                .bindMenu(this.T2SEngineMenu, { placement: Placement.BottomRight })
              }
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
          }
        }

        
        ListItemGroup({ header: this.Header('预加载引擎') }) {
          ListItem() {
            Column() {
              Row() {
                Column() {
                  Text('智能预加载').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('提前加载文章内容，实现秒开阅读体验').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.preloadEnabled })
                  .selectedColor(Constants.THEME_COLOR)
                  .onChange((value) => {
                    this.preloadEnabled = value;
                    if (!value) { PreloadEngine.pause(); } else { PreloadEngine.resume(); }
                    this.savePreloadConfig();
                  })
              }
              .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })

              if (this.preloadEnabled) {
                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

                Row() {
                  Column() {
                    Text('仅 WiFi 下预加载').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                    Text('开启后仅在 WiFi 网络下执行预加载').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: this.preloadWifiOnly })
                    .selectedColor(Constants.THEME_COLOR)
                    .onChange((value) => {
                      this.preloadWifiOnly = value;
                      this.savePreloadConfig();
                    })
                }
                .width('100%').padding({ top: 12, bottom: 12, left: 16, right: 16 })

                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

                
                Column() {
                  Text('预加载配置').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('控制预加载的文章数量和关联内容深度').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })

                  
                  Row() {
                    Row() {
                      SymbolGlyph($r('sys.symbol.bolt_fill')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
                      Text('强度').fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
                    }.layoutWeight(1)

                    SegmentButton({
                      options: this.presetOptions,
                      selectedIndexes: $presetSelectedIndexes,
                      onItemClicked: (index: number) => {
                        this.preloadPreset = index; 
                        this.savePreloadConfig();
                      }
                    })
                    .width(160)
                  }
                  .width('100%').alignItems(VerticalAlign.Center).margin({ top: 12 })

                  
                  Row() {
                    Row() {
                      Image($r('app.media.ic_depth')).width(14).height(14)
                        .fillColor(Constants.TEXT_SECONDARY)
                      Text('深度').fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ left: 4 })
                    }.layoutWeight(1)

                    SegmentButton({
                      options: this.depthOptions,
                      selectedIndexes: $depthSelectedIndexes,
                      onItemClicked: (index: number) => {
                        this.preloadDepth = index + 1; 
                        this.savePreloadConfig();
                      }
                    })
                    .width(160)
                  }
                  .width('100%').alignItems(VerticalAlign.Center).margin({ top: 8 })
                }
                .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
                .alignItems(HorizontalAlign.Start)
              }
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
          }
        }

        
        if (PRELOAD_STATS_ENABLED && this.preloadEnabled && this.developer) {
          ListItemGroup({ header: this.Header('预加载统计（开发者）') }) {
            ListItem() {
              Column() {
                Row({ space: 10 }) {
                  this.StatCard('内存缓存', `${this.preloadStats.memCacheCount} 篇`)
                  this.StatCard('内存占用', this.formatBytes(this.preloadStats.memCacheSizeBytes))
                }.width('100%').padding({ top: 14, left: 14, right: 14 })

                Row({ space: 10 }) {
                  this.StatCard('队列等待', `${this.preloadStats.queueLength}`, '#FF8C00')
                  this.StatCard('正在加载', `${this.preloadStats.activeCount}`, '#4CAF50')
                }.width('100%').padding({ top: 10, left: 14, right: 14 })

                Row({ space: 10 }) {
                  this.StatCard('磁盘缓存', `${this.cacheStats.articleCount} 篇`)
                  this.StatCard('磁盘占用', this.cacheStats.totalSizeStr)
                }.width('100%').padding({ top: 10, left: 14, right: 14 })

                if (this.preloadStats.totalPreloaded > 0) {
                  Row() {
                    Text('本次会话已预加载 ').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                    Text(`${this.preloadStats.totalPreloaded}`).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Constants.THEME_COLOR)
                    Text(' 篇文章').fontSize(12).fontColor(Constants.TEXT_SECONDARY)
                  }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 12 })
                }

                Row({ space: 12 }) {
                  Button('刷新统计')
                    .fontSize(13).fontWeight(FontWeight.Medium)
                    .backgroundColor(Constants.THEME_TINT_BG_STRONG).fontColor(Constants.THEME_COLOR)
                    .borderRadius(20).height(36).layoutWeight(1)
                    .onClick(() => {
                      this.preloadStats = PreloadEngine.getStats();
                      this.cacheStats = PreferenceManager.getCacheStats();
                      promptAction.openToast({ message: '已刷新' });
                    })
                  Button('清空内存缓存')
                    .fontSize(13).fontWeight(FontWeight.Medium)
                    .backgroundColor('rgba(255, 59, 48, 0.08)').fontColor('#FF3B30')
                    .borderRadius(20).height(36).layoutWeight(1)
                    .onClick(() => {
                      promptAction.showDialog({
                        title: '清空内存缓存',
                        message: '将清除所有预加载的内存数据。磁盘缓存不受影响。',
                        buttons: [
                          { text: '取消', color: Constants.DIALOG_CANCEL },
                          { text: '清空', color: '#FF3B30' }
                        ]
                      }).then(data => {
                        if (data.index === 1) {
                          PreloadEngine.clearMemoryCache();
                          this.preloadStats = PreloadEngine.getStats();
                          promptAction.openToast({ message: '已清空' });
                        }
                      });
                    })
                }.width('100%').padding({ top: 14, left: 14, right: 14, bottom: 14 })
              }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
            }
          }
        }

        
        ListItemGroup({ header: this.Header('自定义字体') }) {
          ListItem() {
            Column() {
              
              Row() {
                Column() {
                  Text('阅读字体').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('更换文章正文的显示字体').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                Text(this.fontLabel())
                  .fontSize(14).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                  .margin({ right: 4 })
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([Constants.TEXT_SECONDARY])
              }
              .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
              .bindMenu(this.FontMenu, { placement: Placement.BottomRight })

              Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

              
              Row() {
                Text('导入字体文件').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                Blank()
                Text('选择 .ttf / .otf').fontSize(13).fontColor(Constants.TEXT_SECONDARY).margin({ right: 4 })
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([Constants.TEXT_SECONDARY])
              }
              .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
              .onClick(() => { this.importFontFile(); })

              
              if (this.fontEntries.length > 0) {
                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })
                Column() {
                  ForEach(this.fontEntries, (entry: FontEntry) => {
                    Row() {
                      Column() {
                        Text(entry.familyName).fontSize(14).fontColor(Constants.TEXT_PRIMARY)
                        Text('用户导入')
                          .fontSize(11).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                      
                      if (entry.registered) {
                        Text('轻之国度 — 字体预览 ABCabc 0123')
                          .fontSize(16).fontColor(Constants.TEXT_SECONDARY)
                          .fontFamily(entry.familyName)
                          .margin({ right: 8 })
                      }
                      if (!entry.registered) {
                        Row() {
                          SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                            .fontSize(18).fontColor(['#FF3B30'])
                          if (entry.error) {
                            Text(` ${entry.error}`).fontSize(10).fontColor('#FF3B30').maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: 100 })
                          }
                        }
                      }
                      Text('删除').fontSize(12).fontColor('#FF3B30').margin({ left: 4 })
                        .onClick(() => { this.confirmDeleteFont(entry.familyName); })
                    }
                    .width('100%').padding({ top: 10, bottom: 10 })
                  }, (entry: FontEntry) => `font_${entry.familyName}_${entry.registered}`)
                }
                .padding({ left: 16, right: 16, top: 4, bottom: 8 })
              }
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
          }
        }

        
        ListItemGroup({ header: this.Header('数据管理') }) {
          ListItem() {
            Column() {
              
              Row() {
                Column() {
                  Text('缓存大小限制').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('超过后自动清理最旧的文章缓存').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                Text(this.cacheLimitLabel())
                  .fontSize(14).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Medium)
                  .margin({ right: 4 })
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([Constants.TEXT_SECONDARY])
              }
              .width('100%').padding({ top: 14, bottom: 14, left: 16, right: 16 })
              .bindMenu(this.CacheLimitMenu, { placement: Placement.BottomRight })

              Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

              
              Row() {
                Text('清除缓存').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                Blank()
                Text(this.cacheSizeStr).fontSize(14).fontColor(Constants.TEXT_SECONDARY).margin({ right: 8 })
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
              }
              .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
              .onClick(() => {
                promptAction.showDialog({
                  title: '清除缓存',
                  message: '将清理所有预加载与历史缓存数据，下次打开页面可能稍慢，是否继续？',
                  buttons: [
                    { text: '取消', color: Constants.DIALOG_CANCEL },
                    { text: '清除', color: '#FF0000' }
                  ]
                }).then(data => {
                  if (data.index === 1) {
                    PreferenceManager.clearCache();
                    PreloadEngine.clearMemoryCache();
                    this.cacheSizeStr = PreferenceManager.getCacheSizeStr();
                    this.cacheStats = PreferenceManager.getCacheStats();
                    if (PRELOAD_STATS_ENABLED) {
                      this.preloadStats = PreloadEngine.getStats();
                    }
                    promptAction.openToast({ message: '缓存已成功清除' });
                  }
                });
              })
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
          }
        }

        
        ListItemGroup({ header: this.Header('调试工具') }) {
          ListItem() {
            Column() {
              
              Row() {
                Column() {
                  Text('调试模式').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Text('开启后启用日志记录并显示调试工具').fontSize(12).fontColor(Constants.TEXT_SECONDARY).margin({ top: 2 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.debugMode })
                  .selectedColor(Constants.THEME_COLOR)
                  .onChange((isOn: boolean) => {
                    this.debugMode = isOn;
                    PreferenceManager.putBoolean('debug_mode', isOn);
                    FileLog.setEnabled(isOn);
                    if (isOn) {
                      promptAction.openToast({ message: '调试模式已开启' });
                    } else {
                      promptAction.openToast({ message: '调试模式已关闭' });
                    }
                  })
              }
              .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })

              if (this.debugMode) {
                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

                Row() {
                  Text('复制调试日志到剪贴板').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Blank()
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([Constants.TEXT_SECONDARY])
                }
                .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
                .onClick(() => {
                  let logContent = FileLog.readAll();
                  if (!logContent || logContent.trim().length === 0) {
                    promptAction.openToast({ message: '暂无日志内容' });
                    return;
                  }
                  let display = logContent.length > 2000 ? '...\n' + logContent.substring(logContent.length - 2000) : logContent;
                  promptAction.showDialog({
                    title: '调试日志',
                    message: display,
                    buttons: [{ text: '关闭', color: Constants.THEME_COLOR }]
                  });
                })

                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

                Row() {
                  Text('查看日志文件路径').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Constants.TEXT_PRIMARY)
                  Blank()
                  Text(FileLog.getPath() || '未初始化').fontSize(10).fontColor(Constants.TEXT_SECONDARY)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: 160 })
                }
                .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
                .onClick(() => {
                  promptAction.showDialog({
                    title: '日志文件路径',
                    message: FileLog.getPath() || '未初始化',
                    buttons: [{ text: '关闭', color: Constants.THEME_COLOR }]
                  });
                })

                Divider().color(Constants.DIVIDER_COLOR).strokeWidth(0.5).margin({ left: 16, right: 16 })

                Row() {
                  Text('清空调试日志').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.Red)
                  Blank()
                }
                .width('100%').padding({ top: 16, bottom: 16, left: 16, right: 16 })
                .onClick(() => {
                  FileLog.clear();
                  promptAction.openToast({ message: '日志已清空' });
                })
              }
            }.borderRadius(16).clip(true).backgroundColor(Constants.CARD_BG_COLOR)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
          }
        }
      }
      .padding({ left: 16, right: 16, bottom: 40 }).width('100%').layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
