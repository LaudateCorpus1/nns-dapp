@JS()
library dfinity_agent.js;

import 'dart:convert';
import 'dart:js_util';

import 'package:dfinity_wallet/data/proposal_reward_status.dart';
import 'package:dfinity_wallet/data/topic.dart';
import 'package:dfinity_wallet/data/vote.dart';
import 'package:dfinity_wallet/ic_api/platform_ic_api.dart';
import 'package:dfinity_wallet/ic_api/web/proposal_sync_service.dart';
import 'package:dfinity_wallet/ic_api/web/transaction_sync_service.dart';
import 'package:js/js.dart';
import 'dart:html';

import '../../dfinity.dart';
import 'account_sync_service.dart';
import 'auth_api.dart';
import 'balance_sync_service.dart';
import 'js_utils.dart';
import 'service_api.dart';
import 'hardware_wallet_api.dart';
import 'neuron_sync_service.dart';
import 'package:dfinity_wallet/dfinity.dart';
import 'stringify.dart';

class PlatformICApi extends AbstractPlatformICApi {
  AuthApi? authApi;
  ServiceApi? serviceApi;
  AccountsSyncService? accountsSyncService;
  BalanceSyncService? balanceSyncService;
  TransactionSyncService? transactionSyncService;
  NeuronSyncService? neuronSyncService;
  ProposalSyncService? proposalSyncService;

  PlatformICApi(HiveBoxesWidget hiveBoxes) : super(hiveBoxes);

  @override
  void authenticate(BuildContext context) async {
    await hiveBoxes.authToken.clear();

    authAndBuildServices();
    // await context.boxes.authToken.put(WEB_TOKEN_KEY, AuthToken()..key = key);
    // print("Stored token ${context.boxes.authToken.get(WEB_TOKEN_KEY)?.key}");
    // authApi!.loginWithIdentityProvider(
    //     key, "http://" + window.location.host + "/index.html");
  }

  Future<void> authAndBuildServices() async {
    if (authApi == null) {
      authApi = await promiseToFuture(createAuthApi());
    }

    var identity = authApi!.tryGetIdentity();
    if (identity == null) {
      await promiseToFuture(authApi!.login());
    } else {
      buildServices(identity);
    }
  }

  final gatewayHost = "https://cdtesting.dfinity.network/";

  Future<void> buildServices(dynamic identity) async {
    if (serviceApi == null) {
      serviceApi = createServiceApi(gatewayHost, identity);

      accountsSyncService = AccountsSyncService(serviceApi!, hiveBoxes);
      balanceSyncService = BalanceSyncService(serviceApi!, hiveBoxes);
      transactionSyncService =
          TransactionSyncService(serviceApi: serviceApi!, hiveBoxes: hiveBoxes);
      neuronSyncService =
          NeuronSyncService(serviceApi: serviceApi!, hiveBoxes: hiveBoxes);
      proposalSyncService =
          ProposalSyncService(serviceApi: serviceApi!, hiveBoxes: hiveBoxes);
      print("syncing accounts");

      await accountsSyncService!.performSync();
      balanceSyncService!.syncBalances();
      transactionSyncService!.syncAccount(hiveBoxes.accounts.primary);
      neuronSyncService!.fetchNeurons();
    }
  }

  @override
  Future<void> acquireICPTs(
      {required String accountIdentifier, required BigInt doms}) async {
    await serviceApi!.acquireICPTs(accountIdentifier, doms).toFuture();
    await balanceSyncService!.syncBalances();
  }

  @override
  Future<void> createSubAccount({required String name}) async {
    await promiseToFuture(serviceApi!.createSubAccount(name)).then((value) {
      final json = jsonDecode(stringify(value));
      final res = json['Ok'];
      accountsSyncService!.storeSubAccount(res);
    });
  }

  @override
  Future<void> sendICPTs(
      {required String toAccount,
      required BigInt doms,
      int? fromSubAccount}) async {
    await promiseToFuture(serviceApi!.sendICPTs(SendICPTsRequest(
        to: toAccount, amount: doms.toJS, fromSubAccountId: fromSubAccount)));
    await Future.wait([
      balanceSyncService!.syncBalances(),
      transactionSyncService!.syncAccount(hiveBoxes.accounts.primary)
    ]);
  }

