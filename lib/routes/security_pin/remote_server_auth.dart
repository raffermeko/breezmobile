import 'dart:convert';

import 'package:breez/bloc/tor/bloc.dart';
import 'package:breez/bloc/backup/backup_bloc.dart';
import 'package:breez/bloc/backup/backup_model.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/routes/podcast/theme.dart';
import 'package:breez/routes/network/network.dart';
import 'package:breez/widgets/back_button.dart' as backBtn;
import 'package:breez/widgets/error_dialog.dart';
import 'package:breez/widgets/loader.dart';
import 'package:breez/widgets/route.dart';
import 'package:breez/widgets/single_button_bottom_bar.dart';
import 'package:breez/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:validators/validators.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

Future<RemoteServerAuthData> promptAuthData(
  BuildContext context, {
  restore = false,
}) {
  return Navigator.of(context).push<RemoteServerAuthData>(FadeInRoute(
    builder: (BuildContext context) {
      final backupBloc = AppBlocsProvider.of<BackupBloc>(context);
      final torBloc = AppBlocsProvider.of<TorBloc>(context);
      return withBreezTheme(
        context,
        RemoteServerAuthPage(backupBloc, torBloc, restore),
      );
    },
  ));
}

const String BREEZ_BACKUP_DIR = "DO_NOT_DELETE_Breez_Backup";

class RemoteServerAuthPage extends StatefulWidget {
  final String _title = "Remote Server";

  final BackupBloc _backupBloc;
  final TorBloc _torBloc;
  final bool restore;

  const RemoteServerAuthPage(this._backupBloc, this._torBloc, this.restore);

  @override
  State<StatefulWidget> createState() {
    return RemoteServerAuthPageState();
  }
}

