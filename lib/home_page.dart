import 'dart:async';
import 'dart:io';

import 'package:anytime/ui/anytime_podcast_app.dart';
import 'package:anytime/ui/themes.dart';
import 'package:breez/bloc/account/account_actions.dart';
import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/account/add_fund_vendor_model.dart';
import 'package:breez/bloc/account/add_funds_bloc.dart';
import 'package:breez/bloc/backup/backup_bloc.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/bloc/connect_pay/connect_pay_bloc.dart';
import 'package:breez/bloc/invoice/invoice_bloc.dart';
import 'package:breez/bloc/lnurl/lnurl_bloc.dart';
import 'package:breez/bloc/lsp/lsp_bloc.dart';
import 'package:breez/bloc/lsp/lsp_model.dart';
import 'package:breez/bloc/reverse_swap/reverse_swap_bloc.dart';
import 'package:breez/bloc/user_profile/breez_user_model.dart';
import 'package:breez/bloc/user_profile/user_profile_bloc.dart';
import 'package:breez/routes/admin_login_dialog.dart';
import 'package:breez/routes/charge/pos_invoice.dart';
import 'package:breez/routes/home/bottom_actions_bar.dart';
import 'package:breez/routes/home/qr_action_button.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/theme_data.dart';
import 'package:breez/widgets/enter_payment_info_dialog.dart';
import 'package:breez/widgets/error_dialog.dart';
import 'package:breez/widgets/escher_dialog.dart';
import 'package:breez/widgets/fade_in_widget.dart';
import 'package:breez/widgets/flushbar.dart';
import 'package:breez/widgets/loader.dart';
import 'package:breez/widgets/loading_animated_text.dart';
import 'package:breez/widgets/lost_card_dialog.dart' as lostCard;
import 'package:breez/widgets/lsp_fee.dart';
import 'package:breez/widgets/navigation_drawer.dart';
import 'package:breez/widgets/payment_failed_report_dialog.dart';
import 'package:breez/widgets/route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import 'bloc/invoice/invoice_model.dart';
import 'bloc/user_profile/user_actions.dart';
import 'handlers/check_version_handler.dart';
import 'handlers/ctp_join_session_handler.dart';
import 'handlers/lnurl_handler.dart';
import 'handlers/received_invoice_notification.dart';
import 'handlers/showPinHandler.dart';
import 'handlers/sync_ui_handler.dart';
import 'routes/account_required_actions.dart';
import 'routes/connect_to_pay/connect_to_pay_page.dart';
import 'routes/home/account_page.dart';
import 'routes/no_connection_dialog.dart';
import 'routes/spontaneous_payment/spontaneous_payment_page.dart';