  @override
  Future<void> createNeuron(
      {required BigInt stakeInDoms, int? fromSubAccount}) async {
    await promiseToFuture(serviceApi!.createNeuron(CreateNeuronRequest(
        stake: stakeInDoms, fromSubAccountId: fromSubAccount)));
    await neuronSyncService!.fetchNeurons();
  }

  @override
  Future<void> startDissolving({required BigInt neuronId}) async {
    await promiseToFuture(serviceApi!
        .startDissolving(NeuronIdentifierRequest(neuronId: neuronId.toJS)));
    await neuronSyncService!.fetchNeurons();
  }

  @override
  Future<void> stopDissolving({required BigInt neuronId}) async {
    await promiseToFuture(serviceApi!
        .stopDissolving(NeuronIdentifierRequest(neuronId: neuronId.toJS)));
    await neuronSyncService!.fetchNeurons();
  }

  @override
  Future<void> disburse(
      {required BigInt neuronId,
      required BigInt doms,
      required String toAccountId}) async {
    final res = await promiseToFuture(serviceApi!.disburse(
        DisperseNeuronRequest(
            neuronId: neuronId.toJS,
            amount: doms.toJS,
            toAccountId: toAccountId)));
    print("disburse ${stringify(res)}");
    await fetchNeuron(neuronId: neuronId);
    balanceSyncService?.syncBalances();
  }

  @override
  Future<void> follow(
      {required BigInt neuronId,
      required Topic topic,
      required List<BigInt> followees}) async {
    final result = await promiseToFuture(serviceApi!.follow(FollowRequest(
        neuronId: toJSBigInt(neuronId.toString()),
        topic: topic.index,
        followees: followees.mapToList((e) => e.toJS))));
    print("follow ${stringify(result)}");

    await neuronSyncService!.fetchNeurons();
  }

  @override
  Future<void> increaseDissolveDelay(
      {required BigInt neuronId,
      required int additionalDissolveDelaySeconds}) async {
    print("before increaseDissolveDelay");
    await promiseToFuture(
        serviceApi!.increaseDissolveDelay(IncreaseDissolveDelayRequest(
      neuronId: neuronId.toJS,
      additionalDissolveDelaySeconds: additionalDissolveDelaySeconds,
    )));
    print("before getNeuron");
    await fetchNeuron(neuronId: neuronId);
    print("after getNeuron");
  }

  @override
  Future<void> registerVote(
      {required List<BigInt> neuronIds,
      required BigInt proposalId,
      required Vote vote}) async {
    final result = await Future.wait(neuronIds.map(
        (e) => promiseToFuture(serviceApi!.registerVote(RegisterVoteRequest(
              neuronId: e.toJS,
              proposal: proposalId.toJS,
              vote: vote.index,
            )))));
    print("registerVote ${stringify(result)}");
    await neuronSyncService!.fetchNeurons();
  }

  @override
  Future<void> fetchProposals(
      {required List<Topic> excludeTopics,
      required List<ProposalStatus> includeStatus,
      required List<ProposalRewardStatus> includeRewardStatus,
      Proposal? beforeProposal}) async {
    proposalSyncService?.fetchProposals(
        excludeTopics: excludeTopics,
        includeStatus: includeStatus,
        includeRewardStatus: includeRewardStatus,
        beforeProposal: beforeProposal);
  }

  @override
  Future<Neuron> fetchNeuron({required BigInt neuronId}) async {
    final res = await promiseToFuture(serviceApi!.getNeuron(neuronId.toJS));
    final neuronInfo = jsonDecode(stringify(res));
    print("get neuron response ${stringify(res)}");
    return neuronSyncService!.storeNeuron(neuronInfo);
  }

  @override
  Future<NeuronInfo> fetchNeuronInfo({required BigInt neuronId}) async {
    final res = await promiseToFuture(serviceApi!.getNeuron(neuronId.toJS));
    final neuronInfo = jsonDecode(stringify(res));
    print("Neuron info Response ${stringify(res)}");
    final nInfo = NeuronInfo.fromResponse(neuronInfo);
    print("nInfo ${nInfo}");
    return nInfo;
  }

