part of pinenacl.api;

abstract class SignatureBase extends ByteList {}

abstract class EncryptionMessage {
  SignatureBase get signature;
  ByteList get message;
}

mixin Verify<T extends AlgorithmParams> on ByteList {
  bool verify({SignatureBase signature, List<int> message}) {
    if (signature != null) {
      if (signature.length != TweetNaCl.signatureLength) {
        throw Exception(
            'Signature length (${signature.length}) is invalid, expected "${TweetNaCl.signatureLength}"');
      }
      message = signature + message;
    }
    if (message == null || message.length < TweetNaCl.signatureLength) {
      throw Exception(
          'Signature length (${message.length}) is invalid, expected "${TweetNaCl.signatureLength}"');
    }

    Uint8List m = Uint8List(message.length);

    /// get the signing algorytm
    AlgorithmParams alg = Registrar.getInstance(T.toString());

    final result = alg.sigParams
        .verifyAlg(m, -1, Uint8List.fromList(message), 0, message.length, this);
    if (result != 0) {
      throw Exception(
          'The message is forged or malformed or the signature is invalid');
    }
    return true;
  }

  bool verifySignedMessage({EncryptionMessage signedMessage}) => verify(
      signature: signedMessage.signature, message: signedMessage.message);
}

mixin Sign<T extends AlgorithmParams> on ByteList {
  SignedMessage sign(List<int> message) {
    // signed message
    Uint8List sm = Uint8List(message.length + TweetNaCl.signatureLength);

    AlgorithmParams alg = Registrar.getInstance(T.toString());

    final result = alg.sigParams
        .signAlg(sm, -1, Uint8List.fromList(message), 0, message.length, this);
    if (result != 0) {
      throw Exception('Signing the massage is failed');
    }

    return SignedMessage<T>.fromList(signedMessage: sm);
  }
}

class Signature<T extends AlgorithmParams> extends ByteList
    implements SignatureBase {
  Signature(List<int> bytes) : super(bytes, bytesLength);
  static const bytesLength = TweetNaCl.signatureLength;

  @override
  Codec get encoder => Registrar.getInstance(T.toString()).sigParams.codec;
}

class SignedMessage<T extends AlgorithmParams> extends ByteList
    with Suffix
    implements EncryptionMessage {
  SignedMessage({SignatureBase signature, List<int> message})
      : super(signature + message, signatureLength);
  SignedMessage.fromList({List<int> signedMessage}) : super(signedMessage);

  @override
  int prefixLength = signatureLength;

  static const signatureLength = 64;

  @override
  SignatureBase get signature => Signature<T>(prefix);

  @override
  ByteList get message => suffix;
}
