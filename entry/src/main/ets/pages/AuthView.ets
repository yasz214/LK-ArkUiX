import { curves, promptAction } from '@kit.ArkUI';
import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { NovelRepository } from '../repository/NovelRepository';
import { Constants } from '../common/Constants';
import { PreferenceManager } from '../utils/PreferenceManager';
import { FileLog } from '../utils/FileLog';

const TAG = 'AuthView';

@Entry
@Component
struct AuthView {
  @State isLoginMode: boolean = true;
  @State email: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State nickname: string = '';
  @State captcha: string = '';
  @State isSubmitting: boolean = false;
  @State countdown: number = 0;
  private countdownTimer: number = -1;

  aboutToAppear() {
    
    let endTime = AppStorage.get<number>('captcha_end_time') ?? 0;
    if (endTime > 0) {
      let remaining = Math.ceil((endTime - Date.now()) / 1000);
      if (remaining > 0) {
        this.countdown = remaining;
        this.startCountdownTimer();
      } else {
        
        AppStorage.setOrCreate('captcha_end_time', 0);
      }
    }
  }

  aboutToDisappear() {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  private startCountdownTimer() {
    if (this.countdownTimer !== -1) {
      clearInterval(this.countdownTimer);
    }
    this.countdownTimer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        this.countdown = 0;
        clearInterval(this.countdownTimer);
        this.countdownTimer = -1;
        AppStorage.setOrCreate('captcha_end_time', 0);
      }
    }, 1000);
  }

  async saveAndFinish(key: string) {
    FileLog.i(TAG, `====== saveAndFinish 开始, key长度=${key.length} ======`);

    if (!key || key === '') {
      FileLog.e(TAG, '致命错误：收到的 security_key 为空！');
      promptAction.openToast({ message: '登录异常：未获取到有效凭证' });
      return;
    }

    
    try {
      await PreferenceManager.putString('security_key', key);
      FileLog.i(TAG, '第1步完成：security_key 已写入磁盘');
    } catch (err) {
      let e = err as Error;
      FileLog.e(TAG, `第1步失败：写入磁盘失败 - ${e.message}`);
    }

    
    try {
      let verifyKey = await PreferenceManager.getString('security_key', '');
      FileLog.i(TAG, `磁盘验证读取长度=${verifyKey.length}, 一致=${verifyKey === key}`);
    } catch (err) {
      let e = err as Error;
      FileLog.e(TAG, `磁盘验证异常: ${e.message}`);
    }

    
    try {
      AppStorage.setOrCreate('security_key', key);
      let memKey = AppStorage.get<string>('security_key') || '';
      FileLog.i(TAG, `第3步 AppStorage 写入, 验证长度=${memKey.length}, 一致=${memKey === key}`);
      if (memKey !== key) {
        AppStorage.setOrCreate('security_key', key);
        FileLog.w(TAG, 'AppStorage 验证失败，已重试');
      }
    } catch (err) {
      let e = err as Error;
      FileLog.e(TAG, `AppStorage 写入异常: ${e.message}`);
    }

    
    try {
      let ctx = getContext(this) as common.UIAbilityContext;
      ctx.eventHub.emit('auth_state_changed', key);
      FileLog.i(TAG, '第4步完成：EventHub 事件已广播');
    } catch (err) {
      let e = err as Error;
      FileLog.e(TAG, `EventHub 广播失败: ${e.message}`);
    }

    
    promptAction.openToast({ message: this.isLoginMode ? '登录成功！' : '注册成功！' });

    
    setTimeout(() => {
      let finalCheck = AppStorage.get<string>('security_key') || '';
      FileLog.i(TAG, `返回前最终检查 AppStorage 长度=${finalCheck.length}`);
      router.back();
      FileLog.i(TAG, '====== saveAndFinish 全部完成 ======');
    }, 300);
  }

  
  private isValidEmail(): boolean {
    if (!this.email) return false;
    let atIdx = this.email.indexOf('@');
    if (atIdx <= 0) return false;
    let dotIdx = this.email.indexOf('.', atIdx);
    return dotIdx > atIdx + 1 && dotIdx < this.email.length - 1;
  }

  
  private canSubmit(): boolean {
    if (this.isSubmitting) return false;
    if (!this.isValidEmail() || !this.password) return false;
    if (!this.isLoginMode) {
      if (this.captcha.length !== 6) return false;
      if (!this.nickname) return false;
      if (this.password !== this.confirmPassword) return false;
    }
    return true;
  }

  async handleAuth() {
    if (!this.email || !this.password) {
      promptAction.openToast({ message: '请填写基本信息' });
      return;
    }
    
    if (!this.isLoginMode && this.password !== this.confirmPassword) {
      promptAction.openToast({ message: '两次输入的密码不一致' });
      return;
    }
    this.isSubmitting = true;
    FileLog.i(TAG, `handleAuth 开始, mode=${this.isLoginMode ? 'login' : 'register'}`);
    try {
      if (this.isLoginMode) {
        FileLog.i(TAG, `调用 login, email=${this.email}`);
        let user = await NovelRepository.login(this.email, this.password);
        FileLog.i(TAG, `login 返回: uid=${user.uid}, nickname=${user.nickname}`);
        FileLog.i(TAG, `login security_key长度=${(user.security_key || '').length}`);
        FileLog.i(TAG, `login 完整返回: ${JSON.stringify(user).substring(0, 500)}`);

        if (!user.security_key) {
          FileLog.e(TAG, '致命：login 返回无 security_key!');
          FileLog.e(TAG, `完整字段: ${JSON.stringify(user)}`);
          promptAction.openToast({ message: '登录返回数据异常，请查看调试日志' });
          return;
        }

        
        try {
          await PreferenceManager.putString('userInfo', JSON.stringify(user));
          AppStorage.setOrCreate('userInfo', user);
          FileLog.i(TAG, 'userInfo 已保存');
        } catch (err) {
          let e = err as Error;
          FileLog.e(TAG, `保存 userInfo 失败: ${e.message}`);
        }

        await this.saveAndFinish(user.security_key);
      } else {
        if (!this.nickname || !this.captcha) {
          promptAction.openToast({ message: '请填写完整注册信息' });
          this.isSubmitting = false;
          return;
        }
        let user = await NovelRepository.register(this.email, Number.parseInt(this.captcha), this.nickname, this.password);
        FileLog.i(TAG, `register 返回: ${JSON.stringify(user).substring(0, 500)}`);

        if (!user.security_key) {
          FileLog.e(TAG, '致命：register 返回无 security_key!');
          promptAction.openToast({ message: '注册返回数据异常' });
          return;
        }

        try {
          await PreferenceManager.putString('userInfo', JSON.stringify(user));
          AppStorage.setOrCreate('userInfo', user);
        } catch (err) {
          let e = err as Error;
          FileLog.e(TAG, `保存 userInfo 失败: ${e.message}`);
        }

        await this.saveAndFinish(user.security_key);
      }
    } catch (err) {
      let e = err as Error;
      FileLog.e(TAG, `handleAuth 异常: ${e.message}`);
      promptAction.openToast({ message: e.message || '操作失败' });
    } finally {
      this.isSubmitting = false;
    }
  }

  async sendCode() {
    if (!this.isValidEmail()) {
      promptAction.openToast({ message: '请输入正确的邮箱地址' });
      return;
    }
    if (this.countdown > 0) {
      return;
    }
    try {
      promptAction.openToast({ message: '正在获取验证码...' });
      
      let recaptchaToken = await NovelRepository.generateRecaptchaToken();
      FileLog.i(TAG, `reCAPTCHA token 长度=${recaptchaToken.length}`);
      promptAction.openToast({ message: '正在发送验证码...' });
      let msg = await NovelRepository.sendEmailCode(this.email, recaptchaToken);
      promptAction.openToast({ message: msg });

      
      this.countdown = 60;
      let endTime = Date.now() + 60 * 1000;
      AppStorage.setOrCreate('captcha_end_time', endTime);
      this.startCountdownTimer();
    } catch (err) {
      let e = err as Error;
      promptAction.openToast({ message: e.message || '发送失败' });
    }
  }

  build() {
    Column() {
      Row() {
        Text("❮").fontSize(22).fontColor(Constants.TEXT_PRIMARY).padding(16)
          .onClick(() => router.back())
      }.width('100%').height(64)

      Text(this.isLoginMode ? "欢迎回来" : "创建新账号")
        .fontSize(32).fontWeight(FontWeight.Bolder).fontColor(Constants.TEXT_PRIMARY)
        .margin({ top: 32, left: 32, bottom: 8 }).width('100%').textAlign(TextAlign.Start)
        .animation({ duration: 300, curve: curves.springMotion() })

      Text(this.isLoginMode ? "登录轻之国度，继续你的阅读之旅" : "注册账号，发现更多精彩轻小说")
        .fontSize(15).fontColor(Constants.TEXT_SECONDARY)
        .margin({ left: 32, bottom: 48 }).width('100%').textAlign(TextAlign.Start)

      Column({ space: 16 }) {
        TextInput({ placeholder: '邮箱地址', text: this.email })
          .type(InputType.Email).height(54).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
          .onChange((val) => this.email = val)

        if (!this.isLoginMode) {
          TextInput({ placeholder: '昵称', text: this.nickname })
            .height(54).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
            .onChange((val) => this.nickname = val)
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

          Row({ space: 12 }) {
            TextInput({ placeholder: '验证码（6位）', text: this.captcha })
              .type(InputType.Number).height(54).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
              .layoutWeight(1)
              .maxLength(6)
              .onChange((val) => this.captcha = val)

            Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
              .height(54).backgroundColor(this.countdown > 0 || !this.isValidEmail() ? Constants.PLACEHOLDER_BG : Constants.THEME_TINT_BG_STRONG)
              .fontColor(this.countdown > 0 || !this.isValidEmail() ? Constants.DISABLED_FG : Constants.THEME_COLOR).fontSize(14)
              .enabled(this.countdown <= 0 && this.isValidEmail())
              .onClick(() => this.sendCode())
          }
          .width('100%').transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }

        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password).height(54).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
          .onChange((val) => this.password = val)

        if (!this.isLoginMode) {
          TextInput({ placeholder: '再次输入密码', text: this.confirmPassword })
            .type(InputType.Password).height(54).backgroundColor(Constants.CARD_BG_COLOR).borderRadius(12)
            .onChange((val) => this.confirmPassword = val)
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
      }.padding({ left: 32, right: 32 }).width('100%')

      Button(this.isSubmitting ? '处理中...' : (this.isLoginMode ? '登录' : '注册'))
        .width('85%').height(54).margin({ top: 48 }).borderRadius(27)
        .backgroundColor(this.canSubmit() ? Constants.THEME_COLOR : Constants.DISABLED_BG)
        .fontSize(18).fontWeight(FontWeight.Medium)
        .enabled(this.canSubmit())
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
        .onClick(() => this.handleAuth())

      Blank()

      Row() {
        Text(this.isLoginMode ? "还没有账号？" : "已有账号？").fontSize(14).fontColor(Constants.TEXT_SECONDARY)
        Text(this.isLoginMode ? "立即注册" : "立即登录").fontSize(14).fontColor(Constants.THEME_COLOR).fontWeight(FontWeight.Bold)
          .padding(8)
          .onClick(() => {
            animateTo({ duration: 350, curve: curves.springMotion() }, () => {
              this.isLoginMode = !this.isLoginMode;
            });
          })
      }.margin({ bottom: 48 })

    }
    .width('100%').height('100%').backgroundColor(Constants.BG_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
