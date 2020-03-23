import 'dart:async';

import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/account/account_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PaymentFailedReportDialog extends StatefulWidget {
  final BuildContext context;
  final AccountBloc _accountBloc;

  PaymentFailedReportDialog(this.context, this._accountBloc);

  @override
  PaymentFailedReportDialogState createState() {
    return PaymentFailedReportDialogState();
  }
}

class PaymentFailedReportDialogState extends State<PaymentFailedReportDialog> {
  bool _doneAsk;
  AccountSettings _settings;
  StreamSubscription<AccountSettings> _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _settingsSubscription = widget._accountBloc.accountSettingsStream
        .listen((settings) => setState(() {
              _settings = settings;
            }));
  }

  @override
  void dispose() {
    _settingsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildFailureDialog();
  }

  Widget buildFailureDialog() {
    return Theme(
        data: Theme.of(context).copyWith(
          unselectedWidgetColor: Theme.of(context).canvasColor,
        ),
        child: AlertDialog(
          titlePadding: EdgeInsets.fromLTRB(24.0, 22.0, 0.0, 16.0),
          title: Text(
            "Failed Payment",
            style: Theme.of(context).dialogTheme.titleTextStyle,
          ),
          contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 24.0),
          content: _settings == null
              ? Container()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, right: 12.0),
                      child: Text(
                        "Sending failed payment details to Breez could help increase successful transactions rate.\nDo you want to send this failed payment details to Breez?",
                        style: Theme.of(context)
                            .primaryTextTheme
                            .headline3
                            .copyWith(fontSize: 16),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: <Widget>[
                          Theme(
                            data: Theme.of(context).copyWith(
                                unselectedWidgetColor:
                                    Theme.of(context).textTheme.button.color),
                            child: Checkbox(
                                activeColor: Theme.of(context).canvasColor,
                                value: _doneAsk ??
                                    _settings.failedPaymentBehavior !=
                                        BugReportBehavior.PROMPT,
                                onChanged: (v) {
                                  setState(() {
                                    _doneAsk = v;
                                  });
                                }),
                          ),
                          Text(
                            "Don't ask me again",
                            style: Theme.of(context)
                                .primaryTextTheme
                                .headline3
                                .copyWith(fontSize: 16),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
          actions: [
            SimpleDialogOption(
              onPressed: () {
                onSubmit(false);
                Navigator.pop(widget.context, false);
              },
              child:
                  Text("NO", style: Theme.of(context).primaryTextTheme.button),
            ),
            SimpleDialogOption(
              onPressed: (() async {
                onSubmit(true);
                Navigator.pop(widget.context, true);
              }),
              child:
                  Text("YES", style: Theme.of(context).primaryTextTheme.button),
            ),
          ],
        ));
  }

  void onSubmit(bool yesNo) {
    var dontAsk =
        _doneAsk ?? _settings.failedPaymentBehavior != BugReportBehavior.PROMPT;
    if (dontAsk) {
      widget._accountBloc.accountSettingsSink.add(_settings.copyWith(
          failedPaymentBehavior: yesNo
              ? BugReportBehavior.SEND_REPORT
              : BugReportBehavior.IGNORE));
    }
  }
}
