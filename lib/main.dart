import 'dart:ui';
import 'dart:io' show Platform;
import 'package:breez/routes/user/get_refund/get_refund_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:breez/routes/user/connect_to_pay/connect_to_pay_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breez/bloc/app_blocs.dart';
import 'package:breez/bloc/user_profile/breez_user_model.dart';
import 'package:breez/bloc/bloc_widget_connector.dart';
import 'package:breez/logger.dart';
import 'package:breez/routes/shared/splash_page.dart';
import 'package:breez/routes/shared/initial_walkthrough.dart';
import 'package:breez/routes/shared/dev/dev.dart';
import 'package:breez/routes/user/activate_card/activate_card_page.dart';
import 'package:breez/routes/user/add_funds/add_funds_page.dart';
import 'package:breez/routes/user/home/home_page.dart';
import 'package:breez/routes/user/order_card/order_card_page.dart';
import 'package:breez/routes/user/withdraw_funds/withdraw_funds_page.dart';
import 'package:breez/widgets/static_loader.dart';
import 'package:breez/widgets/route.dart';
import 'package:breez/routes/user/pay_nearby/pay_nearby_page.dart';
import 'package:breez/routes/user/pay_nearby/pay_nearby_complete.dart';
import 'package:breez/routes/user/create_invoice/create_invoice_page.dart';
import 'package:breez/theme_data.dart' as theme;

AppBlocs blocs = AppBlocs();
void main() {
  BreezLogger();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  initializeDateFormatting(Platform.localeName, null);
  runApp(BlocProvider<AppBlocs>(blocs, UserLoaderWidget(blocs)));
}

class UserLoaderWidget extends StatelessWidget {
  final AppBlocs _blocs;
  UserLoaderWidget(this._blocs);

  @override
  Widget build(BuildContext context) {
    return new StreamBuilder<BreezUserModel>(
        stream: _blocs.userProfileBloc.userStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return StaticLoader();
          }

          return BreezApp(_blocs, snapshot.data);
        });
  }
}

class BreezApp extends StatefulWidget {
  final AppBlocs _blocs;
  final BreezUserModel _userModel;

  BreezApp(this._blocs, this._userModel);

  @override
  State<StatefulWidget> createState() {
    return new BreezAppState();
  }
}

class BreezAppState extends State<BreezApp> {
  GlobalKey<NavigatorState> _navigatorKey = new GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget._blocs.connectPayBloc.sessionInvites.listen((sessionLink) async {
      await widget._blocs.connectPayBloc.terminateCurrentSession();      
      _navigatorKey.currentState.push(FadeInRoute(builder: (_) => new ConnectToPayPage(sessionLink)));         
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Breez',
      theme: ThemeData(
        brightness: Brightness.dark,
        accentColor: Color(0xFFffffff),
        dialogBackgroundColor: Colors.white,
        primaryColor: Color.fromRGBO(255, 255, 255, 1.0),
        textSelectionColor: Color.fromRGBO(255, 255, 255, 0.5),
        textSelectionHandleColor: Color(0xFF0085fb),
        dividerColor: Color(0x33ffffff),
        errorColor: theme.errorColor,
        canvasColor: Color.fromRGBO(5, 93, 235, 1.0),
        fontFamily: 'IBMPlexSansRegular',
        cardColor: Color.fromRGBO(5, 93, 235, 1.0),
      ),
      initialRoute: widget._userModel.registered ? null : '/splash',
      home: new Home(widget._blocs.accountBloc, widget._blocs.invoicesBloc),
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/home':
            return new FadeInRoute(
              builder: (_) => new Home(widget._blocs.accountBloc, widget._blocs.invoicesBloc),
              settings: settings,
            );
          case '/intro':
            return new FadeInRoute(
              builder: (_) => new InitialWalkthroughPage(widget._blocs.userProfileBloc, false),
              settings: settings,
            );
          case '/order_card':
            return new FadeInRoute(
              builder: (_) => new OrderCardPage(showSkip: false),
              settings: settings,
            );
          case '/order_card?skip=true':
            return new FadeInRoute(
              builder: (_) => new OrderCardPage(showSkip: true),
              settings: settings,
            );
          case '/add_funds':
            return new FadeInRoute(
              builder: (_) => new AddFundsPage(widget._userModel),
              settings: settings,
            );
          case '/withdraw_funds':
            return new FadeInRoute(
              builder: (_) => new WithdrawFundsPage(),
              settings: settings,
            );
          case '/get_refund':
            return new FadeInRoute(
              builder: (_) => new GetRefundPage(),
              settings: settings,
            );
          case '/activate_card':
            return new FadeInRoute(
              builder: (_) => new ActivateCardPage(),
              settings: settings,
            );          
          case '/pay_nearby':
            return new FadeInRoute(
              builder: (_) => new PayNearbyPage(),
              settings: settings,
            );
          case '/pay_nearby_complete':
            return new FadeInRoute(
              builder: (_) => new PayNearbyComplete(),
              settings: settings,
            );
          case '/create_invoice':
            return new FadeInRoute(
              builder: (_) => new CreateInvoicePage(),
              settings: settings,
            );
          case '/developers':
            return new FadeInRoute(
              builder: (_) => new DevView(),
              settings: settings,
            );
          case '/splash':
            return new FadeInRoute(
              builder: (_) => new SplashPage(widget._userModel),
              settings: settings,
            );
          case '/connect_to_pay':
            return new FadeInRoute(
              builder: (_) => new ConnectToPayPage(null),
              settings: settings,
            );
        }
        assert(false);
      },
    );
  }
}
