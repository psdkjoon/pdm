import 'dart:io';
import 'dart:typed_data';
Future<String> hashFile(String path, String algo) async {
  final bytes = await File(path).readAsBytes();
  switch (algo.toLowerCase()) {
    case 'md5':
      return _bytesToHex(_md5(bytes));
    case 'sha1':
      return _bytesToHex(_sha1(bytes));
    case 'sha256':
      return _bytesToHex(_sha256(bytes));
    case 'sha512':
      return _bytesToHex(_sha512(bytes));
    default:
      throw ArgumentError('Unsupported checksum algorithm "$algo"');
  }
}
Future<bool> verifyFileChecksum(String path, String algo, String expected) async {
  final actual = await hashFile(path, algo);
  return actual.toLowerCase() == expected.toLowerCase();
}
String _bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
int _rotl32(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF;
int _rotr32(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
int _rotr64(int x, int n) => ((x >> n) | (x << (64 - n))) & 0xFFFFFFFFFFFFFFFF;
const _md5S = <int>[
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
];
const _md5K = <int>[
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
  0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
  0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
  0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
  0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
  0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
  0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
  0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
];
Uint8List _md5(Uint8List message) {
  var a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
  final padded = _padLE(message);
  final view = ByteData.sublistView(padded);
  for (var chunkStart = 0; chunkStart < padded.length; chunkStart += 64) {
    final m = List<int>.generate(
      16,
      (j) => view.getUint32(chunkStart + j * 4, Endian.little),
    );
    var a = a0, b = b0, c = c0, d = d0;
    for (var i = 0; i < 64; i++) {
      int f, g;
      if (i < 16) {
        f = (b & c) | (~b & d);
        g = i;
      } else if (i < 32) {
        f = (d & b) | (~d & c);
        g = (5 * i + 1) % 16;
      } else if (i < 48) {
        f = b ^ c ^ d;
        g = (3 * i + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * i) % 16;
      }
      f = (f + a + _md5K[i] + m[g]) & 0xFFFFFFFF;
      a = d;
      d = c;
      c = b;
      b = (b + _rotl32(f, _md5S[i])) & 0xFFFFFFFF;
    }
    a0 = (a0 + a) & 0xFFFFFFFF;
    b0 = (b0 + b) & 0xFFFFFFFF;
    c0 = (c0 + c) & 0xFFFFFFFF;
    d0 = (d0 + d) & 0xFFFFFFFF;
  }
  final out = ByteData(16);
  out.setUint32(0, a0, Endian.little);
  out.setUint32(4, b0, Endian.little);
  out.setUint32(8, c0, Endian.little);
  out.setUint32(12, d0, Endian.little);
  return out.buffer.asUint8List();
}
Uint8List _padLE(Uint8List message) {
  final bitLength = message.length * 8;
  var paddedLength = message.length + 1;
  while (paddedLength % 64 != 56) {
    paddedLength++;
  }
  paddedLength += 8;
  final padded = Uint8List(paddedLength);
  padded.setRange(0, message.length, message);
  padded[message.length] = 0x80;
  final view = ByteData.sublistView(padded);
  view.setUint64(paddedLength - 8, bitLength, Endian.little);
  return padded;
}
Uint8List _padBE(Uint8List message) {
  final bitLength = message.length * 8;
  var paddedLength = message.length + 1;
  while (paddedLength % 64 != 56) {
    paddedLength++;
  }
  paddedLength += 8;
  final padded = Uint8List(paddedLength);
  padded.setRange(0, message.length, message);
  padded[message.length] = 0x80;
  final view = ByteData.sublistView(padded);
  view.setUint64(paddedLength - 8, bitLength, Endian.big);
  return padded;
}
Uint8List _sha1(Uint8List message) {
  var h0 = 0x67452301;
  var h1 = 0xEFCDAB89;
  var h2 = 0x98BADCFE;
  var h3 = 0x10325476;
  var h4 = 0xC3D2E1F0;
  final padded = _padBE(message);
  final view = ByteData.sublistView(padded);
  for (var chunkStart = 0; chunkStart < padded.length; chunkStart += 64) {
    final w = List<int>.filled(80, 0);
    for (var j = 0; j < 16; j++) {
      w[j] = view.getUint32(chunkStart + j * 4, Endian.big);
    }
    for (var j = 16; j < 80; j++) {
      w[j] = _rotl32(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);
    }
    var a = h0, b = h1, c = h2, d = h3, e = h4;
    for (var j = 0; j < 80; j++) {
      int f, k;
      if (j < 20) {
        f = (b & c) | (~b & d);
        k = 0x5A827999;
      } else if (j < 40) {
        f = b ^ c ^ d;
        k = 0x6ED9EBA1;
      } else if (j < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8F1BBCDC;
      } else {
        f = b ^ c ^ d;
        k = 0xCA62C1D6;
      }
      final temp = (_rotl32(a, 5) + f + e + k + w[j]) & 0xFFFFFFFF;
      e = d;
      d = c;
      c = _rotl32(b, 30);
      b = a;
      a = temp;
    }
    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
  }
  final out = ByteData(20);
  out.setUint32(0, h0, Endian.big);
  out.setUint32(4, h1, Endian.big);
  out.setUint32(8, h2, Endian.big);
  out.setUint32(12, h3, Endian.big);
  out.setUint32(16, h4, Endian.big);
  return out.buffer.asUint8List();
}
const _sha256K = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];
Uint8List _sha256(Uint8List message) {
  var h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  final padded = _padBE(message);
  final view = ByteData.sublistView(padded);
  for (var chunkStart = 0; chunkStart < padded.length; chunkStart += 64) {
    final w = List<int>.filled(64, 0);
    for (var j = 0; j < 16; j++) {
      w[j] = view.getUint32(chunkStart + j * 4, Endian.big);
    }
    for (var j = 16; j < 64; j++) {
      final s0 = _rotr32(w[j - 15], 7) ^ _rotr32(w[j - 15], 18) ^ (w[j - 15] >> 3);
      final s1 = _rotr32(w[j - 2], 17) ^ _rotr32(w[j - 2], 19) ^ (w[j - 2] >> 10);
      w[j] = (w[j - 16] + s0 + w[j - 7] + s1) & 0xFFFFFFFF;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var j = 0; j < 64; j++) {
      final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
      final ch = (e & f) ^ (~e & g);
      final temp1 = (hh + s1 + ch + _sha256K[j] + w[j]) & 0xFFFFFFFF;
      final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }
    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
    h[5] = (h[5] + f) & 0xFFFFFFFF;
    h[6] = (h[6] + g) & 0xFFFFFFFF;
    h[7] = (h[7] + hh) & 0xFFFFFFFF;
  }
  final out = ByteData(32);
  for (var i = 0; i < 8; i++) {
    out.setUint32(i * 4, h[i], Endian.big);
  }
  return out.buffer.asUint8List();
}
const _sha512K = <int>[
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817,
];
Uint8List _sha512(Uint8List message) {
  var h = <int>[
    0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
    0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
  ];
  final padded = _padBE128(message);
  final view = ByteData.sublistView(padded);
  for (var chunkStart = 0; chunkStart < padded.length; chunkStart += 128) {
    final w = List<int>.filled(80, 0);
    for (var j = 0; j < 16; j++) {
      w[j] = view.getUint64(chunkStart + j * 8, Endian.big);
    }
    for (var j = 16; j < 80; j++) {
      final s0 = _rotr64(w[j - 15], 1) ^ _rotr64(w[j - 15], 8) ^ (w[j - 15] >> 7);
      final s1 = _rotr64(w[j - 2], 19) ^ _rotr64(w[j - 2], 61) ^ (w[j - 2] >> 6);
      w[j] = w[j - 16] + s0 + w[j - 7] + s1;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var j = 0; j < 80; j++) {
      final s1 = _rotr64(e, 14) ^ _rotr64(e, 18) ^ _rotr64(e, 41);
      final ch = (e & f) ^ (~e & g);
      final temp1 = hh + s1 + ch + _sha512K[j] + w[j];
      final s0 = _rotr64(a, 28) ^ _rotr64(a, 34) ^ _rotr64(a, 39);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = s0 + maj;
      hh = g;
      g = f;
      f = e;
      e = d + temp1;
      d = c;
      c = b;
      b = a;
      a = temp1 + temp2;
    }
    h[0] += a;
    h[1] += b;
    h[2] += c;
    h[3] += d;
    h[4] += e;
    h[5] += f;
    h[6] += g;
    h[7] += hh;
  }
  final out = ByteData(64);
  for (var i = 0; i < 8; i++) {
    out.setUint64(i * 8, h[i], Endian.big);
  }
  return out.buffer.asUint8List();
}
Uint8List _padBE128(Uint8List message) {
  final bitLength = message.length * 8;
  var paddedLength = message.length + 1;
  while (paddedLength % 128 != 112) {
    paddedLength++;
  }
  paddedLength += 16;
  final padded = Uint8List(paddedLength);
  padded.setRange(0, message.length, message);
  padded[message.length] = 0x80;
  final view = ByteData.sublistView(padded);
  view.setUint64(paddedLength - 8, bitLength, Endian.big);
  return padded;
}
