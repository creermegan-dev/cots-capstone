import 'dart:typed_data';



import 'package:firebase_storage/firebase_storage.dart';



import '../utils/scan_record_image.dart';



class ScanImageUploadResult {

  const ScanImageUploadResult({

    required this.downloadUrl,

    required this.storageObjectPath,

  });



  final String downloadUrl;

  final String storageObjectPath;

}



/// Firebase Storage paths for user media — profile uploads work on all platforms via [putData].

class StorageService {

  StorageService({FirebaseStorage? storage})

      : _storage = storage ?? FirebaseStorage.instance;



  final FirebaseStorage _storage;



  static const _maxImageBytes = 20 * 1024 * 1024;



  /// `users/{uid}/profile/profile.jpg`

  Reference profileImageRef(String uid, {String filename = 'profile.jpg'}) {

    return _storage.ref().child('users').child(uid).child('profile').child(filename);

  }



  /// `scan_records/{uid}/{scanId}/{filename}`

  Reference scanImageRef(String uid, String scanId, {required String filename}) {

    return _storage

        .ref()

        .child('scan_records')

        .child(uid)

        .child(scanId)

        .child(filename);

  }



  /// Upload GoPro detection image; returns download URL and object path.

  Future<ScanImageUploadResult> uploadScanImageBytes({

    required String uid,

    required String scanId,

    required Uint8List bytes,

    required String filename,

    String contentType = 'image/jpeg',

  }) async {

    if (bytes.isEmpty) {

      throw FirebaseException(

        plugin: 'firebase_storage',

        code: 'invalid-argument',

        message: 'Scan image is empty — pick a photo and try again.',

      );

    }



    final safeName = ScanRecordImage.safeStorageFilename(filename);

    final objectPath = ScanRecordImage.scanObjectPath(

      uid: uid,

      scanId: scanId,

      filename: safeName,

    );

    final ref = _storage.ref(objectPath);

    final snapshot = await ref.putData(

      bytes,

      SettableMetadata(contentType: contentType),

    );

    if (snapshot.state != TaskState.success) {

      throw FirebaseException(

        plugin: 'firebase_storage',

        code: 'upload-failed',

        message: 'Scan image upload did not complete.',

      );

    }



    try {

      final downloadUrl = await snapshot.ref.getDownloadURL();

      return ScanImageUploadResult(

        downloadUrl: downloadUrl,

        storageObjectPath: objectPath,

      );

    } on FirebaseException catch (e) {

      if (e.code == 'object-not-found') {

        throw FirebaseException(

          plugin: 'firebase_storage',

          code: 'storage-not-configured',

          message:

              'Firebase Storage is not set up. Enable Storage in Firebase Console, '

              'then run: firebase deploy --only storage',

        );

      }

      rethrow;

    }

  }



  Future<Uint8List?> downloadBytes({required String objectPath}) async {

    try {

      final ref = _storage.ref(objectPath);

      return await ref.getData(_maxImageBytes);

    } on FirebaseException catch (e) {

      if (e.code == 'object-not-found') return null;

      rethrow;

    }

  }



  /// Upload raw image bytes (works on Android, iOS, and Web).

  Future<String> uploadProfileImageBytes({

    required String uid,

    required Uint8List bytes,

    String filename = 'profile.jpg',

    String contentType = 'image/jpeg',

  }) async {

    final ref = profileImageRef(uid, filename: filename);

    await ref.putData(bytes, SettableMetadata(contentType: contentType));

    return ref.getDownloadURL();

  }



  Future<void> deleteProfileImage(String uid, {String filename = 'profile.jpg'}) async {

    try {

      await profileImageRef(uid, filename: filename).delete();

    } on FirebaseException catch (e) {

      if (e.code == 'object-not-found') return;

      rethrow;

    }

  }

}

