/**
 * OTPAuthURI：otpauth:// URI 解析与生成（kit-free）。
 * 遵循 Google Authenticator Key URI Format（IANA Provisional #13829）；
 * query 手写拆分，不依赖平台 URL 查询解析 API。
 */
import { OtpError, OtpErrorCode } from './OtpError';
import { OtpAlgorithm, OtpAuthParams, OtpType } from './OtpOptions';
import { decode, encode } from './internal/Base32';

export class OTPAuthURI {
  /**
   * 解析 otpauth:// URI 为 OtpAuthParams：scheme 大小写不敏感 → type 限 totp/hotp →
   * label 百分号解码（失败回退原串）后按首个冒号切 issuer/account → query 手写拆分 →
   * secret 规范化为大写无填充 base32；未知参数忽略，query 的 issuer 优先于 label 前缀。
   */
  static parse(uri: string): OtpAuthParams {
    // ① scheme 大小写不敏感
    const prefix: string = 'otpauth://';
    if (uri.toLowerCase().indexOf(prefix) !== 0) {
      throw new OtpError(OtpErrorCode.INVALID_OTPAUTH_URI, 'INVALID_OTPAUTH_URI');
    }
    const rest: string = uri.substring(prefix.length);
    const qIndex: number = rest.indexOf('?');
    const beforeQuery: string = (qIndex === -1) ? rest : rest.substring(0, qIndex);
    const queryPart: string = (qIndex === -1) ? '' : rest.substring(qIndex + 1);

    // ② type：'?' 之前、'/' 之后，小写化；非 totp/hotp 抛 UNSUPPORTED_OTPAUTH_TYPE
    const slashIndex: number = beforeQuery.indexOf('/');
    const typeRaw: string = (slashIndex === -1) ? beforeQuery : beforeQuery.substring(0, slashIndex);
    const type: string = typeRaw.toLowerCase();
    if (type !== 'totp' && type !== 'hotp') {
      throw new OtpError(OtpErrorCode.UNSUPPORTED_OTPAUTH_TYPE, 'UNSUPPORTED_OTPAUTH_TYPE');
    }

    // ③ label：'/' 之后、'?' 之前的部分，百分号解码（失败回退原串）
    const labelRaw: string = (slashIndex === -1) ? '' : beforeQuery.substring(slashIndex + 1);
    let label: string = labelRaw;
    try {
      label = decodeURIComponent(labelRaw);
    } catch (e) {
      label = labelRaw; // 解码失败回退原串
    }
    // 按首个冒号切分 issuer/account；解码失败回退原串时兼容 '%3A' 分隔形式（只切第一个分隔符）
    let issuerFromLabel: string = '';
    let account: string = '';
    const colonIndex: number = label.indexOf(':');
    if (colonIndex !== -1) {
      issuerFromLabel = label.substring(0, colonIndex);
      account = label.substring(colonIndex + 1);
    } else {
      const pctIndex: number = label.indexOf('%3A');
      if (pctIndex !== -1) {
        issuerFromLabel = label.substring(0, pctIndex);
        account = label.substring(pctIndex + 3);
      } else {
        account = label;
      }
    }

    // ④ query 手写拆分：'&' 分段、'=' 分键值，键值均百分号解码（失败回退原串）
    const params: Map<string, string> = new Map<string, string>();
    if (queryPart !== '') {
      const pairs: string[] = queryPart.split('&');
      for (let i = 0; i < pairs.length; i++) {
        const pair: string = pairs[i];
        if (pair === '') {
          continue;
        }
        const eqIndex: number = pair.indexOf('=');
        let key: string;
        let value: string;
        if (eqIndex === -1) {
          key = pair;
          value = '';
        } else {
          key = pair.substring(0, eqIndex);
          value = pair.substring(eqIndex + 1);
        }
        try {
          key = decodeURIComponent(key);
        } catch (e) {
          // 键解码失败回退原串
        }
        try {
          value = decodeURIComponent(value);
        } catch (e) {
          // 值解码失败回退原串
        }
        params.set(key.toLowerCase(), value);
      }
    }

    // secret 必填，经 Base32.decode 校验（空/非法字符/过短各自抛码）
    const secretRaw: string | undefined = params.get('secret');
    if (secretRaw === undefined || secretRaw === '') {
      throw new OtpError(OtpErrorCode.EMPTY_SECRET, 'EMPTY_SECRET');
    }
    const secret: string = encode(decode(secretRaw));

    // issuer：query 优先，其次 label 前缀
    let issuer: string = issuerFromLabel;
    const issuerQuery: string | undefined = params.get('issuer');
    if (issuerQuery !== undefined) {
      issuer = issuerQuery;
    }

    // algorithm：大小写不敏感，默认 SHA1；非三值抛 INVALID_ALGORITHM
    let algorithm: OtpAlgorithm = OtpAlgorithm.SHA1;
    const algorithmRaw: string | undefined = params.get('algorithm');
    if (algorithmRaw !== undefined && algorithmRaw !== '') {
      const upper: string = algorithmRaw.toUpperCase();
      if (upper === 'SHA1') {
        algorithm = OtpAlgorithm.SHA1;
      } else if (upper === 'SHA256') {
        algorithm = OtpAlgorithm.SHA256;
      } else if (upper === 'SHA512') {
        algorithm = OtpAlgorithm.SHA512;
      } else {
        throw new OtpError(OtpErrorCode.INVALID_ALGORITHM, 'INVALID_ALGORITHM');
      }
    }

    // digits：默认 6，仅 6/7/8，否则 INVALID_DIGITS
    let digits: number = 6;
    const digitsRaw: string | undefined = params.get('digits');
    if (digitsRaw !== undefined && digitsRaw !== '') {
      const d: number = Number(digitsRaw);
      if (d !== 6 && d !== 7 && d !== 8) {
        throw new OtpError(OtpErrorCode.INVALID_DIGITS, 'INVALID_DIGITS');
      }
      digits = d;
    }

    // period（仅 TOTP）：默认 30，正整数，否则 INVALID_PERIOD
    // counter（仅 HOTP）：默认 0，非负整数，否则 INVALID_COUNTER
    let period: number = 30;
    let counter: number = 0;
    if (type === 'totp') {
      const periodRaw: string | undefined = params.get('period');
      if (periodRaw !== undefined && periodRaw !== '') {
        const p: number = Number(periodRaw);
        if (!Number.isInteger(p) || p <= 0) {
          throw new OtpError(OtpErrorCode.INVALID_PERIOD, 'INVALID_PERIOD');
        }
        period = p;
      }
    } else {
      const counterRaw: string | undefined = params.get('counter');
      if (counterRaw !== undefined && counterRaw !== '') {
        const c: number = Number(counterRaw);
        if (!Number.isInteger(c) || c < 0) {
          throw new OtpError(OtpErrorCode.INVALID_COUNTER, 'INVALID_COUNTER');
        }
        counter = c;
      }
    }

    const result: OtpAuthParams = {
      type: type === 'totp' ? OtpType.TOTP : OtpType.HOTP,
      secret: secret,
      algorithm: algorithm,
      digits: digits
    };
    if (type === 'totp') {
      result.period = period;
    } else {
      result.counter = counter;
    }
    if (issuer !== '') {
      result.issuer = issuer;
    }
    if (account !== '') {
      result.account = account;
    }
    if (label !== '') {
      result.label = label;
    }
    return result;
  }