class RemoteServerAuthPageState extends State<RemoteServerAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  bool failDiscoverURL = false;
  bool failAuthenticate = false;
  bool _passwordObscured = true;

  String appendPath(String uri, List<String> pathSegments) {
    var uriObject = Uri.parse(uri);
    uriObject = uriObject.replace(pathSegments: uriObject.pathSegments.toList()..addAll(pathSegments));
    return uriObject.toString();
  }

  @override
  void initState() {
    super.initState();
    widget._backupBloc.backupSettingsStream.first.then((value) {
      var data = value.remoteServerAuthData;
      if (data != null) {
        var backupDirPathSegments = data.breezDir.split("/");
        _urlController.text = data.url;
        if (backupDirPathSegments.length > 1) {
          backupDirPathSegments.removeLast();
          _urlController.text  = appendPath(data.url, backupDirPathSegments);
        }
        _userController.text = data.user;
        _passwordController.text = data.password;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final themeData = Theme.of(context);
    final nav = Navigator.of(context);

    return StreamBuilder<BackupSettings>(
      stream: widget._backupBloc.backupSettingsStream,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            leading: backBtn.BackButton(
              onPressed: () {
                nav.pop(null);
              },
            ),
            automaticallyImplyLeading: false,
            iconTheme: themeData.appBarTheme.iconTheme,
            textTheme: themeData.appBarTheme.textTheme,
            backgroundColor: themeData.canvasColor,
            title: Text(
              texts.remote_server_title,
              style: themeData.appBarTheme.textTheme.headline6,
            ),
            elevation: 0.0, toolbarTextStyle: themeData.appBarTheme.textTheme.bodyText2, titleTextStyle: themeData.appBarTheme.textTheme.headline6,
          ),
          body: SingleChildScrollView(
            reverse: true,
            child: StreamBuilder<BackupSettings>(
              stream: widget._backupBloc.backupSettingsStream,
              builder: (context, snapshot) {
                var settings = snapshot.data;
                if (settings == null) {
                  return Loader();
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formFieldUrl(context),
                          _formFieldUserName(context),
                          _formFieldPassword(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(bottom: 0.0),
            child: SingleButtonBottomBar(
              stickToBottom: true,
              text: widget.restore
                  ? texts.remote_server_action_restore
                  : texts.remote_server_action_save,
              onPressed: () async {
                Uri uri = Uri.parse(_urlController.text);
                var connectionWarningResponse = true;
                if (uri.scheme != 'https') {
                  connectionWarningResponse = await promptAreYouSure(
                    context,
                    texts.remote_server_warning_connection_title,
                    Text(
                      texts.remote_server_warning_connection_message,
                    ),
                  );
                }

                if (connectionWarningResponse) {
                  failDiscoverURL = false;
                  failAuthenticate = false;
                  if (_formKey.currentState.validate()) {
                    final newSettings = snapshot.data.copyWith(
                      remoteServerAuthData: RemoteServerAuthData(
                        uri.toString(),
                        _userController.text,
                        _passwordController.text,
                        BREEZ_BACKUP_DIR,
>>>>>>> b4a986c0a26276d150d2481ea166c71f9a92989a
                      ),
                    );
                  },
                ),
              ),
              bottomNavigationBar: Padding(
                padding: EdgeInsets.only(bottom: 0.0),
                child: SingleButtonBottomBar(
                  stickToBottom: true,
                  text: widget.restore ? "RESTORE" : "SAVE",
                  onPressed: () async {
                    var continueResponse = true;
                    Uri uri = Uri.parse(_urlController.text);
                    if (uri.host.endsWith('onion') &&
                        widget._torBloc.torConfig == null) {
                      continueResponse = await promptError(
                          context,
                          'Server URL',
                          Text(
                            'This URL has an onion domain. You probably need to first enable Tor in the Network settings.',
                            style:
                                Theme.of(context).dialogTheme.contentTextStyle,
                          ),
                          optionText: 'CONTINUE',
                          optionFunc: () {
                            Navigator.of(context).pop();
                          },
                          okText: 'SETTINGS',
                          okFunc: () {
                            // Navigator.of(context).pop();
                            Navigator.of(context).push(FadeInRoute(
                              builder: (_) =>
                                  withBreezTheme(context, NetworkPage()),
                            ));
                            // Navigator.of(context).popUntil((route) => route is RemoteServerAuthPage);
                            return false;
                          });
                    }

                    if (continueResponse) {
                      var connectionWarningResponse = true;
                      if (!uri.host.endsWith('.onion') &&
                          uri.scheme == 'http') {
                        connectionWarningResponse = await promptAreYouSure(
                            context,
                            "Connection Warning",
                            Text(
                                'Your connection to this remote server may not be a secured connection. Are you sure you want to continue?'));
                      }

                      if (connectionWarningResponse) {
                        var nav = Navigator.of(context);
                        failDiscoverURL = false;
                        failAuthenticate = false;

                        if (_formKey.currentState.validate()) {
                          var newSettings = snapshot.data.copyWith(
                              remoteServerAuthData: RemoteServerAuthData(
                                  _urlController.text,
                                  _userController.text,
                                  _passwordController.text,
                                  BREEZ_BACKUP_DIR));
                          var loader = createLoaderRoute(context,
                              message: "Testing connection", opacity: 0.8);
                          Navigator.push(context, loader);
                          discoverURL(newSettings.remoteServerAuthData)
                              .then((value) async {
                            nav.removeRoute(loader);

                            if (value.authError == DiscoverResult.SUCCESS) {
                              Navigator.pop(context, value.authData);
                            }
                            setState(() {
                              failDiscoverURL =
                                  value.authError == DiscoverResult.INVALID_URL;
                              failAuthenticate = value.authError ==
                                  DiscoverResult.INVALID_AUTH;
                            });
                            _formKey.currentState.validate();
                          }).catchError((err) {
                            nav.removeRoute(loader);
                            promptError(
                                context,
                                "Remote Server",
                                Text(
                                    "Failed to connect with the remote server, please check your settings."));
                          });
                        }
                      }
                    }
                  },
                ),
              ));
        });
  }

  Widget _formFieldUrl(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return TextFormField(
      controller: _urlController,
      minLines: 1,
      maxLines: 1,
      validator: (value) {
        final validURL = isURL(
          value,
          protocols: ['https', 'http'],
          requireProtocol: true,
          allowUnderscore: true,
        );
        if (!failDiscoverURL && validURL) {
          return null;
        }
        return texts.remote_server_error_invalid_url;
      },
      decoration: InputDecoration(
        hintText: texts.remote_server_server_url_hint,
        labelText: texts.remote_server_server_url_label,
      ),
      onEditingComplete: () => FocusScope.of(context).nextFocus(),
    );
  }

  Widget _formFieldUserName(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return TextFormField(
      validator: (value) {
        if (failAuthenticate) {
          return texts.remote_server_error_invalid_username_or_password;
        }
        return null;
      },
      controller: _userController,
      minLines: 1,
      maxLines: 1,
      decoration: InputDecoration(
        hintText: texts.remote_server_server_username_hint,
        labelText: texts.remote_server_server_username_label,
      ),
      onEditingComplete: () => FocusScope.of(context).nextFocus(),
    );
  }

  Widget _formFieldPassword(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return TextFormField(
      validator: (value) {
        if (failAuthenticate) {
          return texts.remote_server_error_invalid_username_or_password;
        }
        return null;
      },
      controller: _passwordController,
      minLines: 1,
      maxLines: 1,
      obscureText: _passwordObscured,
      decoration: InputDecoration(
        hintText: texts.remote_server_server_password_hint,
        labelText: texts.remote_server_server_password_label,
        suffixIcon: IconButton(
          icon: Icon(Icons.remove_red_eye),
          onPressed: () {
            setState(() {
              _passwordObscured = !_passwordObscured;
            });
          },
        ),
      ),
      onEditingComplete: () => FocusScope.of(context).nextFocus(),
    );
  }

  Future testConnection(RemoteServerAuthData authData) async {
    var client = webdav.newClient(
      authData.url,
      user: authData.user,
      password: authData.password,
      debug: true,
    );
    await client.ping();
  }

  // We try to discover the webdav url using a backward search where on every 
  // step we take the last path segment from the url and append it as a prefix
  // to the folder path.
  Future<DiscoveryResult> discoverURL(RemoteServerAuthData authData) async {
    RemoteServerAuthData testedAuthData = authData;    
    while(true) {
      var testedUrl = Uri.parse(testedAuthData.url);
      var result = await discoverURLInternal(testedAuthData);
      if (result.authError == DiscoverResult.SUCCESS ||
        result.authError == DiscoverResult.INVALID_AUTH) {
          return result;
      }
            
      List<String> pathSegments = testedUrl.pathSegments.toList();

      // if we reached url origin then we fail.
      if (pathSegments.length == 0) {
        return DiscoveryResult(testedAuthData, DiscoverResult.INVALID_URL);
      }
      String lastSegment = pathSegments.removeLast();
      
      // we couldn't use webdav with the current root, try differenet origin
      // and move the last path segment as the directory prefix
      testedAuthData = testedAuthData.copyWith(
        url: testedUrl.replace(pathSegments: pathSegments).toString(), 
        breezDir: lastSegment + "/" + testedAuthData.breezDir);
    }    
  }

  Future<DiscoveryResult> discoverURLInternal(RemoteServerAuthData authData) async {   

    var result = await testAuthData(authData);
    if (result == DiscoverResult.SUCCESS ||
        result == DiscoverResult.INVALID_AUTH) {
      return DiscoveryResult(authData, result);
    }

    var url = authData.url;
    if (!url.endsWith("/")) {
      url = url + "/";
    }
    final nextCloudURL = url + "remote.php/webdav";
    result = await testAuthData(authData.copyWith(url: nextCloudURL));
    if (result == DiscoverResult.SUCCESS ||
        result == DiscoverResult.INVALID_AUTH) {
      return DiscoveryResult(authData.copyWith(url: nextCloudURL), result);
    }
    return DiscoveryResult(authData, result);
  }

  Future<DiscoverResult> testAuthData(RemoteServerAuthData authData) async {
    log.info('remote_server_auth.dart: testAuthData');
    try {
      await widget._backupBloc
          .testAuth(BackupSettings.remoteServerBackupProvider, authData);

      /*
      // findProxy will only work for HTTPS but will not work for onion hidden services or HTTP
      // because it does not support SOCKS. It it did we could do something like this:
      if (widget._torBloc.torConfig != null) {
        final http = widget._torBloc.torConfig.http;
        (client.c.httpClientAdapter as DefaultHttpClientAdapter)
            .onHttpClientCreate = (client) {
          client.findProxy = (uri) {
            log.info('client.findProxy: $uri');
            return 'PROXY localhost:${http}';
          };
        };
      }
      */

    } on SignInFailedException catch (e) {
      log.warning('remote_server_auth.dart: testAuthData: $e');
      return DiscoverResult.INVALID_AUTH;
    } on RemoteServerNotFoundException catch (e) {
      return DiscoverResult.INVALID_URL;
    }

    return DiscoverResult.SUCCESS;
  }
}

enum DiscoverResult {
  SUCCESS,
  INVALID_URL,
  INVALID_AUTH,
}

class DiscoveryResult {
  final RemoteServerAuthData authData;
  final DiscoverResult authError;

  const DiscoveryResult(
    this.authData,
    this.authError,
  );
}
