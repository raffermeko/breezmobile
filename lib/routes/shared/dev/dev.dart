import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/services/permissions.dart';
import 'package:flutter/material.dart';
import 'package:breez/logger.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/widgets/back_button.dart' as backBtn;
import 'package:breez/widgets/lnd_bootstrap_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:breez/services/injector.dart';
import 'package:breez/services/breezlib/breez_bridge.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';
import 'package:flutter/gestures.dart';
import 'package:breez/routes/shared/dev/default_commands.dart';

final _cliInputController = TextEditingController();
final FocusNode _cliEntryFocusNode = FocusNode();
final FocusNode _runCommandButtonFocusNode = FocusNode();

class LinkTextSpan extends TextSpan {
  LinkTextSpan({TextStyle style, String command, String text})
      : super(
            style: style,
            text: text ?? command,
            recognizer: new TapGestureRecognizer()
              ..onTap = () {
                _cliInputController.text = command + " ";
                FocusScope
                    .of(_scaffoldKey.currentState.context)
                    .requestFocus(_cliEntryFocusNode);
              });
}

class Choice {
  const Choice({this.title, this.icon, this.function});

  final String title;
  final IconData icon;
  final Function function;
}

final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
final _formKey = GlobalKey<FormState>();

class DevView extends StatefulWidget {
  BreezBridge _breezBridge;
  Permissions _permissionsService;

  DevView() {
    ServiceInjector injector = new ServiceInjector();
    _breezBridge = injector.breezBridge;
    _permissionsService = injector.permissions;
  }

  void _select(Choice choice) {
    choice.function();
  }

  @override
  DevViewState createState() {
    return new DevViewState();
  }
}

class DevViewState extends State<DevView> {
  String _cliText = '';
  TextStyle _cliTextStyle = theme.smallTextStyle;

  var _richCliText = <TextSpan>[];

  bool _showDefaultCommands = true;

  @override
  void initState() {
    _richCliText = defaultCliCommandsText;
    super.initState();
  }

