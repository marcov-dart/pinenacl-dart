import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

class Sha256 {
  static const K = [
    // 4x16
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static Int32 _rotr(Int32 x, int n) => _shr(x, n) | (x << (32 - n));
  static Int32 _shr(Int32 x, int n) => x.shiftRightUnsigned(n);
  static Int32 _ch(Int32 x, Int32 y, Int32 z) => ((x & y) ^ ((~x) & z));
  static Int32 _maj(Int32 x, Int32 y, Int32 z) => ((x & y) ^ (x & z) ^ (y & z));
  static Int32 _sigma0(Int32 x) => (_rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22));
  static Int32 _sigma1(Int32 x) => (_rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25));
  static Int32 _gamma0(Int32 x) => (_rotr(x, 7) ^ _rotr(x, 18) ^ _shr(x, 3));
  static Int32 _gamma1(Int32 x) => (_rotr(x, 17) ^ _rotr(x, 19) ^ _shr(x, 10));

  static Uint8List crypto_hash_sha256(Uint8List out, Uint8List m) {
    return _crypto_hash_sha256(out, m, m.length);
  }

  static Uint8List _crypto_hash_sha256(Uint8List out, Uint8List m, int l) {
    if (out.length != 32) {
      throw Exception('Invalid block for the message to digest.');
    }

    final w = List<Int32>.filled(64, Int32(0));
    Int32 a, b, c, d, e, f, g, h, T1, T2;

    final hh = List<Int32>.from(<Int32>[
      Int32(0x6a09e667),
      Int32(0xbb67ae85),
      Int32(0x3c6ef372),
      Int32(0xa54ff53a),
      Int32(0x510e527f),
      Int32(0x9b05688c),
      Int32(0x1f83d9ab),
      Int32(0x5be0cd19)
    ]);

    final paddedLen = ((l + 8 >> 6) << 4) + 16;
    final padded = Uint32List(paddedLen);

    final bitLength = l << 3;
    final dataLength = bitLength >> 5;

    for (var i = 0; i < bitLength; i += 8) {
      padded[i >> 5] |= (m[i ~/ 8]) << (24 - i % 32);
    }

    padded[dataLength] |= 0x80 << (24 - bitLength % 32);
    padded[paddedLen - 1] = bitLength;

    for (var i = 0; i < padded.length; i += 16) {
      a = hh[0];
      b = hh[1];
      c = hh[2];
      d = hh[3];
      e = hh[4];
      f = hh[5];
      g = hh[6];
      h = hh[7];

      for (var j = 0; j < 64; j++) {
        if (j < 16) {
          w[j] = Int32(padded[j + i]);
        } else {
          w[j] = _gamma1(w[j - 2]) + w[j - 7] + _gamma0(w[j - 15]) + w[j - 16]
              as Int32;
        }

        T1 = _sigma1(e) + _ch(e, f, g) + h + K[j] + w[j] as Int32;
        T2 = _sigma0(a) + _maj(a, b, c) as Int32;

        h = g;
        g = f;
        f = e;
        e = d + T1 as Int32;
        d = c;
        c = b;
        b = a;
        a = T1 + T2 as Int32;
      }

      hh[0] = a + hh[0] as Int32;
      hh[1] = b + hh[1] as Int32;
      hh[2] = c + hh[2] as Int32;
      hh[3] = d + hh[3] as Int32;
      hh[4] = e + hh[4] as Int32;
      hh[5] = f + hh[5] as Int32;
      hh[6] = g + hh[6] as Int32;
      hh[7] = h + hh[7] as Int32;
    }

    for (var i = 0; i < hh.length; i++) {
      out[4 * i + 0] = ((hh[i] >> 24) & 0xff).toInt();
      out[4 * i + 1] = ((hh[i] >> 16) & 0xff).toInt();
      out[4 * i + 2] = ((hh[i] >> 8) & 0xff).toInt();
      out[4 * i + 3] = (hh[i] & 0xff).toInt();
    }

    return out;
  }
}