  /**
   * 由 OtpAuthParams 生成规范 URI。参数顺序固定：secret, issuer, algorithm, digits, period|counter。
   * label 形如 issuer:account（两者百分号编码、冒号保留，为空则省略）；algorithm 始终输出，
   * digits 仅 != 6、period 仅 TOTP 且 != 30 时输出（与 GA 二维码惯例一致），HOTP 始终输出 counter。
   * secret 先经 Base32 规范化（与 parse 对称）；非法 base32 抛对应错误码。
   */
  static build(params: OtpAuthParams): string {
    const secret: string = encode(decode(params.secret));
    const type: string = params.type === OtpType.TOTP ? 'totp' : 'hotp';
    const issuer: string = params.issuer === undefined ? '' : params.issuer;
    const account: string = params.account === undefined ? '' : params.account;

    // label：issuer:account 均百分号编码、冒号保留；缺省方省略
    let label: string = '';
    if (issuer !== '') {
      label += encodeURIComponent(issuer);
    }
    if (account !== '') {
      if (label !== '') {
        label += ':';
      }
      label += encodeURIComponent(account);
    }

    const parts: string[] = [];
    parts.push('secret=' + secret);
    if (issuer !== '') {
      parts.push('issuer=' + encodeURIComponent(issuer));
    }
    parts.push('algorithm=' + params.algorithm);
    if (params.digits !== 6) {
      parts.push('digits=' + params.digits);
    }
    if (type === 'totp') {
      const period: number = params.period === undefined ? 30 : params.period;
      if (period !== 30) {
        parts.push('period=' + period);
      }
    } else {
      const counter: number = params.counter === undefined ? 0 : params.counter;
      parts.push('counter=' + counter);
    }

    return 'otpauth://' + type + '/' + label + '?' + parts.join('&');
  }
}
