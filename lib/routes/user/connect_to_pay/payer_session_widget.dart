import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/connect_pay/connect_pay_model.dart';
import 'package:breez/bloc/connect_pay/payer_session.dart';
import 'package:breez/routes/user/connect_to_pay/amount_form.dart';
import 'package:breez/routes/user/connect_to_pay/peers_connection.dart';
import 'package:breez/routes/user/connect_to_pay/session_instructions.dart';
import 'package:breez/widgets/delay_render.dart';
import 'package:breez/widgets/loading_animated_text.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breez/theme_data.dart' as theme;

class PayerSessionWidget extends StatelessWidget {
  final PayerRemoteSession _currentSession;
  final AccountModel _account;
  final Function _onReset;

  PayerSessionWidget(this._currentSession, this._account, this._onReset);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentSessionState>(
        stream: _currentSession.paymentSessionStateStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }
          PaymentSessionState sessionState = snapshot.data;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              SessionInstructions(_PayerInstructions(sessionState, _account), actions: _getActions(sessionState), onAction: (action) => _onAction(context, action)),              
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0, bottom: 21.0, top: 25.0),
                child: PeersConnection(sessionState, onShareInvite: () {
                    _currentSession.sentInvitesSink.add(null);
                  }),
              ),
              waitingFormPayee(sessionState) ? Container() : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(50.0, 0.0, 50.0, 0.0),
                    child: DelayRender(
                      child: AmountForm(_account, sessionState, (amountToPay) => _currentSession.amountSink.add(amountToPay.toInt())),
                      duration: PaymentSessionState.connectionEmulationDuration),
                  ),
                  flex: 1)
            ],
          );
        });
  }

  bool waitingFormPayee(PaymentSessionState sessionState) {
    return !sessionState.payeeData.status.online && sessionState.payerData.amount == null || sessionState.payerData.amount != null;
  }

  _onAction(BuildContext context, String action){
    if (action == "Cancel Payment") {
      _onReset();
    }
  }

  _getActions(PaymentSessionState sessionState){
    if (sessionState.invitationSent && sessionState.payeeData.paymentRequest == null) {
      return ["Cancel Payment"];
    }
    return null;
  }
}

class _PayerInstructions extends StatelessWidget {
  final PaymentSessionState sessionState;
  final AccountModel _account;

  _PayerInstructions(this.sessionState, this._account);

  @override
  Widget build(BuildContext context) {
    var message = "";
    if (sessionState.paymentFulfilled) {
      message = "You've successfully paid " + _account.currency.format(Int64(sessionState.payerData.amount));
    } else if (sessionState.payerData.amount == null) {
      if (sessionState.payeeData.status.online) {
        message = '${sessionState.payeeData.userName} joined the session.\nPlease enter an amount and tap Pay to proceed.';
      } else if (!sessionState.invitationSent) {
        message = "Tap the Share button to share a link with a person that you want to pay.\nThen, please wait while this person clicks the link and joins the session.";
      } else {
        return LoadingAnimatedText("Waiting for someone to join this session", textStyle: theme.sessionNotificationStyle);
      }
    } else if (sessionState.payeeData.paymentRequest == null) {
      return LoadingAnimatedText('Waiting for ${sessionState.payeeData.userName} to approve your payment', textStyle: theme.sessionNotificationStyle);
    } else {
      message = "Sending payment...";
    }

    return Text(message, style: theme.sessionNotificationStyle);
  }
}