final GlobalKey firstPaymentItemKey = GlobalKey();
final ScrollController scrollController = ScrollController();
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class Home extends StatefulWidget {
  final AccountBloc accountBloc;
  final InvoiceBloc invoiceBloc;
  final UserProfileBloc userProfileBloc;
  final ConnectPayBloc ctpBloc;
  final BackupBloc backupBloc;
  final LSPBloc lspBloc;
  final ReverseSwapBloc reverseSwapBloc;
  final LNUrlBloc lnurlBloc;

  Home(this.accountBloc, this.invoiceBloc, this.userProfileBloc, this.ctpBloc,
      this.backupBloc, this.lspBloc, this.reverseSwapBloc, this.lnurlBloc);

  final List<DrawerItemConfig> _screens = List<DrawerItemConfig>.unmodifiable(
      [DrawerItemConfig("breezHome", "Breez", "")]);

  final Map<String, Widget> _screenBuilders = {};

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<Home> {
  String _activeScreen = "breezHome";
  Set _hiddenRoutes = Set<String>();
  StreamSubscription<String> _accountNotificationsSubscription;

  @override
  void initState() {
    super.initState();
    _registerNotificationHandlers();
    listenNoConnection(context, widget.accountBloc);
    _listenBackupConflicts();
    _listenWhitelistPermissionsRequest();
    _listenLSPSelectionPrompt();
    _listenPaymentResults();
    _hiddenRoutes.add("/get_refund");
    widget.accountBloc.accountStream.listen((acc) {
      setState(() {
        if (acc != null &&
            acc.swapFundsStatus.maturedRefundableAddresses.length > 0) {
          _hiddenRoutes.remove("/get_refund");
        } else {
          _hiddenRoutes.add("/get_refund");
        }
      });
    });

    widget.accountBloc.accountStream.listen((acc) {
      var activeAccountRoutes = [
        "/connect_to_pay",
        "/pay_invoice",
        "/create_invoice"
      ];
      Function addOrRemove =
          acc.connected ? _hiddenRoutes.remove : _hiddenRoutes.add;
      setState(() {
        activeAccountRoutes.forEach((r) => addOrRemove(r));
      });
    });
  }

  @override
  void dispose() {
    _accountNotificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AddFundsBloc addFundsBloc = BlocProvider.of<AddFundsBloc>(context);
    LSPBloc lspBloc = AppBlocsProvider.of<LSPBloc>(context);

    return StreamBuilder<BreezUserModel>(
        stream: widget.userProfileBloc.userStream,
        builder: (context, userSnapshot) {
          var user = userSnapshot.data;

          return StreamBuilder<AccountModel>(
              stream: widget.accountBloc.accountStream,
              builder: (context, accSnapshot) {
                var account = accSnapshot.data;
                if (account == null) {
                  return SizedBox();
                }
                return StreamBuilder<AccountSettings>(
                    stream: widget.accountBloc.accountSettingsStream,
                    builder: (context, settingsSnapshot) {
                      var settings = settingsSnapshot.data;
                      if (settings == null) {
                        return SizedBox();
                      }

                      return StreamBuilder<LSPStatus>(
                          stream: lspBloc.lspStatusStream,
                          builder: (context, lspSnapshot) {
                            return StreamBuilder<List<AddFundVendorModel>>(
                                stream: addFundsBloc.availableVendorsStream,
                                builder: (context, snapshot) {
                                  List<DrawerItemConfig> addFundsVendors = [];
                                  if (snapshot.data != null) {
                                    snapshot.data.forEach((v) {
                                      if (v.isAllowed) {
                                        var vendorDrawerConfig =
                                            DrawerItemConfig(v.route,
                                                v.shortName ?? v.name, v.icon,
                                                disabled: !v.enabled ||
                                                    v.requireActiveChannel &&
                                                        !account.connected,
                                                onItemSelected: (item) {
                                          if (!v.showLSPFee) {
                                            Navigator.of(context)
                                                .pushNamed(v.route);
                                            return;
                                          }
                                          promptLSPFeeAndNavigate(
                                              context,
                                              account,
                                              lspSnapshot.data.currentLSP,
                                              v.route);
                                        });

                                        addFundsVendors.add(vendorDrawerConfig);
                                      }
                                    });
                                  }
                                  var refundableAddresses = account
                                      .swapFundsStatus
                                      .maturedRefundableAddresses;
                                  var refundItems = <DrawerItemConfigGroup>[];
                                  if (refundableAddresses.length > 0) {
                                    refundItems = [
                                      DrawerItemConfigGroup([
                                        DrawerItemConfig("", "Get Refund",
                                            "src/icon/withdraw_funds.png",
                                            onItemSelected: (_) =>
                                                protectAdminRoute(context, user,
                                                    "/get_refund"))
                                      ])
                                    ];
                                  }

                                  var flavorItems = <DrawerItemConfigGroup>[];
                                  flavorItems = [
                                    DrawerItemConfigGroup([
                                      user.isPOS
                                          ? DrawerItemConfig(
                                              "/transactions",
                                              "Transactions",
                                              "src/icon/transactions.png")
                                          : DrawerItemConfig(
                                              "/marketplace",
                                              "Marketplace",
                                              "src/icon/ic_market.png",
                                              disabled: !account.connected)
                                    ])
                                  ];

                                  var posItem = <DrawerItemConfigGroup>[];
                                  posItem = [
                                    DrawerItemConfigGroup(user.isPOS
                                        ? [
                                            DrawerItemConfig(
                                                "", "POS", "src/icon/pos.png",
                                                onItemSelected: (_) {
                                              widget.userProfileBloc
                                                  .userActionsSink
                                                  .add(SetPOSFlavor(
                                                      !user.isPOS));
                                            },
                                                switchWidget: Switch(
                                                    activeColor: Colors.white,
                                                    value: user.isPOS,
                                                    onChanged: (_) {
                                                      protectAdminAction(
                                                          context, user, () {
                                                        var action =
                                                            SetPOSFlavor(false);
                                                        widget.userProfileBloc
                                                            .userActionsSink
                                                            .add(action);
                                                        return action.future;
                                                      });
                                                    })),
                                          ]
                                        : [
                                            DrawerItemConfig(
                                                "", "POS", "src/icon/pos.png",
                                                onItemSelected: (_) {
                                              if (!user.isPodcast) {
                                                widget.userProfileBloc
                                                    .userActionsSink
                                                    .add(SetPOSFlavor(
                                                        !user.isPOS));
                                              }
                                            },
                                                switchWidget: Switch(
                                                    inactiveThumbColor:
                                                        Colors.grey.shade400,
                                                    activeColor: Colors.white,
                                                    value: user.isPOS,
                                                    onChanged: !account
                                                                .connected ||
                                                            user.isPodcast
                                                        ? null
                                                        : (_) {
                                                            var action =
                                                                SetPOSFlavor(
                                                                    !user
                                                                        .isPOS);
                                                            widget
                                                                .userProfileBloc
                                                                .userActionsSink
                                                                .add(action);
                                                          })),
                                          ])
                                  ];

                                  var podcastItem = DrawerItemConfig(
                                      "", "Podcast", "src/icon/podcast.png",
                                      onItemSelected: (_) {
                                    if (!user.isPOS) {
                                      widget.userProfileBloc.userActionsSink
                                          .add(SetPodcastFlavor(
                                              !user.isPodcast));
                                    }
                                  },
                                      switchWidget: Switch(
                                          inactiveThumbColor:
                                              Colors.grey.shade400,
                                          activeColor: Colors.white,
                                          value: user.isPodcast,
                                          onChanged: user.isPOS
                                              ? null
                                              : (val) {
                                                  widget.userProfileBloc
                                                      .userActionsSink
                                                      .add(SetPodcastFlavor(
                                                          !user.isPodcast));
                                                }));

                                  var advancedFlavorItems =
                                      List<DrawerItemConfig>();
                                  advancedFlavorItems = user.isPOS
                                      ? [
                                          DrawerItemConfig("", "POS Settings",
                                              "src/icon/settings.png",
                                              onItemSelected: (_) =>
                                                  protectAdminRoute(context,
                                                      user, "/settings")),
                                        ]
                                      : [
                                          DrawerItemConfig(
                                              "/developers",
                                              "Developers",
                                              "src/icon/developers.png")
                                        ];

                                  return StreamBuilder<
                                          Future<DecodedClipboardData>>(
                                      stream: widget
                                          .invoiceBloc.decodedClipboardStream,
                                      builder: (context, snapshot) {
                                        return Container(
                                          height: MediaQuery.of(context)
                                              .size
                                              .height,
                                          width:
                                              MediaQuery.of(context).size.width,
                                          child: FadeInWidget(
                                            child: Scaffold(
                                                key: _scaffoldKey,
                                                appBar: AppBar(
                                                  brightness:
                                                      theme.themeId == "BLUE"
                                                          ? Brightness.light
                                                          : Theme.of(context)
                                                              .appBarTheme
                                                              .brightness,
                                                  centerTitle: false,
                                                  actions: <Widget>[
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              14.0),
                                                      child:
                                                          AccountRequiredActionsIndicator(
                                                              widget.backupBloc,
                                                              widget
                                                                  .accountBloc,
                                                              widget.lspBloc),
                                                    ),
                                                  ],
                                                  leading: IconButton(
                                                      icon: SvgPicture.asset(
                                                        "src/icon/hamburger.svg",
                                                        height: 24.0,
                                                        width: 24.0,
                                                        color: Theme.of(context)
                                                            .appBarTheme
                                                            .actionsIconTheme
                                                            .color,
                                                      ),
                                                      onPressed: () =>
                                                          _scaffoldKey
                                                              .currentState
                                                              .openDrawer()),
                                                  title: SvgPicture.asset(
                                                    "src/images/logo-color.svg",
                                                    height: 23.5,
                                                    width: 62.7,
                                                    color: Theme.of(context)
                                                        .appBarTheme
                                                        .color,
                                                    colorBlendMode:
                                                        BlendMode.srcATop,
                                                  ),
                                                  iconTheme: IconThemeData(
                                                      color: Color.fromARGB(
                                                          255, 0, 133, 251)),
                                                  backgroundColor: (user.isPOS)
                                                      ? Theme.of(context)
                                                          .backgroundColor
                                                      : theme
                                                          .customData[
                                                              theme.themeId]
                                                          .dashboardBgColor,
                                                  elevation: 0.0,
                                                ),
                                                drawer: Theme(
                                                  data: theme
                                                      .themeMap[user.themeId],
                                                  child: NavigationDrawer(
                                                      true,
                                                      [
                                                        ...refundItems,
                                                        _buildSendItems(
                                                            account,
                                                            snapshot,
                                                            context,
                                                            user,
                                                            settings),
                                                        DrawerItemConfigGroup([
                                                          DrawerItemConfig(
                                                            "/create_invoice",
                                                            "Receive via Invoice",
                                                            "src/icon/paste.png",
                                                          ),
                                                          ...addFundsVendors,
                                                        ],
                                                            groupTitle:
                                                                "Receive",
                                                            groupAssetImage:
                                                                "src/icon/receive-action.png",
                                                            withDivider: false),
                                                        ...flavorItems,
                                                        ...posItem,
                                                        DrawerItemConfigGroup(
                                                          [
                                                            podcastItem,
                                                          ],
                                                        ),
                                                        DrawerItemConfigGroup(
                                                            _filterItems([
                                                              DrawerItemConfig(
                                                                  "/fiat_currency",
                                                                  "Fiat Currencies",
                                                                  "src/icon/fiat_currencies.png"),
                                                              DrawerItemConfig(
                                                                  "/network",
                                                                  "Network",
                                                                  "src/icon/network.png"),
                                                              DrawerItemConfig(
                                                                  "/security",
                                                                  "Security & Backup",
                                                                  "src/icon/security.png"),
                                                              ...advancedFlavorItems,
                                                            ]),
                                                            groupTitle:
                                                                "Advanced",
                                                            groupAssetImage:
                                                                "src/icon/advanced.png"),
                                                      ],
                                                      _onNavigationItemSelected),
                                                ),
                                                bottomNavigationBar: user
                                                        .isWalletMode
                                                    ? BottomActionsBar(account,
                                                        firstPaymentItemKey)
                                                    : null,
                                                floatingActionButton:
                                                    user.isWalletMode
                                                        ? QrActionButton(
                                                            account,
                                                            firstPaymentItemKey)
                                                        : null,
                                                floatingActionButtonLocation:
                                                    FloatingActionButtonLocation
                                                        .centerDocked,
                                                body: widget._screenBuilders[
                                                        _activeScreen] ??
                                                    _homePage(user)),
                                          ),
                                        );
                                      });
                                });
                          });
                    });
              });
        });
  }

  DrawerItemConfigGroup _buildSendItems(
      AccountModel account,
      AsyncSnapshot<Future<DecodedClipboardData>> snapshot,
      BuildContext context,
      BreezUserModel user,
      AccountSettings settings) {
    List<DrawerItemConfig> itemConfigs = [];
    DrawerItemConfig pasteItem = DrawerItemConfig(
        "", "Paste Invoice or Node ID", "src/icon/paste.png",
        disabled: !account.connected, onItemSelected: (_) {
      protectAdminAction(context, user, () async {
        DecodedClipboardData clipboardData = await snapshot.data;
        if (clipboardData != null) {
          if (clipboardData.type == "invoice") {
            widget.invoiceBloc.decodeInvoiceSink.add(clipboardData.data);
          } else if (clipboardData.type == "nodeID") {
            Navigator.of(context).push(FadeInRoute(
              builder: (_) => SpontaneousPaymentPage(
                  clipboardData.data, firstPaymentItemKey),
            ));
          }
        } else {
          return showDialog(
              useRootNavigator: false,
              context: context,
              barrierDismissible: false,
              builder: (_) => EnterPaymentInfoDialog(
                  context, widget.invoiceBloc, firstPaymentItemKey));
        }
      });
    });
    DrawerItemConfig c2pItem = DrawerItemConfig(
        "", "Connect to Pay", "src/icon/connect_to_pay.png",
        disabled: !account.connected,
        onItemSelected: (_) =>
            protectAdminRoute(context, user, "/connect_to_pay"));
    DrawerItemConfig sendToBTCAddressItem = DrawerItemConfig(
        "", "Send to BTC Address", "src/icon/bitcoin.png",
        disabled: !account.connected,
        onItemSelected: (_) =>
            protectAdminRoute(context, user, "/withdraw_funds"));
    DrawerItemConfig escherItem = DrawerItemConfig(
        "", "Cash-Out via Escher", "src/icon/escher.png",
        disabled: !account.connected, onItemSelected: (_) {
      return showDialog(
          useRootNavigator: false,
          context: context,
          barrierDismissible: false,
          builder: (_) => EscherDialog(context, widget.accountBloc));
    });
    itemConfigs.add(pasteItem);
    itemConfigs.add(c2pItem);
    itemConfigs.add(sendToBTCAddressItem);

    if (settings.isEscherEnabled) {
      itemConfigs.add(escherItem);
    }

    return DrawerItemConfigGroup(itemConfigs,
        groupTitle: "Send",
        groupAssetImage: "src/icon/send-action.png",
        withDivider: true);
  }

  _homePage(BreezUserModel user) {
    if (user.isPodcast) {
      return AnytimeHomePage(
        topBarVisible: false,
        title: 'Anytime Podcast Player',
      );
    }
    return user.isPOS
        ? POSInvoice()
        : AccountPage(firstPaymentItemKey, scrollController);
  }

  _onNavigationItemSelected(String itemName) {
    if (widget._screens.map((sc) => sc.name).contains(itemName)) {
      setState(() {
        _activeScreen = itemName;
      });
    } else {
      if (itemName == "/lost_card") {
        showDialog(
            useRootNavigator: false,
            context: context,
            builder: (_) => lostCard.LostCardDialog(
                  context: context,
                ));
      } else {
        Navigator.of(context).pushNamed(itemName).then((message) {
          if (message != null && message.runtimeType == String) {
            showFlushbar(context, message: message);
          }
        });
      }
    }
  }

  void _registerNotificationHandlers() {
    InvoiceNotificationsHandler(
        context,
        widget.userProfileBloc,
        widget.accountBloc,
        widget.invoiceBloc.receivedInvoicesStream,
        firstPaymentItemKey,
        scrollController,
        _scaffoldKey);
    LNURLHandler(context, widget.lnurlBloc);
    CTPJoinSessionHandler(widget.userProfileBloc, widget.ctpBloc, this.context,
        (session) {
      Navigator.popUntil(context, (route) {
        return route.settings.name != "/connect_to_pay";
      });
      var ctpRoute = FadeInRoute(
          builder: (_) => ConnectToPayPage(session),
          settings: RouteSettings(name: "/connect_to_pay"));
      Navigator.of(context).push(ctpRoute);
    }, (e) {
      promptError(
          context,
          "Connect to Pay",
          Text(e.toString(),
              style: Theme.of(context).dialogTheme.contentTextStyle));
    });
    SyncUIHandler(widget.accountBloc, context);
    ShowPinHandler(widget.userProfileBloc, context);

    _accountNotificationsSubscription = widget
        .accountBloc.accountNotificationsStream
        .listen((data) => showFlushbar(context, message: data),
            onError: (e) => showFlushbar(context, message: e.toString()));
    widget.reverseSwapBloc.broadcastTxStream.listen((_) {
      showFlushbar(context,
          messageWidget: LoadingAnimatedText("Broadcasting your transaction",
              textStyle: theme.snackBarStyle, textAlign: TextAlign.left));
    });
    CheckVersionHandler(context, widget.userProfileBloc);
  }

  void _listenBackupConflicts() {
    widget.accountBloc.nodeConflictStream.listen((_) async {
      Navigator.popUntil(context, (route) {
        return route.settings.name == "/";
      });
      await promptError(
          context,
          "Configuration Error",
          Text(
              "Breez detected another device is running with the same configuration (probably due to restore). Breez cannot run the same configuration on more than one device. Please reinstall Breez if you wish to continue using Breez on this device.",
              style: Theme.of(context).dialogTheme.contentTextStyle),
          okText: "Exit Breez",
          okFunc: () => exit(0),
          disableBack: true);
    });
  }

  void _listenLSPSelectionPrompt() async {
    widget.lspBloc.lspPromptStream.first
        .then((_) => Navigator.of(context).pushNamed("/select_lsp"));
  }

  void _listenWhitelistPermissionsRequest() {
    widget.accountBloc.optimizationWhitelistExplainStream.listen((_) async {
      await promptError(
          context,
          "Background Synchronization",
          Text(
              "In order to support instantaneous payments, Breez needs your permission in order to synchronize the information while the app is not active. Please approve the app in the next dialog.",
              style: Theme.of(context).dialogTheme.contentTextStyle),
          okFunc: () =>
              widget.accountBloc.optimizationWhitelistRequestSink.add(null));
    });
  }

  void _listenPaymentResults() {
    widget.accountBloc.completedPaymentsStream.listen((fulfilledPayment) {
      if (!fulfilledPayment.cancelled &&
          !fulfilledPayment.ignoreGlobalFeedback) {
        scrollController.animateTo(scrollController.position.minScrollExtent,
            duration: Duration(milliseconds: 10), curve: Curves.ease);
        showFlushbar(context, message: "Payment was successfully sent!");
      }
    }, onError: (err) async {
      var error = err as PaymentError;
      if (error.ignoreGlobalFeedback) {
        return;
      }
      var accountSettings =
          await widget.accountBloc.accountSettingsStream.first;
      bool prompt =
          accountSettings.failedPaymentBehavior == BugReportBehavior.PROMPT;
      bool send = accountSettings.failedPaymentBehavior ==
          BugReportBehavior.SEND_REPORT;

      var accountModel = await widget.accountBloc.accountStream.first;
      var errorString = error.toDisplayMessage(accountModel.currency);
      showFlushbar(context, message: "$errorString");
      if (!error.validationError) {
        if (prompt) {
          send = await showDialog(
              useRootNavigator: false,
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  PaymentFailedReportDialog(context, widget.accountBloc));
        }

        if (send) {
          var sendAction = SendPaymentFailureReport(error.traceReport);
          widget.accountBloc.userActionsSink.add(sendAction);
          await Navigator.push(
              context,
              createLoaderRoute(context,
                  message: "Sending Report...",
                  opacity: 0.8,
                  action: sendAction.future));
        }
      }
    });
  }

  List<DrawerItemConfig> _filterItems(List<DrawerItemConfig> items) {
    return items.where((c) => !_hiddenRoutes.contains(c.name)).toList();
  }

  DrawerItemConfig get activeScreen {
    return widget._screens.firstWhere((screen) => screen.name == _activeScreen);
  }
}
