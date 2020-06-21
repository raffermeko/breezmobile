import 'package:breez/bloc/lnurl/lnurl_actions.dart';
import 'package:breez/bloc/lnurl/lnurl_bloc.dart';
import 'package:breez/bloc/lnurl/lnurl_model.dart';
import 'package:breez/routes/sync_progress_dialog.dart';
import 'package:breez/widgets/error_dialog.dart';
import 'package:breez/widgets/loader.dart';
import 'package:breez/widgets/route.dart';
import 'package:flutter/material.dart';

import '../routes/create_invoice/create_invoice_page.dart';

class LNURLHandler {
  final BuildContext _context;
  final LNUrlBloc lnurlBloc;
  ModalRoute _loaderRoute;
  bool _handlingRequest = false;

  LNURLHandler(this._context, this.lnurlBloc) {
    _listenLnLinks();
    lnurlBloc.lnurlStream.listen((response) {
      _handlingRequest = true;
      return executeLNURLResponse(this._context, this.lnurlBloc, response);
    }).onError((err) async {
      _setLoading(false);
      promptError(
          this._context,
          "Link Error",
          Text("Failed to process link: " + err.toString(),
              style: Theme.of(this._context).dialogTheme.contentTextStyle));
    });
  }

  void executeLNURLResponse(
      BuildContext context, LNUrlBloc lnurlBloc, dynamic response) {
    if (response.runtimeType == ChannelFetchResponse) {
      _openLNURLChannel(context, lnurlBloc, response);
    } else if (response.runtimeType == WithdrawFetchResponse) {
      _setLoading(false);
      Navigator.popUntil(context, (route) {
        return route.settings.name == "/";
      });

      Navigator.of(context).push(FadeInRoute(
        builder: (_) => CreateInvoicePage(lnurlWithdraw: response),
      ));
    } else {
      _setLoading(false);
      throw "Unsupported LNUrl";
    }
  }

  void _openLNURLChannel(BuildContext context, LNUrlBloc lnurlBloc,
      ChannelFetchResponse response) {
    _setLoading(false);
    var host = Uri.parse(response.callback).host;
    promptAreYouSure(context, "Open Channel",
            Text("Are you sure you want to open a channel with $host?"))
        .then((value) async {
      if (value) {
        var synced = await showDialog(
            context: context,
            useRootNavigator: false,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: SyncProgressDialog(closeOnSync: true),
                actions: <Widget>[
                  FlatButton(
                    child: Text("CANCEL",
                        style: Theme.of(context).primaryTextTheme.button),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                ],
              );
            });
        if (synced == true) {
          var loaderRoute = createLoaderRoute(context);
          Navigator.of(context).push(loaderRoute);
          var action =
              OpenChannel(response.uri, response.callback, response.k1);
          lnurlBloc.actionsSink.add(action);
          action.future.catchError((err) {
            promptError(context, "Open Channel Error",
                Text("Failed to open channel.\n" + err.toString()));
          }).whenComplete(() => Navigator.of(context).removeRoute(loaderRoute));
        }
      }
    });
  }

  void _listenLnLinks() {
    lnurlBloc.fetchLNUrlStateStream.listen((state) {
      if (state == fetchLNUrlState.started && !_handlingRequest) {
        _setLoading(true);
      } else {
        _setLoading(false);
      }
    });
  }

  _setLoading(bool visible) {
    if (visible && _loaderRoute == null) {
      _loaderRoute = createLoaderRoute(_context);
      Navigator.of(_context).push(_loaderRoute);
      return;
    }

    if (!visible && _loaderRoute != null) {
      Navigator.removeRoute(_context, _loaderRoute);
      _handlingRequest = false;
      _loaderRoute = null;
    }
  }
}
