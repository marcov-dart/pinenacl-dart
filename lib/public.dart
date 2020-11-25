library pinenacl.api.public;

import 'dart:typed_data';

import 'api.dart';
export 'package:pinenacl/api.dart';

/// Public Key Encryption
///
/// Package box authenticates and encrypts small messages using public-key cryptography.
/// Box uses Curve25519, XSalsa20 and Poly1305 to encrypt and authenticate messages.
/// The length of messages is not hidden.
///
/// It is the caller's responsibility to ensure the uniqueness of nonces—for example,
/// by using nonce 1 for the first message, nonce 2 for the second message, etc.
/// Nonces are long enough that randomly generated nonces have negligible risk of collision.
///
/// Messages should be small because:
/// 1. The whole message needs to be held in memory to be processed.
/// 2. Using large messages pressures implementations on small machines to decrypt and process
/// plaintext before authenticating it. This is very dangerous, and this API does not allow it,
/// but a protocol that uses excessive message sizes might present some implementations with no other choice.
/// 3. Fixed overheads will be sufficiently amortised by messages as small as 8KB.
/// 4. Performance may be improved by working with messages that fit into data caches.
///
/// Thus large amounts of data should be chunked so that each message is small.
/// (Each message still needs a unique nonce.) If in doubt, 16KB is a reasonable chunk size.
///
/// Doc Comment from: [PyNaCl's readthedocs](https://pynacl.readthedocs.io)
///
/// The __Box__ class boxes and unboxes messages between a pair of keys
///
/// The ciphertexts generated by Box include a 16 byte authenticator which
/// is checked as part of the decryption.
/// An invalid authenticator will cause the decrypt function to raise an exception.
/// The authenticator is not a signature. Once you’ve decrypted the message you’ve
/// demonstrated the ability to create arbitrary valid message,
/// so messages you send are repudiable. For non-repudiable messages,
/// sign them after encryption.
///
/// Doc comment from: [PyNaCl's readthedocs](https://pynacl.readthedocs.io)
class Box extends BoxBase {
  Box(
      {required AsymmetricPrivateKey myPrivateKey,
      required AsymmetricPublicKey theirPublicKey})
      : super.fromList(
            _beforeNm(theirPublicKey, myPrivateKey, null) as List<int>);

  Box._fromSharedKey(AsymmetricKey sharedKey)
      : super.fromList(_beforeNm(null, null, sharedKey) as List<int>);

  factory Box.decode(AsymmetricKey encoded) {
    return Box._fromSharedKey(encoded);
  }

  AsymmetricKey get sharedKey => this;

  static const decoder = HexCoder.instance;

  @override
  Encoder get encoder => decoder;

  // NOTE: properties and function must be public i.e. not underscore names e.g. _key
  @override
  ByteList get key => sharedKey;

  @override
  Crypting doEncrypt = TweetNaCl.crypto_box_afternm;

  @override
  Crypting doDecrypt = TweetNaCl.crypto_box_open_afternm;

  // Initialize the sharedKey
  static ByteList? _beforeNm(AsymmetricPublicKey? publicKey,
      AsymmetricPrivateKey? secretKey, AsymmetricKey? sharedKey) {
    if (publicKey == null && secretKey == null) {
      /// Using the predefined sharedKey we must have the
      /// publicKey and privateKey unset.
      /// It returns a null or a list, which checked in the parent classes.
      return sharedKey;
    } else if (publicKey == null || secretKey == null) {
      /// Invalid combination
      return null;
    } else if (sharedKey != null) {
      throw Exception(
          'The sharedKey must be null when the private and public keys are provided.');
    }

    final priv = Uint8List.fromList(secretKey);
    final pub = Uint8List.fromList(publicKey);
    final k = Uint8List(TweetNaCl.keyLength);

    TweetNaCl.crypto_box_beforenm(k, pub, priv);
    // Returns the constructed sharedKey.
    return ByteList.fromList(k);
  }
}

/// The SealedBox class encrypts messages addressed to a specified key-pair
/// by using ephemeral sender’s keypairs, which will be discarded just after
/// encrypting a single plaintext message.
///
/// This kind of construction allows sending messages, which only the recipient
/// can decrypt without providing any kind of cryptographic proof of sender’s authorship.
///
/// ## `Warning`
/// By design, the recipient will have no means to trace the ciphertext to a known author,
/// since the sending keypair itself is not bound to any sender’s identity, and the sender
/// herself will not be able to decrypt the ciphertext she just created, since the private
/// part of the key cannot be recovered after use.
///
/// Doc comment from: [PyNaCl's readthedocs](https://pynacl.readthedocs.io)
class SealedBox extends AsymmetricKey {
  SealedBox._fromKeyPair(
      AsymmetricPrivateKey? privateKey, AsymmetricPublicKey publicKey)
      : _privateKey = privateKey,
        super.fromList(publicKey);

  factory SealedBox(AsymmetricKey key) {
    if (key is AsymmetricPrivateKey) {
      final pub = key.publicKey;
      return SealedBox._fromKeyPair(key, pub);
    } else if (key is AsymmetricPublicKey) {
      return SealedBox._fromKeyPair(null, key);
    } else {
      throw Exception(
          'SealedBox must be created from a PublicKey or a PrivateKey');
    }
  }

  final AsymmetricPrivateKey? _privateKey;

