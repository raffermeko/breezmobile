import 'package:breez/bloc/account/account_model.dart';
import 'package:flutter/material.dart';

import 'payment_item.dart';

class PaymentsList extends StatefulWidget {
  final List<PaymentInfo> _payments;
  final double _itemHeight;
  final GlobalKey firstPaymentItemKey;
  final ScrollController scrollController;

  PaymentsList(this._payments, this._itemHeight, this.firstPaymentItemKey,
      this.scrollController);

  @override
  State<StatefulWidget> createState() {
    return PaymentsListState();
  }
}

class PaymentsListState extends State<PaymentsList> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(onScroll);
    super.dispose();
  }

  void onScroll() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SliverFixedExtentList(
      itemExtent: widget._itemHeight,
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        return PaymentItem(widget._payments[index], index, 0 == index,
            widget.firstPaymentItemKey, widget.scrollController);
      }, childCount: widget._payments.length),
    );
  }
}