  @override
  Future<void> createDummyProposals({required BigInt neuronId}) async {
    await promiseToFuture(
        serviceApi!.createDummyProposals(neuronId.toString()));
    await fetchProposals(
        excludeTopics: [],
        includeStatus: ProposalStatus.values,
        includeRewardStatus: ProposalRewardStatus.values);
  }

  @override
  Future<Proposal> fetchProposal({required BigInt proposalId}) async {
    final response =
        await promiseToFuture(serviceApi!.getProposalInfo(proposalId.toJS));
    final json = jsonDecode(stringify(response));
    print("proposal json ${stringify(response)}");
    final proposal = await proposalSyncService!.storeProposal(json);
    proposalSyncService!.linkProposalsToNeurons();
    return Proposal.empty();
  }

  @override
  Future<dynamic> connectToHardwareWallet() {
    return promiseToFuture(authApi!.connectToHardwareWallet());
  }

  @override
  Future<HardwareWalletApi> createHardwareWalletApi(
      {dynamic ledgerIdentity}) async {
    final identity = await promiseToFuture(authApi!.connectToHardwareWallet());
    print(identity);
    return HardwareWalletApi(gatewayHost, identity);
  }

  @override
  Future<void> test() async {
    await promiseToFuture(serviceApi!.integrationTest());
  }

  @override
  Future<void> registerHardwareWallet(
      {required String name, dynamic ledgerIdentity}) async {
    await promiseToFuture(
        serviceApi!.registerHardwareWallet(name, ledgerIdentity));
  }

  @override
  Future<void> refreshAccounts() async {
    await accountsSyncService!.performSync();
  }

  @override
  Future<Neuron> spawnNeuron({required BigInt neuronId}) async {
    print("SpawnRequest ${neuronId}");

    final spawnResponse = await promiseToFuture(serviceApi!
        .spawn(SpawnRequest(neuronId: neuronId.toJS, newController: null)));
    // print("spawnResponse " + stringify(spawnResponse));
    final createdNeuronId = spawnResponse.createdNeuronId.toString();
    await neuronSyncService!.fetchNeurons();
    return hiveBoxes.neurons.values
        .firstWhere((element) => element.identifier == createdNeuronId);
  }
}

@JS()
@anonymous
class IncreaseDissolveDelayRequest {
  external dynamic get neuronId;

  external num get additionalDissolveDelaySeconds;

  external factory IncreaseDissolveDelayRequest(
      {dynamic neuronId, num additionalDissolveDelaySeconds});
}

@JS()
@anonymous
class FollowRequest {
  external dynamic neuronId;
  external int topic;
  external List<dynamic> followees;

  external factory FollowRequest(
      {dynamic neuronId, int topic, List<dynamic> followees});
}

@JS()
@anonymous
class NeuronIdentifierRequest {
  external dynamic neuronId;

  external factory NeuronIdentifierRequest({dynamic neuronId});
}

@JS()
@anonymous
class CreateNeuronRequest {
  external dynamic stake;
  external int? fromSubAccountId;

  external factory CreateNeuronRequest({dynamic stake, int? fromSubAccountId});
}

@JS()
@anonymous
class DisperseNeuronRequest {
  external dynamic neuronId;
  external dynamic amount;
  external String toAccountId;

  external factory DisperseNeuronRequest(
      {dynamic neuronId, dynamic amount, String toAccountId});
}

@JS()
@anonymous
class SendICPTsRequest {
  external dynamic to;
  external dynamic amount;
  external int? fromSubAccountId;

  external factory SendICPTsRequest(
      {dynamic to, dynamic amount, int? fromSubAccountId});
}

@JS()
@anonymous
class RegisterVoteRequest {
  external dynamic neuronId;
  external dynamic proposal;
  external int vote;

  external factory RegisterVoteRequest(
      {dynamic neuronId, dynamic proposal, int vote});
}

@JS()
@anonymous
class SpawnRequest {
  external dynamic neuronId;
  external dynamic newController;

  external factory SpawnRequest({dynamic neuronId, dynamic newController});
}
