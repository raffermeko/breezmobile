import 'dart:async';

import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/bloc/invoice/invoice_bloc.dart';
import 'package:breez/bloc/invoice/invoice_model.dart';
import 'package:breez/bloc/lnurl/lnurl_bloc.dart';
import 'package:breez/bloc/lnurl/lnurl_model.dart';
import 'package:breez/bloc/user_profile/breez_user_model.dart';
import 'package:breez/bloc/user_profile/currency.dart';
import 'package:breez/routes/charge/currency_wrapper.dart';
import 'package:breez/routes/charge/pos_sale_nfc_error.dart';
import 'package:breez/services/countdown.dart';
import 'package:breez/services/injector.dart';
import 'package:breez/widgets/compact_qr_image.dart';
import 'package:breez/widgets/flushbar.dart';
import 'package:breez/widgets/loader.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_extend/share_extend.dart';

class PosPaymentResult {
  final bool paid;
  final bool clearSale;
  final String nfcPaymentHash;

  const PosPaymentResult({
    this.paid = false,
    this.clearSale = false,
    this.nfcPaymentHash,
  });
}

class PosPaymentDialog extends StatefulWidget {
  final InvoiceBloc _invoiceBloc;
  final LNUrlBloc _lnUrlBloc;
  final BreezUserModel _user;
  final PaymentRequestModel paymentRequest;
  final double satAmount;
  final String _note;

  const PosPaymentDialog(
    this._invoiceBloc,
    this._lnUrlBloc,
    this._user,
    this.paymentRequest,
    this.satAmount,
    this._note,
  );

  @override
  _PosPaymentDialogState createState() {
    return _PosPaymentDialogState();
  }
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  CountDown _paymentTimer;
  StreamSubscription<Duration> _timerSubscription;
  StreamSubscription<PaymentRequestModel> _paidInvoiceSubscription;
  String _countdownString = "3:00";
  _PosWithdrawResponseInterceptor _withdrawResponseInterceptor;
  var _loadingNfc = false;
  Duration _expiration;

