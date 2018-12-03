import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/bloc/backup/backup_bloc.dart';

class EnableBackupDialog extends StatefulWidget {
  final BuildContext context;
  final BackupBloc backupBloc;

  EnableBackupDialog(this.context, this.backupBloc);

  @override
  EnableBackupDialogState createState() {
    return new EnableBackupDialogState();
  }
}

class EnableBackupDialogState extends State<EnableBackupDialog> {
  bool _isChecked = true;

  @override
  Widget build(BuildContext context) {
    return createEnableBackupDialog();
  }

  Widget createEnableBackupDialog() {
    return new AlertDialog(
      titlePadding: EdgeInsets.fromLTRB(24.0, 22.0, 0.0, 16.0),
      title: new Text(
        "Backup",
        style: theme.alertTitleStyle,
      ),
      contentPadding: EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          new Text(
            "If you want to be able to restore your funds in case this mobile device or this app are no longer available (e.g. lost or stolen device or app uninstall), you are required to backup your information.",
            style: theme.paymentRequestSubtitleStyle,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: new ListTile(
              contentPadding: const EdgeInsets.only(left: 0.0),
              leading: Checkbox(
                  activeColor: theme.BreezColors.blue[500],
                  value: _isChecked,
                  onChanged: (v) {
                    setState(() {
                      _isChecked = !_isChecked;
                    });
                  }),
              title: Text(
                "Don't prompt again",
                style: theme.paymentRequestSubtitleStyle,
              ),
            ),
          ),
          new Padding(padding: EdgeInsets.only(top: 24.0)),
          new Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              new SimpleDialogOption(
                onPressed: () => Navigator.pop(widget.context),
                child: new Text("LATER", style: theme.buttonStyle),
              ),
              new SimpleDialogOption(
                onPressed: (() {
                  Navigator.pop(widget.context);
                  widget.backupBloc.disableBackupPromptSink.add(_isChecked);
                  widget.backupBloc.backupNowSink.add(true);
                }),
                child: new Text("BACKUP NOW", style: theme.buttonStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}