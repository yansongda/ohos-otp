/**
 * RFC 4226/6238 黄金向量（全库唯一来源，禁止改值、禁止补算）。
 * 本文件仅供测试使用（fixture 装表 + 期望值断言），kit-free。
 */

/** RFC 4226 Appendix D：SHA1 / seed 20B / digits=6（A.2，10 条）。 */
export interface Rfc4226Vector {
  counter: number;
  digestHex: string;
  code: string;
}

/** RFC 6238 Appendix B：X=30 / T0=0 / digits=8（A.3）。 */
export interface Rfc6238Vector {
  timeSec: number;
  counter: number;
  counterHex: string;
  digestHex: string;
  code8: string;
}

/** A.4 单个算法的 {digest, 6 位码, 8 位码} 结构。 */
export interface BoundaryAlg {
  digest: string;
  code6: string;
  code8: string;
}

/** A.4 边界 counter：每 counter 按算法各存一组 6/8 位码。 */
export interface BoundaryVector {
  counter: number;
  counterHex: string;
  sha1: BoundaryAlg;
  sha256: BoundaryAlg;
  sha512: BoundaryAlg;
}

/** A.6 SHA1 / digits=7（counter 0/1/9）。 */
export interface Digits7Vector {
  counter: number;
  digestHex: string;
  code7: string;
}

/** A.5 counterToBytes 对照表。 */
export interface CounterBytesVector {
  counter: number;
  hex: string;
}

/** A.2 RFC 4226 Appendix D（SHA1 / seed 20B / digits=6）。 */
export const RFC4226_SHA1_6DIGIT: Rfc4226Vector[] = [
  { counter: 0, digestHex: 'cc93cf18508d94934c64b65d8ba7667fb7cde4b0', code: '755224' },
  { counter: 1, digestHex: '75a48a19d4cbe100644e8ac1397eea747a2d33ab', code: '287082' },
  { counter: 2, digestHex: '0bacb7fa082fef30782211938bc1c5e70416ff44', code: '359152' },
  { counter: 3, digestHex: '66c28227d03a2d5529262ff016a1e6ef76557ece', code: '969429' },
  { counter: 4, digestHex: 'a904c900a64b35909874b33e61c5938a8e15ed1c', code: '338314' },
  { counter: 5, digestHex: 'a37e783d7b7233c083d4f62926c7a25f238d0316', code: '254676' },
  { counter: 6, digestHex: 'bc9cd28561042c83f219324d3c607256c03272ae', code: '287922' },
  { counter: 7, digestHex: 'a4fb960c0bc06e1eabb804e5b397cdc4b45596fa', code: '162583' },
  { counter: 8, digestHex: '1b3c89f65e6c9e883012052823443f048b4332db', code: '399871' },
  { counter: 9, digestHex: '1637409809a679dc698207310c8c7fc07290d9e5', code: '520489' }
];

/** A.3 RFC 6238 Appendix B，SHA1 列（6 条）。 */
export const RFC6238_SHA1: Rfc6238Vector[] = [
  { timeSec: 59, counter: 1, counterHex: '0000000000000001', digestHex: '75a48a19d4cbe100644e8ac1397eea747a2d33ab', code8: '94287082' },
  { timeSec: 1111111109, counter: 37037036, counterHex: '00000000023523ec', digestHex: '278c02e53610f84c40bd9135acd4101012410a14', code8: '07081804' },
  { timeSec: 1111111111, counter: 37037037, counterHex: '00000000023523ed', digestHex: 'b0092b21d048af209da0a1ddd498ade8a79487ed', code8: '14050471' },
  { timeSec: 1234567890, counter: 41152263, counterHex: '000000000273ef07', digestHex: '907cd1a9116564ecb9d5d1780325f246173fe703', code8: '89005924' },
  { timeSec: 2000000000, counter: 66666666, counterHex: '0000000003f940aa', digestHex: '25a326d31fc366244cad054976020c7b56b13d5f', code8: '69279037' },
  { timeSec: 20000000000, counter: 666666666, counterHex: '0000000027bc86aa', digestHex: 'ab07e97e2c1278769dbcd75783aabde75ed8550a', code8: '65353130' }
];

