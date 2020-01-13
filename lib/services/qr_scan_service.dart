import 'dart:async';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/services.dart';

class QRScanService {
  QRScanService();

  Future<String> scan() async {
    try {
      String result = "";
      await BarcodeScanner.scan().then((scanResult) async {
        if (scanResult == "GET_CLIPBOARD_DATA") {
          result = await _getClipboardData();
        } else {
          result = scanResult;
        }
      });
      return result;
    } on PlatformException catch (error) {
      throw error;
    }
  }

  Future<String> _getClipboardData() async {
    ClipboardData clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    return clipboardData.text;
  }
}