  void _sendCommand(String command) {
    FocusScope.of(context).requestFocus(new FocusNode());
    widget._breezBridge.sendCommand(command).then((reply) {
      setState(() {
        _showDefaultCommands = false;
        _cliTextStyle = theme.smallTextStyle;
        _cliText = reply;
        _richCliText = <TextSpan>[
          new TextSpan(text: _cliText),
        ];
      });
    }).catchError((error) {
      setState(() {
        _showDefaultCommands = false;
        _cliText = error;
        _cliTextStyle = theme.warningStyle;
        _richCliText = <TextSpan>[
          new TextSpan(text: _cliText),
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    AccountBloc accBloc = AppBlocsProvider.of<AccountBloc>(context);
    return StreamBuilder(
      stream: accBloc.accountSettingsStream,
      builder: (context, settingsSnapshot) {
        return new Scaffold(
          key: _scaffoldKey,
          appBar: new AppBar(
            iconTheme: theme.appBarIconTheme,
            textTheme: theme.appBarTextTheme,
            backgroundColor: Color.fromRGBO(5, 93, 235, 1.0),
            leading: backBtn.BackButton(),
            elevation: 0.0,
            actions: <Widget>[
              PopupMenuButton<Choice>(
                onSelected: widget._select,
                itemBuilder: (BuildContext context) {
                  return getChoices(accBloc, settingsSnapshot.data).map((Choice choice) {
                    return PopupMenuItem<Choice>(
                      value: choice,
                      child: Text(choice.title),
                    );
                  }).toList();
                },
              ),
            ],
            title: new Text(
              "Developers",
              style: theme.appBarTextStyle,
            ),
          ),
          body: new Column(mainAxisSize: MainAxisSize.max, children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: new Row(
                children: <Widget>[
                  new Flexible(
                      child: new TextField(
                    focusNode: _cliEntryFocusNode,
                    controller: _cliInputController,
                    decoration: InputDecoration(
                        hintText: 'Enter a command or use the links below'),
                    onSubmitted: (command) {
                      _sendCommand(command);
                    },
                  )),
                  new IconButton(
                    icon: new Icon(Icons.play_arrow),
                    tooltip: 'Run',
                    onPressed: () {
                      _sendCommand(_cliInputController.text);
                    },
                  ),
                  new IconButton(
                    icon: new Icon(Icons.clear),
                    tooltip: 'Clear',
                    onPressed: () {
                      setState(() {
                        _cliInputController.clear();
                        _showDefaultCommands = true;
                        _cliText = "";
                        _richCliText = defaultCliCommandsText;
                      });
                    },
                  ),
                ],
              ),
            ),
            new Expanded(
                flex: 1,
                child: new Container(
                  padding: new EdgeInsets.all(10.0),
                  child: new Container(
                    padding: _showDefaultCommands
                        ? new EdgeInsets.all(0.0)
                        : new EdgeInsets.all(2.0),
                    decoration: new BoxDecoration(
                        border: _showDefaultCommands ? null : new Border.all(
                            width: 1.0,
                            color: Color(0x80FFFFFF))),
                    child: new Column(
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        _showDefaultCommands
                            ? new Container()
                            : new Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  new IconButton(
                                    icon: new Icon(Icons.content_copy),
                                    tooltip: 'Copy to Clipboard',
                                    iconSize: 19.0,
                                    onPressed: () {
                                      Clipboard.setData(
                                          new ClipboardData(text: _cliText));
                                      _scaffoldKey.currentState
                                          .showSnackBar(new SnackBar(
                                        content: new Text(
                                          'Copied to clipboard.',
                                          style: theme.snackBarStyle,
                                        ),
                                        backgroundColor:
                                            theme.snackBarBackgroundColor,
                                        duration: new Duration(seconds: 2),
                                      ));
                                    },
                                  ),
                                  new IconButton(
                                    icon: new Icon(Icons.share),
                                    iconSize: 19.0,
                                    tooltip: 'Share',
                                    onPressed: () {
                                      Share.share(_cliText);
                                    },
                                  )
                                ],
                              ),
                        new Expanded(
                            child: new SingleChildScrollView(
                                child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: new Row(
                            children: <Widget>[
                              new Expanded(
                                  child: new RichText(
                                      text: new TextSpan(
                                          style: _cliTextStyle,
                                          children: _richCliText)))
                            ],
                          ),
                        )))
                      ],
                    ),
                  ),
                )),
            new LNDBootstrapProgress(),
          ]),
        );
      }
    );
  }

  List<Choice> getChoices(AccountBloc accBloc, AccountSettings settings){
    List<Choice> choices = <Choice>[
      Choice(
        title: 'Share Logs', 
        icon: Icons.share, 
        function: shareLog),
      Choice(
        title: 'Show Initial Screen',
        icon: Icons.phone_android,
        function: _gotoInitialScreen),
      Choice(
        title: 'Battery Optimization',
        icon: Icons.phone_android,
        function: _showOptimizationsSettings),
      Choice(
        title: '${settings.showConnectProgress ? "Hide" : "Show"} Connect Progress',
        icon: Icons.phone_android,
        function: (){
          toggleConnectProgress(accBloc, settings);
        }),
      Choice(
        title: 'Marketplace',
        icon: Icons.lock,
        function: _gotoBitrefillWidgetScreen),
    ];
    return choices;
  }  

  void _gotoInitialScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isFirstRun', true);
    Navigator
        .of(_scaffoldKey.currentState.context)
        .pushReplacementNamed("/splash");
  }

  void _showOptimizationsSettings() async {
    widget._permissionsService.requestOptimizationSettings();
  }

  void toggleConnectProgress(AccountBloc bloc, AccountSettings settings){
    bloc.accountSettingsSink.add(settings.copyWith(showConnectProgress: !settings.showConnectProgress));
  }

  void _gotoBitrefillWidgetScreen() async {
    _promptPassword();
  }

  Future _promptPassword() {
    return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new AlertDialog(
            contentPadding: EdgeInsets.only(left: 24.0, right: 24.0),
            title: new Text(
                "Enter credentials", style: theme.alertTitleStyle),
            content: new SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: new Container(
                    child: new TextFormField(
                      obscureText: true,
                      decoration:
                      new InputDecoration(
                        hintText: "Password",
                        hintStyle: theme.alertStyle,
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.black45,
                                style: BorderStyle.solid,
                                width: 2.0)),),
                      style: theme.alertStyle,
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        if (value.isEmpty) {
                          return "Please enter password.";
                        } else if (!_validatePassword(
                            value)) {
                          return "Invalid password.";
                        }
                      },
                    ),
                  ),)
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text("Cancel", style: theme.cancelButtonStyle),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              new FlatButton(
                child: new Text("OK", style: theme.buttonStyle),
                onPressed: () {
                  if (_formKey.currentState.validate()) {
                    Navigator
                        .of(_scaffoldKey.currentState.context)
                        .pushReplacementNamed("/marketplace");
                  }
                },
              ),
            ],
          );
        });
  }

  bool _validatePassword(String value) {
    if (value == "135642") {
      return true;
    }
    return false;
  }
}
