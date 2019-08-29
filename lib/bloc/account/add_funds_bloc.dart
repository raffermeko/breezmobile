import 'dart:async';
import 'dart:convert';

import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/logger.dart';
import 'package:breez/services/breezlib/breez_bridge.dart';
import 'package:breez/services/injector.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import "package:ini/ini.dart";
import 'package:rxdart/rxdart.dart';

import 'account_model.dart';
import 'moonpay_order.dart';

class AddFundsBloc {
  static const String ACCOUNT_SETTINGS_PREFERENCES_KEY = "account_settings";
  static const String PENDING_MOONPAY_ORDER_KEY = "pending_moonpay_order";
  String _moonPayURL;

  final _addFundRequestController = new StreamController<void>();

  Sink<void> get addFundRequestSink => _addFundRequestController.sink;

  final _addFundResponseController = new StreamController<AddFundResponse>();

  Stream<AddFundResponse> get addFundResponseStream => _addFundResponseController.stream;

  final _moonPayOrderController = new BehaviorSubject<MoonpayOrder>();

  Stream<MoonpayOrder> get moonPayOrderStream => _moonPayOrderController.stream;

  Sink<MoonpayOrder> get moonPayOrderSink => _moonPayOrderController.sink;

  AddFundsBloc(String userID) {
    ServiceInjector injector = ServiceInjector();
    BreezBridge breezLib = injector.breezBridge;
    _addFundRequestController.stream.listen((request) {
      _addFundResponseController.add(null);
      breezLib
          .addFundsInit(userID)
          .then((reply) => _addFundResponseController.add(new AddFundResponse(reply)))
          .catchError(_addFundResponseController.addError);
    }).onDone(_dispose);
    _listenAccountSettings(injector);
    _handleMoonpayOrders(injector);
  }

  String get moonPayURL => _moonPayURL;

  _listenAccountSettings(ServiceInjector injector) async {
    var preferences = await injector.sharedPreferences;
    var accountSettings = preferences.getString(ACCOUNT_SETTINGS_PREFERENCES_KEY);
    if (accountSettings != null) {
      Map<String, dynamic> settings = json.decode(accountSettings);
      if (settings["moonpayIpCheck"]) {
        _isIPMoonpayAllowed().then((isAllowed) {
          if (isAllowed) _createMoonpayUrl();
        });
      } else {
        _createMoonpayUrl();
      }
    }
  }

  Future<bool> _isIPMoonpayAllowed() async {
    var response = await http.get("https://api.moonpay.io/v2/ip_address");
    if (response.statusCode != 200) {
      log.severe('moonpay response error: ${response.body.substring(0, 100)}');
      throw "Service Unavailable. Please try again later.";
    }
    return jsonDecode(response.body)['isAllowed'];
  }

  Future _createMoonpayUrl() async {
    Config config = await _readConfig();
    String baseUrl = config.get("MoonPay Parameters", 'baseUrl');
    String apiKey = config.get("MoonPay Parameters", 'apiKey');
    String currencyCode = config.get("MoonPay Parameters", 'currencyCode');
    String colorCode = config.get("MoonPay Parameters", 'colorCode');
    String redirectURL = config.get("MoonPay Parameters", 'redirectURL');
    _moonPayURL = "$baseUrl?apiKey=$apiKey&currencyCode=$currencyCode&colorCode=$colorCode&redirectURL=${Uri.encodeFull(redirectURL)}";
  }

  Future<Config> _readConfig() async {
    String lines = await rootBundle.loadString('conf/moonpay.conf');
    return Config.fromString(lines);
  }

  Future _handleMoonpayOrders(ServiceInjector injector) async {
    var preferences = await injector.sharedPreferences;
    var pendingOrder = preferences.getString(PENDING_MOONPAY_ORDER_KEY);
    if (pendingOrder != null) {
      Map<String, dynamic> settings = json.decode(pendingOrder);
      _moonPayOrderController.add(MoonpayOrder.fromJson(settings));
    }
    _moonPayOrderController.stream.listen((order) async {
      injector.sharedPreferences.then((preferences) {
        preferences.setString(PENDING_MOONPAY_ORDER_KEY, json.encode(order.toJson()));
      });
    });
  }

  _dispose() {
    _addFundRequestController.close();
    _addFundResponseController.close();
    _moonPayOrderController.close();
  }
}
