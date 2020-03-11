import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/pos_catalog/actions.dart';
import 'package:breez/bloc/pos_catalog/bloc.dart';
import 'package:breez/bloc/pos_catalog/model.dart';
import 'package:breez/bloc/user_profile/currency.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/widgets/flushbar.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'item_avatar.dart';

class CatalogItem extends StatelessWidget {
  final AccountModel accountModel;
  final PosCatalogBloc posCatalogBloc;
  final Item _itemInfo;
  final bool _lastItem;
  final Function(AccountModel accountModel, String symbol, Int64 itemPriceInSat)
      _addItem;

  CatalogItem(this.accountModel, this.posCatalogBloc, this._itemInfo,
      this._lastItem, this._addItem);

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.bottomCenter, children: <Widget>[
      Slidable(
        actionPane: SlidableDrawerActionPane(),
        actionExtentRatio: 0.25,
        secondaryActions: <Widget>[
          IconSlideAction(
            foregroundColor: Colors.white,
            color: Theme.of(context).primaryColorLight,
            icon: Icons.delete_forever,
            onTap: () {
              DeleteItem deleteItem = DeleteItem(_itemInfo.id);
              posCatalogBloc.actionsSink.add(deleteItem);
              deleteItem.future.catchError((err) => showFlushbar(context,
                  message: "Failed to delete ${_itemInfo.name}"));
            },
          ),
        ],
        key: Key(_itemInfo.id.toString()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
          child: ListTile(
            leading: ItemAvatar(_itemInfo.imageURL),
            title: Text(
              _itemInfo.name,
              style: theme.transactionTitleStyle
                  .copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RichText(
                        text: new TextSpan(
                          style: theme.transactionAmountStyle,
                          children: <InlineSpan>[
                            _itemInfo.currency == "SAT"
                                ? WidgetSpan(
                                    child: Container(
                                      height: 20,
                                      child: Center(
                                        child: Text(
                                            _formattedPrice().substring(0, 1),
                                            style: TextStyle(
                                                fontSize: 13.4,
                                                fontFamily: 'SAT')),
                                      ),
                                    ),
                                  )
                                : TextSpan(
                                    text: _formattedPrice().substring(0, 1),
                                  ),
                            TextSpan(
                              text: _formattedPrice().substring(1),
                            ),
                          ],
                        ),
                      ),
                    ]),
              ],
            ),
            onTap: () {
              _addItem(accountModel, _itemInfo.currency, _itemPriceInSat());
            },
          ),
        ),
      ),
      Divider(
        height: 0.0,
        color: _lastItem
            ? Color.fromRGBO(255, 255, 255, 0.0)
            : Color.fromRGBO(255, 255, 255, 0.12),
        indent: 72.0,
      ),
    ]);
  }

  String _formattedPrice({bool userInput = false, bool includeSymbol = true}) {
    if (Currency.fromSymbol(_itemInfo.currency) != null) {
      var currency = Currency.fromSymbol(_itemInfo.currency);
      return currency.format(currency.toSats(_itemInfo.price),
          fixedDecimals: false, useSymbol: true);
    } else {
      return accountModel
          .getFiatCurrencyByShortName(_itemInfo.currency)
          .formatFiat(_itemInfo.price, removeTrailingZeros: true);
    }
  }

  Int64 _itemPriceInSat() {
    return Currency.fromSymbol(_itemInfo.currency) != null
        ? Currency.fromSymbol(_itemInfo.currency).toSats(_itemInfo.price)
        : accountModel
            .getFiatCurrencyByShortName(_itemInfo.currency)
            .fiatToSat(_itemInfo.price);
  }
}
