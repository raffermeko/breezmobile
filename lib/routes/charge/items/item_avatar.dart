import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_advanced_networkimage/provider.dart';

class ItemAvatar extends StatelessWidget {
  final String avatarURL;
  final double radius;
  final bool useDecoration;

  ItemAvatar(this.avatarURL, {Key key, this.radius = 20.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (avatarURL != null && avatarURL.isNotEmpty) {
      if (Uri.tryParse(avatarURL)?.scheme?.startsWith("http") ?? false) {
        return _NetworkImageAvatar(avatarURL, radius);
      }
      if (avatarURL.startsWith("#")) {
        return _ColorAvatar(radius, avatarURL);
      }
      if (avatarURL.startsWith("icon:")) {
        return _IconAvatar(radius, avatarURL, useDecoration: useDecoration);
      }

      return _FileImageAvatar(radius, avatarURL);
    }

    return _UnknownAvatar(radius);
  }
}

class _UnknownAvatar extends StatelessWidget {
  final double radius;

  _UnknownAvatar(this.radius);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      child: Center(
        child: Icon(Icons.airplanemode_active, size: radius * 1.5),
      ),
    );
  }
}

class _ColorAvatar extends StatelessWidget {
  final double radius;
  final String color;

  _ColorAvatar(this.radius, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: fromHex(color),
        shape: BoxShape.circle,
      ),
    );
  }
}

Color fromHex(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class _FileImageAvatar extends StatelessWidget {
  final double radius;
  final String filePath;

  _FileImageAvatar(this.radius, this.filePath);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: radius * 2,
      width: radius * 2,
      decoration: new BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: FileImage(
            File(filePath),
          ),
        ),
      ),
    );
  }
}

class _NetworkImageAvatar extends StatelessWidget {
  final double radius;
  final String avatarURL;

  _NetworkImageAvatar(this.avatarURL, this.radius);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: AdvancedNetworkImage(avatarURL, useDiskCache: true),
    );
  }
}

class _IconAvatar extends StatelessWidget {
  final double radius;
  final String iconName;
  final bool useDecoration;

  _IconAvatar(this.radius, this.iconName, {this.useDecoration = false});

  @override
  Widget build(BuildContext context) {
    // TODO: Map Material Icons library
    Map<String, IconData> iconMapping = {
      'account_balance': Icons.account_balance,
      'map': Icons.map,
      'airline_seat_individual_suite': Icons.airline_seat_individual_suite,
      'attach_money': Icons.attach_money,
      'beach_access': Icons.beach_access,
      'brush': Icons.brush
    };
    String iconName = this.iconName.substring(5);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: useDecoration
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white, width: 1.0, style: BorderStyle.solid),
              image: DecorationImage(
                  colorFilter: ColorFilter.mode(
                      Theme.of(context).primaryColorLight, BlendMode.srcATop),
                  image: AssetImage("src/images/avatarbg.png"),
                  fit: BoxFit.cover))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            iconMapping[iconName],
            size: useDecoration ? radius : radius * 1.5,
          ),
        ],
      ),
    );
  }
}
