import 'package:async/async.dart';
import 'package:couchbase_lite/couchbase_lite.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  String dbName = "myDatabase";
  List<Future> pendingListeners = List();
  ListenerToken _replicatorListenerToken;
  Database database;
  Replicator replicator;

  Future<bool> login(String username, String password) async {
    try {
      database = await Database.initWithName(dbName);
      // Note wss://10.0.2.2:4984/my-database is for the android simulator on your local machine's couchbase database
      ReplicatorConfiguration config =
          ReplicatorConfiguration(database, "ws://localhost:4984/mobile-sample");
      config.replicatorType = ReplicatorType.pushAndPull;
      config.continuous = true;

      // Using self signed certificate
      // config.pinnedServerCertificate = "assets/cert-android.cer";
      
      config.authenticator = BasicAuthenticator("admin", "password");
      replicator = Replicator(config);

      replicator.addChangeListener((ReplicatorChange event) {
        if (event.status.error != null) {
          print("Error: " + event.status.error);
        }

        print(event.status.activity.toString());
      });

      await replicator.start();
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> logout() async {
    await Future.wait(pendingListeners);
    replicator.removeChangeListener(_replicatorListenerToken);
    _replicatorListenerToken =
        replicator.addChangeListener((ReplicatorChange event) async {
      if (event.status.activity == ReplicatorActivityLevel.stopped) {
        await database.close();
        await replicator.dispose();
        _replicatorListenerToken = null;
      }
    });
    await replicator.stop();
  }

  Future<Map<String, dynamic>> createDocument(Map<String, dynamic> map) async {
    var id = "appname::${Uuid().v1()}";
    
    try {
      await database.save(MutableDocument(map, id));
      var newDoc = Map<String, dynamic>.from(map);
      newDoc["id"] = id;
      return Future.value(newDoc);
    } on PlatformException {
      return null;
    }
  }

}
