import 'dart:async';
import 'dart:developer';

import 'package:chat_app/core/enums/enums.dart';
import 'package:chat_app/core/models/user_model.dart';
import 'package:chat_app/core/other/base_viewmodel.dart';
import 'package:chat_app/core/services/database_service.dart';

class ChatListViewmodel extends BaseViewmodel {
  final DatabaseService _db;
  final UserModel _currentUser;
  StreamSubscription? _userStreamSubscription;

  ChatListViewmodel(this._db, this._currentUser) {
    fetchUsers();
  }

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];

  List<UserModel> get users => _users;
  List<UserModel> get filteredUsers => _filteredUsers;

  search(String value) {
    _filteredUsers =
        _users.where((e) => e.name!.toLowerCase().contains(value)).toList();
    notifyListeners();
  }

  fetchUsers() async {
    try {
      if (disposed) {
        log("Skipping fetchUsers because viewmodel is disposed");
        return;
      }
      
      setstate(ViewState.loading);
      
      // Cancel any existing subscription first
      await _userStreamSubscription?.cancel();
      _userStreamSubscription = null;
      
      // Set up a new stream subscription with error handling
      _userStreamSubscription = _db.fetchUserStream(_currentUser.uid!).listen(
        (data) {
          // Always check if disposed before updating state
          if (!disposed) {
            try {
              _users = data.docs.map((e) => UserModel.fromMap(e.data())).toList();
              _filteredUsers = users;
              notifyListeners();
            } catch (e) {
              log("Error processing user data: $e");
            }
          }
        },
        onError: (error) {
          log("Error in user stream: $error");
          if (!disposed) {
            setstate(ViewState.idle);
          }
        },
        onDone: () {
          log("User stream closed");
        },
      );
      
      if (!disposed) {
        setstate(ViewState.idle);
      }
    } catch (e) {
      log("Error fetching users: $e");
      if (!disposed) {
        setstate(ViewState.idle);
      }
    }
  }
  
  @override
  void dispose() {
    log("Disposing ChatListViewmodel");
    // Cancel the stream subscription when the viewmodel is disposed
    if (_userStreamSubscription != null) {
      _userStreamSubscription!.cancel();
      _userStreamSubscription = null;
    }
    super.dispose();
  }
}
