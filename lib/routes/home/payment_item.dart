import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/utils/date.dart';
import 'package:breez/widgets/payment_details_dialog.dart';
import 'package:flutter/material.dart';

import 'flip_transition.dart';
import 'payment_item_avatar.dart';
import 'success_avatar.dart';

const DASHBOARD_MAX_HEIGHT = 176.25;
const DASHBOARD_MIN_HEIGHT = 70.0;
const FILTER_MAX_SIZE = 56.0;
const PAYMENT_LIST_ITEM_HEIGHT = 72.0;
const AVATAR_DIAMETER = 24.0;

class PaymentItem extends StatelessWidget {
  final PaymentInfo _paymentInfo;
  final int _itemIndex;
  final bool _firstItem;
  final GlobalKey firstPaymentItemKey;
  final ScrollController _scrollController;

  PaymentItem(this._paymentInfo, this._itemIndex, this._firstItem,
      this.firstPaymentItemKey, this._scrollController);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: ListTile(
              tileColor: theme.customData[theme.themeId].paymentListBgColor,
              leading: Opacity(
                // when the transaction list is fully expanded
                // set opacity the avatar of the item that's
                // no longer visible to transparent
                opacity: (_scrollController.offset -
                            (DASHBOARD_MAX_HEIGHT - DASHBOARD_MIN_HEIGHT) -
                            (PAYMENT_LIST_ITEM_HEIGHT * (_itemIndex + 1) -
                                FILTER_MAX_SIZE +
                                AVATAR_DIAMETER) >
                        0)
                    ? 0.0
                    : 1.0,
                child: Container(
                    height: PAYMENT_LIST_ITEM_HEIGHT,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: Offset(0.5, 0.5),
                            blurRadius: 5.0),
                      ],
                    ),
                    child: _buildPaymentItemAvatar()),
              ),
              key: _firstItem ? firstPaymentItemKey : null,
              title: Transform.translate(
                offset: Offset(-8, -2),
                child: Opacity(
                  // set title text to transparent when it leaves viewport
                  opacity: (_scrollController.offset -
                              (DASHBOARD_MAX_HEIGHT - DASHBOARD_MIN_HEIGHT) -
                              (PAYMENT_LIST_ITEM_HEIGHT * (_itemIndex + 1) -
                                  FILTER_MAX_SIZE +
                                  AVATAR_DIAMETER / 2) >
                          0)
                      ? 0.0
                      : 1.0,
                  child: Text(
                    _paymentInfo.title.replaceAll("\n", " "),
                    style: Theme.of(context).accentTextTheme.subtitle2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              subtitle: Transform.translate(
                offset: Offset(-8, -2),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        BreezDateUtils.formatMonthDate(
                            DateTime.fromMillisecondsSinceEpoch(
                                _paymentInfo.creationTimestamp.toInt() * 1000)),
                        style: Theme.of(context).accentTextTheme.caption,
                      ),
                      _paymentInfo.pending
                          ? Text(" (Pending)",
                              style: Theme.of(context)
                                  .accentTextTheme
                                  .caption
                                  .copyWith(
                                      color: theme.customData[theme.themeId]
                                          .pendingTextColor))
                          : SizedBox()
                    ]),
              ),
              trailing: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Opacity(
                            // set amount text to transparent when it leaves viewport
                            opacity: (_scrollController.offset -
                                        (DASHBOARD_MAX_HEIGHT -
                                            DASHBOARD_MIN_HEIGHT) -
                                        (PAYMENT_LIST_ITEM_HEIGHT *
                                                (_itemIndex + 1) -
                                            FILTER_MAX_SIZE +
                                            AVATAR_DIAMETER / 2) >
                                    0)
                                ? 0.0
                                : 1.0,
                            child: Text(
                              (_paymentInfo.type == PaymentType.SENT ||
                                          _paymentInfo.type ==
                                              PaymentType.WITHDRAWAL ||
                                          _paymentInfo.type ==
                                              PaymentType.CLOSED_CHANNEL
                                      ? "- "
                                      : "+ ") +
                                  _paymentInfo.currency.format(
                                      _paymentInfo.amount,
                                      includeDisplayName: false),
                              style:
                                  Theme.of(context).accentTextTheme.headline6,
                            ),
                          )
                        ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 7.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _paymentInfo.fee == 0 || _paymentInfo.pending
                                ? SizedBox()
                                : Text(
                                    "FEE " +
                                        _paymentInfo.currency.format(
                                            _paymentInfo.fee,
                                            includeDisplayName: false),
                                    style: Theme.of(context)
                                        .accentTextTheme
                                        .caption,
                                  ),
                          ]),
                    ),
                  ],
                ),
              ),
              onTap: () => showPaymentDetailsDialog(context, _paymentInfo),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentItemAvatar() {
    // Show Flip Transition if the payment item is created within last 10 seconds
    if (_createdWithin(Duration(seconds: 10))) {
      return PaymentItemAvatar(_paymentInfo, radius: 16);
    } else {
      return FlipTransition(
          PaymentItemAvatar(
            _paymentInfo,
            radius: 16,
          ),
          SuccessAvatar());
    }
  }

  bool _createdWithin(Duration duration) {
    return DateTime.fromMillisecondsSinceEpoch(
                _paymentInfo.creationTimestamp.toInt() * 1000)
            .difference(DateTime.fromMillisecondsSinceEpoch(
                DateTime.now().millisecondsSinceEpoch)) <
        -duration;
  }
}
