import { TOTP, OtpError } from '@yansongda/otp';

/**
 * 消费方 smoke demo：entry 经 barrel 消费 @yansongda/otp 的 TOTP 算码能力。
 * secret 为文档公开示例值（JBSWY3DPEHPK3PXP，非真实密钥）；经 barrel 导入即自动注册默认 provider。
 * 失败场景：OtpError 按 code 分支展示，不崩溃。
 */
@Entry
@Component
struct Index {
  @State code: string = '------';
  @State remaining: number = 0;
  @State progress: number = 0;
  @State deltaText: string = '尚未校验';
  @State errorText: string = '';
  private totp: TOTP | null = null;
  private timerId: number = -1;

  aboutToAppear(): void {
    try {
      this.totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP', period: 30 });
      this.refresh();
      this.timerId = setInterval(() => {
        this.refresh();
      }, 1000);
    } catch (e) {
      const err = e as OtpError;
      this.errorText = '初始化失败: ' + err.code;
    }
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  refresh(): void {
    if (this.totp === null) {
      return;
    }
    try {
      this.code = this.totp.generate();
      this.remaining = this.totp.remaining();
      this.progress = this.totp.progress();
      this.errorText = '';
    } catch (e) {
      const err = e as OtpError;
      this.errorText = '算码失败: ' + err.code;
    }
  }

  verifyAndSync(): void {
    if (this.totp === null) {
      return;
    }
    try {
      // 演示 window 校验：对当前窗口刚生成的码做 verify（同源码恒 delta=0，
      // 说明本机时钟与码源一致）。真实场景：把用户输入/服务器下发的码传入 verify，
      // 命中后 syncClockOffset(delta) 将本机时钟向码源对齐（RFC 6238 §6）。
      const delta = this.totp.verify(this.code, { window: 1 });
      if (delta === null) {
        this.deltaText = '未命中窗口（返回 null）';
      } else {
        this.totp.syncClockOffset(delta);
        this.deltaText = '命中 delta=' + delta + '，已按码源对齐';
      }
    } catch (e) {
      const err = e as OtpError;
      this.errorText = '校验失败: ' + err.code;
    }
  }

  build() {
    Column({ space: 16 }) {
      Text('TOTP 算码 demo')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text(this.code)
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontFamily('monospace')
      Text('剩余 ' + this.remaining + ' 秒')
        .fontSize(16)
      Progress({ value: this.progress, total: 1, type: ProgressType.Linear })
        .width('80%')
      Button('校验当前码(演示 window=1)')
        .onClick(() => {
          this.verifyAndSync();
        })
      Text(this.deltaText)
        .fontSize(14)
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(14)
          .fontColor(Color.Red)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
