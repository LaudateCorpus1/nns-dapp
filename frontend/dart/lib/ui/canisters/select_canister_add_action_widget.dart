import 'package:nns_dapp/ui/transaction/wizard_overlay.dart';
import 'package:nns_dapp/ui/transaction/wizard_path_button.dart';
import '../../nns_dapp.dart';
import 'enter_canister_id_widget.dart';
import 'new_canister_cycles_widget.dart';
import 'select_cycles_origin_widget.dart';

class SelectCanisterAddActionWidget extends StatelessWidget {
  const SelectCanisterAddActionWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WizardPathButton(
                  title: "Create New Canister",
                  subtitle: "Create a new canister, to deploy your application",
                  onPressed: () async {
                    WizardOverlay.of(context).pushPage("Select ICP Source",
                        SelectCyclesOriginWidget(
                            onSelected: (account, context) {
                      WizardOverlay.of(context).pushPage(
                          "Enter Amount",
                          NewCanisterCyclesAmountWidget(
                            source: account,
                          ),
                          context);
                    }), context);
                  }),
              SizedBox(
                height: 24.0,
              ),
              WizardPathButton(
                  title: "Link Canister To Account",
                  subtitle: "Enter the id of a canister, to top up it's cycles",
                  onPressed: () {
                    WizardOverlay.of(context).pushPage(
                        "Attach Canister", EnterCanisterIdWidget(), context);
                  }),
              // SmallFormDivider(),
              // SizedBox(
              //   height: 50,
              // )
            ],
          ),
        ),
      ),
    );
  }
}