  static const _zerobytesLength = TweetNaCl.zerobytesLength;
  static const _nonceLength = 24;
  static const _pubLength = TweetNaCl.publicKeyLength;
  static const _secretLength = TweetNaCl.secretKeyLength;
  static const _macBytes = TweetNaCl.macBytes;
  static const _sealBytes = _pubLength + _macBytes;

  static const decoder = HexCoder.instance;

  @override
  Encoder get encoder => decoder;

  /// Decrypts the ciphertext using the ephemeral public key enclosed
  /// in the ciphertext and the SealedBox private key, returning
  /// the plaintext message.
  Uint8List decrypt(Uint8List ciphertext) {
    if (_privateKey == null) {
      throw Exception(
          'SealedBox does not have the privateKey to decrypt the ciphertext');
    }
    return _cryptoBoxSealOpen(ciphertext);
  }

  /// Encrypts the plaintext message using a random-generated ephemeral
  /// keypair and returns a "composed ciphertext", containing both
  /// the public part of the keypair and the ciphertext proper,
  /// encoded with the encoder.
  ///
  /// The private part of the ephemeral key-pair will be scrubbed before
  /// returning the ciphertext, therefore, the sender will not be able to
  /// decrypt the generated ciphertext.
  Uint8List encrypt(List<int> plaintext) {
    return _cryptoBoxSeal(Uint8List.fromList(plaintext), this);
  }

  static void _generateNonce(Uint8List out, Uint8List in1, Uint8List in2) {
    final state = Blake2b.init(_nonceLength, null, null, null);
    Blake2b.update(state, in1);
    Blake2b.update(state, in2);

    final digest = Blake2b.finalise(state);
    Utils.listCopy(digest, out, 0);
  }

  /// The `crypto_box_seal` is not in the `TweetNaCl`, that's why
  /// is implemented here and not in `TweetNaClFast`
  ///
  /// Encrypts and returns a message `message` using an ephemeral secret key
  /// and the public key `pk`.
  /// The ephemeral public key, which is embedded in the sealed box, is also
  /// used, in combination with `pk`, to derive the nonce needed for the
  /// underlying box construct.
  Uint8List _cryptoBoxSeal(Uint8List message, ByteList pk) {
    final mLen = message.length;
    final cLen = _sealBytes + mLen;
    final ciphertext = Uint8List(cLen);

    var epk = Uint8List(_pubLength);
    var esk = Uint8List(_secretLength);
    TweetNaCl.crypto_box_keypair(epk, esk);

    final nonce = Uint8List(_nonceLength);
    _generateNonce(nonce, epk, pk);

    final k = Uint8List(_secretLength);
    TweetNaCl.crypto_box_beforenm(k, pk, esk);

    var mac = ciphertext.sublist(_pubLength, _pubLength + _macBytes);

    _cryptoBoxDetached(ciphertext, mac, message, mLen, nonce, k);
    Utils.listCopy(epk, ciphertext, 0);
    Utils.listCopy(mac, ciphertext, _pubLength);

    // Clean the sensitive data which are not required anymore.
    Utils.listZero(esk);
    Utils.listZero(nonce);
    Utils.listZero(k);

    return ciphertext;
  }

  void _cryptoBoxDetached(Uint8List c, Uint8List mac, Uint8List m, int d,
      Uint8List n, Uint8List k) {
    var ciphertext = Uint8List(d + _zerobytesLength);

    TweetNaCl.crypto_stream_xor(
        ciphertext,
        0,
        Uint8List.fromList(List<int>.filled(_zerobytesLength, 0) + m),
        0,
        d + _zerobytesLength,
        n,
        k);

    final block0 = ciphertext.sublist(0, _zerobytesLength);
    ciphertext = ciphertext.sublist(_zerobytesLength, d + _zerobytesLength);
    Utils.listCopy(ciphertext, c, _zerobytesLength + _macBytes);

    TweetNaCl.crypto_onetimeauth(mac, ciphertext, d, block0);
  }

  /// Decrypts and returns an encrypted message `ciphertext`, using the
  /// recipent's secret key `sk` and the sender's ephemeral public key
  /// embedded in the sealed box. The box contruct nonce is derived from
  /// the recipient's public key `pk` and the sender's public key.
  Uint8List _cryptoBoxSealOpen(Uint8List ciphertext) {
    final cLen = ciphertext.length;

    if (cLen < _sealBytes) {
      throw Exception('Input cyphertext must be at least $_sealBytes long');
    } else if (cLen == _sealBytes) {
      // means empty message, no point of calculate anything.
      return Uint8List(0);
    }

    final mLen = cLen - _sealBytes;
    final plaintext = Uint8List(mLen + _zerobytesLength);

    final epk = ciphertext.sublist(0, _pubLength);

    final k = Uint8List(_secretLength);
    TweetNaCl.crypto_box_beforenm(k, epk, _privateKey!);
    final nonce = Uint8List(_nonceLength);
    _generateNonce(nonce, epk, this);

    var x = Uint8List(_secretLength);
    TweetNaCl.crypto_stream(x, 0, _zerobytesLength, nonce, k);

    final mac = ciphertext.sublist(_zerobytesLength, _sealBytes);
    final mm = ciphertext.sublist(_sealBytes);

    if (TweetNaCl.crypto_onetimeauth_verify(mac, mm, x) != 0) {
      throw 'The message is forged, malformed or the shared secret is invalid';
    }

    final a = x.toList() + mm;
    final cc = Uint8List.fromList(a);

    TweetNaCl.crypto_stream_xor(plaintext, 0, cc, 0, cc.length, nonce, k);

    return plaintext.sublist(_zerobytesLength);
  }
}