  @override
  void initState() {
    super.initState();

    _paymentTimer = CountDown(Duration(
      seconds: widget._user.cancellationTimeoutValue.toInt(),
    ));
    _timerSubscription = _paymentTimer.stream.listen((d) {
      setState(() {
        final texts = AppLocalizations.of(context);
        _expiration = d;
        _countdownString = texts.pos_dialog_clock(
          d.inMinutes.toRadixString(10),
          (d.inSeconds - (d.inMinutes * 60)).toRadixString(10).padLeft(2, "0"),
        );
      });
    }, onDone: () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(PosPaymentResult());
      }
    });

    _paidInvoiceSubscription =
        widget._invoiceBloc.paidInvoicesStream.listen((paidRequest) {
      setState(() {
        if (paidRequest.paymentHash == widget.paymentRequest.paymentHash) {
          Navigator.of(context).pop(PosPaymentResult(paid: true));
        }
      });
    });

    _withdrawResponseInterceptor = _PosWithdrawResponseInterceptor(this);
    widget._lnUrlBloc.withdrawFetchResponseInterceptor = _withdrawResponseInterceptor;
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    _paidInvoiceSubscription?.cancel();
    widget._lnUrlBloc.withdrawFetchResponseInterceptor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountBloc = AppBlocsProvider.of<AccountBloc>(context);
    return StreamBuilder<AccountModel>(
      stream: accountBloc.accountStream,
      builder: (context, snapshot) {
        final account = snapshot.data;
        if (account == null) {
          return Loader();
        }

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20.0, 22.0, 0.0, 8.0),
          title: _buildDialogTitle(context, account),
          contentPadding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
          content: _buildWaitingPayment(context, account),
        );
      },
    );
  }

  Widget _buildDialogTitle(
    BuildContext context,
    AccountModel account,
  ) {
    final texts = AppLocalizations.of(context);
    final themeData = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            texts.pos_dialog_title,
            style: themeData.dialogTheme.titleTextStyle,
          ),
        ),
        Row(
          children: <Widget>[
            IconButton(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(14.0, 8.0, 2.0, 8.0),
              icon: Icon(IconData(0xe917, fontFamily: 'icomoon')),
              color: themeData.primaryTextTheme.button.color,
              tooltip: texts.pos_dialog_share,
              onPressed: () => ShareExtend.share(
                "lightning:" + widget.paymentRequest.rawPayReq,
                "text",
              ),
            ),
            IconButton(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(2.0, 8.0, 14.0, 8.0),
              icon: Icon(IconData(0xe90b, fontFamily: 'icomoon')),
              color: themeData.primaryTextTheme.button.color,
              tooltip: texts.pos_dialog_invoice_copy,
              onPressed: () {
                ServiceInjector()
                    .device
                    .setClipboardText(widget.paymentRequest.rawPayReq);
                showFlushbar(
                  context,
                  message: texts.pos_dialog_invoice_copied,
                  duration: Duration(seconds: 3),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaitingPayment(
    BuildContext context,
    AccountModel account,
  ) {
    final themeData = Theme.of(context);
    final texts = AppLocalizations.of(context);

    final lspFee = widget.paymentRequest.lspFee;
    var saleCurrency = CurrencyWrapper.fromShortName(
        widget._user.posCurrencyShortName, account);
    var userCurrency = (saleCurrency.isFiat)
        ? CurrencyWrapper.fromBTC(Currency.SAT)
        : saleCurrency;
    var priceInSaleCurrency = "";
    if (saleCurrency.isFiat) {
      String salePrice = saleCurrency.format(
        widget.satAmount / saleCurrency.satConversionRate,
        includeCurrencySymbol: true,
        removeTrailingZeros: true,
      );
      priceInSaleCurrency =
          saleCurrency.rtl ? "($salePrice) " : " ($salePrice)";
    }

    return SingleChildScrollView(
      child: ListBody(
        children: <Widget>[
          Text(
            userCurrency.format(
                  widget.satAmount / userCurrency.satConversionRate,
                  includeCurrencySymbol: true,
                ) +
                priceInSaleCurrency,
            textAlign: TextAlign.center,
            style: themeData.primaryTextTheme.headline4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                height: 230.0,
                width: 230.0,
                child: _loadingNfc
                    ? Loader()
                    : CompactQRImage(
                        data: widget.paymentRequest.rawPayReq,
                      ),
              ),
            ),
          ),
          lspFee == 0
              ? SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    texts.pos_dialog_setup_fee(
                      Currency.SAT.format(lspFee),
                      account.fiatCurrency.format(lspFee),
                    ),
                    textAlign: TextAlign.center,
                    style: themeData.primaryTextTheme.headline4,
                  ),
                ),
          Text(
            _countdownString,
            textAlign: TextAlign.center,
            style: themeData.primaryTextTheme.headline4.copyWith(
              fontSize: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: _actionsWidget(context),
          ),
        ],
      ),
    );
  }

  Widget _actionsWidget(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _clearSaleButton(context),
        _cancelButton(context),
      ],
    );
  }

  Widget _clearSaleButton(BuildContext context) {
    final themeData = Theme.of(context);
    final texts = AppLocalizations.of(context);

    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 16.0),
      ),
      child: Text(
        texts.pos_dialog_clear_sale,
        textAlign: TextAlign.center,
        style: themeData.primaryTextTheme.button,
      ),
      onPressed: () {
        Navigator.of(context).pop(PosPaymentResult(clearSale: true));
      },
    );
  }

  Widget _cancelButton(BuildContext context) {
    final themeData = Theme.of(context);
    final texts = AppLocalizations.of(context);

    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 16.0),
      ),
      child: Text(
        texts.pos_dialog_cancel,
        textAlign: TextAlign.center,
        style: themeData.primaryTextTheme.button,
      ),
      onPressed: () {
        Navigator.of(context).pop(PosPaymentResult());
      },
    );
  }

  void _nfcWithdrawStarted() {
    if (mounted) {
      setState(() {
        _loadingNfc = true;
      });
    }
  }

  void _nfcWithdrawFinished({String error, String paymentHash}) {
    if (mounted) {
      setState(() {
        _loadingNfc = false;
      });
      if (error != null) {
        showFlushbar(context, message: error);
      } else {
        Navigator.of(context).pop(PosPaymentResult(
          paid: true,
          nfcPaymentHash: paymentHash,
        ));
      }
    }
  }
}

class _PosWithdrawResponseInterceptor extends WithdrawResponseInterceptor {
  final _PosPaymentDialogState state;

  _PosWithdrawResponseInterceptor(this.state);

  @override
  void intercept(WithdrawFetchResponse response) {
    final context = state.context;
    final satAmount = state.widget.satAmount;
    final texts = AppLocalizations.of(context);
    if (response.minAmount.toDouble() > satAmount ||
        response.maxAmount.toDouble() < satAmount) {
      showDialog(
        context: context,
        builder: (_) => PosSaleNfcError(
          texts.pos_payment_nfc_range_error(
            Currency.SAT.format(response.minAmount, includeDisplayName: false),
            Currency.SAT.format(response.maxAmount),
          ),
        ),
      );
    } else {
      _withdraw(response);
    }
  }

  void _withdraw(WithdrawFetchResponse response) {
    state._nfcWithdrawStarted();

    final expiration = state._expiration;
    if (expiration == null) {
      final texts = AppLocalizations.of(state.context);
      state._nfcWithdrawFinished(
        error: texts.payment_error_payment_timeout_exceeded,
      );
    }

    final invoiceBloc = state.widget._invoiceBloc;
    invoiceBloc.paidNfcSalesStream.listen((paid) {
      state._nfcWithdrawFinished(paymentHash: paid.paymentHash);
    }).onError((error) {
      state._nfcWithdrawFinished(error: error.toString());
    });

    invoiceBloc.actionsSink.add(
      NfcSaleRequestModel(
        state.widget._user.avatarURL,
        state.widget._note,
        state.widget._user.avatarURL,
        Int64(state.widget.satAmount.toInt()),
        Int64(expiration.inMilliseconds),
      ),
    );
  }
}
