import base32Test from './Base32.test';
import counterTest from './Counter.test';
import truncateTest from './Truncate.test';
import digitsTest from './Digits.test';
import timeStepTest from './TimeStep.test';
import secretTest from './Secret.test';
import cryptoSourceTest from './CryptoSource.test';
import otpAuthUriTest from './OtpAuthUri.test';
import otpErrorTest from './OtpError.test';
import otpEngineTest from './OtpEngine.test';
import hotpTest from './Hotp.test';
import totpTest from './Totp.test';

export default function testsuite() {
  base32Test();
  counterTest();
  truncateTest();
  digitsTest();
  timeStepTest();
  secretTest();
  cryptoSourceTest();
  otpAuthUriTest();
  otpErrorTest();
  otpEngineTest();
  hotpTest();
  totpTest();
}