/** A.3 RFC 6238 Appendix B，SHA256 列（6 条）。 */
export const RFC6238_SHA256: Rfc6238Vector[] = [
  { timeSec: 59, counter: 1, counterHex: '0000000000000001', digestHex: '392514c9dd4165d4709456062c78e04e16e68718515951333bdb8b26caa3053c', code8: '46119246' },
  { timeSec: 1111111109, counter: 37037036, counterHex: '00000000023523ec', digestHex: '4eed729864525d771326c6049bc885629fb8813ebb417e5704df02358793f056', code8: '68084774' },
  { timeSec: 1111111111, counter: 37037037, counterHex: '00000000023523ed', digestHex: 'cb48f7ef5cd98f6d7bfcb31ae7458ff692a015776205de7e1abfff29d6d48a9d', code8: '67062674' },
  { timeSec: 1234567890, counter: 41152263, counterHex: '000000000273ef07', digestHex: '3befb8821caef9df4e05790da0966163f4e38feee7f71fcd289c3de48d3486d9', code8: '91819424' },
  { timeSec: 2000000000, counter: 66666666, counterHex: '0000000003f940aa', digestHex: 'a4e8eabbe549adfa65408945a9282cb93f394f06c0d4f122260963641bc3abe2', code8: '90698825' },
  { timeSec: 20000000000, counter: 666666666, counterHex: '0000000027bc86aa', digestHex: '1363cc0ee3557f092e5b55ea3ddb06bcd20f063ce393ccf670059e3ca44941f8', code8: '77737706' }
];

/** A.3 RFC 6238 Appendix B，SHA512 列（6 条）。 */
export const RFC6238_SHA512: Rfc6238Vector[] = [
  { timeSec: 59, counter: 1, counterHex: '0000000000000001', digestHex: '6f76f324230cefda1d3f65309a0badb36efce9528ada64967d71e4e9d74c4aa37fe7650f931ab86ddccc2d38962d720ee626a20feb311b485a92e3bb0796df28', code8: '90693936' },
  { timeSec: 1111111109, counter: 37037036, counterHex: '00000000023523ec', digestHex: 'b3381250260d6a9e811ae58dfa406705e38c804c97528d5a7ed8ee533331f8c43cc3454911ad1d2761f9380170c0b180a657e3a944c796e05d09f2d1630b7505', code8: '25091201' },
  { timeSec: 1111111111, counter: 37037037, counterHex: '00000000023523ed', digestHex: '01713ed59e49948a4f0fffb7466baebac66362d90764a5a23df761636e1535c44b635339ec00a789b8ca45cd3d727acd6b995047547f6f68adc6f16a7436c331', code8: '99943326' },
  { timeSec: 1234567890, counter: 41152263, counterHex: '000000000273ef07', digestHex: '87d0cfb5d4e968d7d9041a5cf21dd7d460705784004f0244edb98004e6cf9942ace539d621c97dc0fb75f6f10d64af1f09ecae83ea7f1213c7fa187dfaf6b938', code8: '93441116' },
  { timeSec: 2000000000, counter: 66666666, counterHex: '0000000003f940aa', digestHex: '129baa738cfa1565a24297237bce282671ff6e261754eb7011e1e75bd2555b326313142a1f9fe2f31d9ce6cc95d3b16a0dee56f2492f2f76885702d98bfadc93', code8: '38618901' },
  { timeSec: 20000000000, counter: 666666666, counterHex: '0000000027bc86aa', digestHex: '562298a02af13e7522127adee3dc6678d53669ca2b7016186968f9a9c14f51d1e7098ba91293a01b5f3bab4207a2af5ce332a45f2c2ff2b9885aa42ff61cb426', code8: '47863826' }
];

