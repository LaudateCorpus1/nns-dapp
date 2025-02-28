import 'package:nns_dapp/data/icp.dart';
import 'package:nns_dapp/ui/_components/constants.dart';
import 'package:nns_dapp/ui/_components/form_utils.dart';
import 'package:nns_dapp/ui/_components/responsive.dart';

import '../../../nns_dapp.dart';

class TransactionDetailsWidget extends StatelessWidget {
  final ICP amount;
  final ICPSource source;
  final String destination;

  const TransactionDetailsWidget(
      {Key? key,
      required this.amount,
      required this.source,
      required this.destination})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Center(
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TallFormDivider(),
            Center(
              child: BalanceDisplayWidget(
                amount: amount,
                amountSize:
                    Responsive.isDesktop(context) | Responsive.isTablet(context)
                        ? kCurrentBalanceSizeBig
                        : kCurrentBalanceSizeSmall,
                icpLabelSize: 0,
                amountLabelSuffix: " ICP",
              ),
            ),
            TallFormDivider(),
            Text("Source",
                style:
                    Responsive.isDesktop(context) | Responsive.isTablet(context)
                        ? context.textTheme.headline3
                        : context.textTheme.headline4),
            VerySmallFormDivider(),
            SelectableText(source.address,
                style:
                    Responsive.isDesktop(context) | Responsive.isTablet(context)
                        ? context.textTheme.bodyText1
                        : context.textTheme.bodyText2),
            TallFormDivider(),
            Text("Destination",
                style:
                    Responsive.isDesktop(context) | Responsive.isTablet(context)
                        ? context.textTheme.headline3
                        : context.textTheme.headline4),
            VerySmallFormDivider(),
            SelectableText(destination,
                style:
                    Responsive.isDesktop(context) | Responsive.isTablet(context)
                        ? context.textTheme.bodyText1
                        : context.textTheme.bodyText2),
            TallFormDivider(),
            Text("Transaction Fee (billed to source)",
                style:
                    Responsive.isDesktop(context) | Responsive.isTablet(context)
                        ? context.textTheme.headline3
                        : context.textTheme.headline4),
            VerySmallFormDivider(),
            Text(
                ICP.fromE8s(BigInt.from(TRANSACTION_FEE_E8S)).asString() +
                    " ICP",
                style: Responsive.isTablet(context)
                    ? context.textTheme.bodyText1
                    : context.textTheme.bodyText2),
            VerySmallFormDivider()
          ],
        ),
      ),
    ));
  }
}
