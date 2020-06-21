import 'dart:async';

import 'package:breez/services/breezlib/breez_bridge.dart';
import 'package:breez/services/breezlib/data/rpc.pbserver.dart';
import 'package:breez/services/injector.dart';
import 'package:breez/utils/retry.dart';
import 'package:rxdart/rxdart.dart';

import '../async_actions_handler.dart';
import 'lnurl_actions.dart';
import 'lnurl_model.dart';

enum fetchLNUrlState { started, completed }

class LNUrlBloc with AsyncActionsHandler {
  BreezBridge _breezLib;

  final _fetchLNUrlStateController =
      StreamController<fetchLNUrlState>.broadcast();
  Stream<fetchLNUrlState> get fetchLNUrlStateStream =>
      _fetchLNUrlStateController.stream;

  LNUrlBloc() {
    ServiceInjector injector = ServiceInjector();
    _breezLib = injector.breezBridge;

    registerAsyncHandlers({
      Fetch: _fetch,
      Withdraw: _withdraw,
      OpenChannel: _openChannel,
    });
    listenActions();
  }

  Stream get lnurlStream => Observable.merge([
        ServiceInjector().nfc.receivedLnLinks(),
        ServiceInjector().lightningLinks.linksNotifications,
      ])
          .where((l) => l.toLowerCase().startsWith("lightning:lnurl"))
          .asyncMap((l) {
        _fetchLNUrlStateController.add(fetchLNUrlState.started);
        return _breezLib.fetchLNUrl(l);
      }).map((response) {
        _fetchLNUrlStateController.add(fetchLNUrlState.completed);
        if (response.hasWithdraw()) {
          return WithdrawFetchResponse(response.withdraw);
        }
        if (response.hasChannel()) {
          return ChannelFetchResponse(response.channel);
        }

        return Future.error("Unsupported lnurl");
      });

  Future _fetch(Fetch action) async {
    LNUrlResponse res = await _breezLib.fetchLNUrl(action.lnurl);
    if (res.hasWithdraw()) {
      action.resolve(WithdrawFetchResponse(res.withdraw));
      return;
    }
    if (res.hasChannel()) {
      action.resolve(ChannelFetchResponse(res.channel));
      return;
    }
    throw "Unsupported LNUrl action";
  }

  Future _withdraw(Withdraw action) async {
    action.resolve(await _breezLib.withdrawLNUrl(action.bolt11Invoice));
  }

  Future _openChannel(OpenChannel action) async {
    var openResult = retry(
        () => _breezLib.connectDirectToLnurl(
            action.uri, action.k1, action.callback),
        tryLimit: 3,
        interval: Duration(seconds: 5));
    action.resolve(await openResult);
  }

  @override
  Future dispose() {
    _fetchLNUrlStateController.close();
    return super.dispose();
  }
}
