@JS()
library dfinity_agent.js;

import 'package:dfinity_wallet/ic_api/web/service_api.dart';
import 'package:dfinity_wallet/ic_api/web/service_api.dart';
import 'package:dfinity_wallet/ic_api/web/web_ic_api.dart';
import 'package:js/js.dart';

import '../models.dart';
import 'js_utils.dart';

@JS("createHardwareWalletApi")
external Promise<HardwareWalletApi> createHardwareWalletApi(dynamic identity);

@JS("HardwareWalletApi")
class HardwareWalletApi {
  @JS("sendICPTs")
  external Promise<void> sendICPTs(
      String fromAccount, SendICPTsRequest request);

  @JS("showAddressAndPubKeyOnDevice")
  external Promise<void> showAddressAndPubKeyOnDevice();
}
