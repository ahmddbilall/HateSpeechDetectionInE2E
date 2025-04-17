import 'package:chat_app/core/enums/enums.dart';
import 'package:flutter/material.dart';

class BaseViewmodel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  bool _disposed = false;

  ViewState get state => _state;
  bool get disposed => _disposed;

  setstate(ViewState state) {
    _state = state;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