/** 边界 counter（RFC 6238 §4.2「T 必须支持超过 32 位」，3 条 × 三算法）。 */
export const BOUNDARY_COUNTERS: BoundaryVector[] = [
  {
    counter: 4294967296,
    counterHex: '0000000100000000',
    sha1: { digest: '7c9fd37f3b71aad82c508f423de075df9a15fbea', code6: '999456', code8: '55999456' },
    sha256: { digest: 'e2a1668e5766bf539f1e796308d494ee098d463aa95d6fd078987d5c9cc89874', code6: '351443', code8: '66351443' },
    sha512: { digest: '06d77e29a50045fa79fdefc7b53a6daeaa06563a8607332dd9bbe7292bb4d898c9675a3d85f115293c81179bb57d435b010fcb26a7207308a026a9b57768ce5f', code6: '894678', code8: '82894678' }
  },
  {
    counter: 4294967297,
    counterHex: '0000000100000001',
    sha1: { digest: '3203c942196668bb1ec3c6c8610c9ad02f191010', code6: '108930', code8: '39108930' },
    sha256: { digest: '8d7f17cf14053f1f8b2dd5ce012f3332899627ace62e1e990e068a9e08f2b112', code6: '447045', code8: '99447045' },
    sha512: { digest: '674f239496a045b341265c7a5be6fd6e3d3d4fbf3a3227600ed3c19e8f04bf14f382d486f9b7dda1e7dfb4e837bdbecd6afb4ed08f5528792b2c603652b90a96', code6: '375526', code8: '69375526' }
  },
  {
    counter: 9007199254740991,
    counterHex: '001fffffffffffff',
    sha1: { digest: '7d8d6dc907ebca15280ec364c9ca7c567c7a3cf2', code6: '891307', code8: '41891307' },
    sha256: { digest: 'bf01b7ccf0341510011a732a5ad7ad4ab4f23361d88fe285f3df6bff6ab1bcf1', code6: '822768', code8: '28822768' },
    sha512: { digest: '8c799dd186a120528c62d2d604c466fe4d9491824234abd9e6cbd8a483639a99b7ca033365a0f8635fee6bdada51da1bf3ed2742983c384b7a6b636a06093d65', code6: '766412', code8: '55766412' }
  }
];

/** A.6 SHA1 / digits=7：counter 0/1/9（code7 = A.2 对应 code 的 7 位形态）。 */
export const DIGITS7_SHA1: Digits7Vector[] = [
  { counter: 0, digestHex: 'cc93cf18508d94934c64b65d8ba7667fb7cde4b0', code7: '4755224' },
  { counter: 1, digestHex: '75a48a19d4cbe100644e8ac1397eea747a2d33ab', code7: '4287082' },
  { counter: 9, digestHex: '1637409809a679dc698207310c8c7fc07290d9e5', code7: '5520489' }
];

/** A.5 counterToBytes 对照表（9 条，8 字节大端 hex）。 */
export const COUNTER_BYTES: CounterBytesVector[] = [
  { counter: 0, hex: '0000000000000000' },
  { counter: 1, hex: '0000000000000001' },
  { counter: 9, hex: '0000000000000009' },
  { counter: 666666666, hex: '0000000027bc86aa' },
  { counter: 4294967295, hex: '00000000ffffffff' },
  { counter: 4294967296, hex: '0000000100000000' },
  { counter: 4294967297, hex: '0000000100000001' },
  { counter: 4294967391, hex: '000000010000005f' },
  { counter: 9007199254740991, hex: '001fffffffffffff' }
];

/** A.1 seed 结构（三算法 ASCII 字节串 + base32 规范形）。 */
export interface Seeds {
  SHA1: string;
  SHA256: string;
  SHA512: string;
  SHA1_BASE32: string;
  SHA256_BASE32: string;
  SHA512_BASE32: string;
}

/** seed（三算法 ASCII 字节串 + 等价 base32 规范形，供设备端用例走公开 API）。 */
export const SEEDS: Seeds = {
  SHA1: '12345678901234567890',
  SHA256: '12345678901234567890123456789012',
  SHA512: '1234567890123456789012345678901234567890123456789012345678901234',
  SHA1_BASE32: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
  SHA256_BASE32: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA',
  SHA512_BASE32: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA'
};

/** A.6 第 1 行：SHA256 / digits=8 / counter=0（period=60 → floor(59/60)=0）。 */
export const SHA256_C0_8DIGIT = '18920136';
export const SHA256_C0_DIGEST = 'c79f479abc3c567224e3f8c8e46b2631d5b3f319a06a1e472cbdbee3aa479848';
