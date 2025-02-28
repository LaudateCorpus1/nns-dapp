import 'package:nns_dapp/data/icp.dart';
import 'package:nns_dapp/data/topic.dart';
import 'package:universal_html/js_util.dart';
import '../../nns_dapp.dart';
import 'service_api.dart';
import 'dart:convert';
import 'stringify.dart';

class NeuronSyncService {
  final ServiceApi serviceApi;
  final HiveBoxesWidget hiveBoxes;

  NeuronSyncService({required this.serviceApi, required this.hiveBoxes});

  Future<void> sync({bool checkBalances = true}) async {
    print("[${DateTime.now()}] Syncing neurons with a query call...");
    await _sync(useUpdateCalls: false, checkBalances: false);

    print("[${DateTime.now()}] Syncing neurons with an update call...");
    _sync(useUpdateCalls: true, checkBalances: true)
        .then((_) => {print("[${DateTime.now()}] Syncing neurons complete.")});
  }

  Future<void> _sync(
      {required bool useUpdateCalls, bool checkBalances = true}) async {
    // This gets all neurons linked to the current user's principal, even those
    // with a stake of 0. If 'checkBalances' is true then we will query the
    // ledger for each neuron and refresh those whose stake does not match their
    // ledger balance. Neurons whose balances are too low are later discarded
    // during 'storeNeuron'.
    dynamic res =
        (await promiseToFuture(serviceApi.getNeurons(useUpdateCalls)));
    final string = stringify(res);
    dynamic response = (jsonDecode(string) as List<dynamic>).toList();
    response.forEach((e) => storeNeuron(e));

    // ignore: deprecated_member_use
    hiveBoxes.neurons.notifyChange();

    if (checkBalances) {
      _checkNeuronBalances(res);
    }
  }

  Neuron? storeNeuron(dynamic e) {
    final neuronId = e['neuronId'].toString();
    final Neuron neuron;
    if (!hiveBoxes.neurons.containsKey(neuronId)) {
      neuron = Neuron.empty();
      _updateNeuron(neuron, neuronId, e);
    } else {
      neuron = hiveBoxes.neurons[neuronId]!;
      _updateNeuron(neuron, neuronId, e);
    }
    if (neuron.cachedNeuronStake.asE8s() > BigInt.from(TRANSACTION_FEE_E8S)) {
      hiveBoxes.neurons[neuronId] = neuron;
      return neuron;
    } else {
      removeNeuron(neuronId);
      return null;
    }
  }

  void _updateNeuron(Neuron neuron, String neuronId, dynamic res) {
    neuron.id = neuronId;
    neuron.votingPower = ICP.fromE8s(res['votingPower'].toString().toBigInt);
    neuron.state = NeuronState.values[res['state'].toInt()];
    neuron.dissolveDelaySeconds =
        res['dissolveDelaySeconds'].toString().toInt();
    neuron.ageSeconds = res['ageSeconds'].toString().toInt();

    final fullNeuron = res['fullNeuron'];
    if (fullNeuron != null) {
      _parseFullNeuron(fullNeuron, neuron);
    }
    // ignore: deprecated_member_use
    hiveBoxes.neurons.notifyChange();
  }

  void removeNeuron(String neuronId) {
    hiveBoxes.neurons.remove(neuronId);
    // ignore: deprecated_member_use
    hiveBoxes.neurons.notifyChange();
  }

  void _parseFullNeuron(dynamic fullNeuron, Neuron neuron) {
    final dissolveState = fullNeuron['dissolveState'];
    if (dissolveState != null) {
      neuron.whenDissolvedTimestampSeconds =
          dissolveState['WhenDissolvedTimestampSeconds']?.toString();
    }
    neuron.cachedNeuronStake =
        ICP.fromE8s(fullNeuron['cachedNeuronStake'].toString().toBigInt);
    neuron.recentBallots = _parseRecentBallots(fullNeuron['recentBallots']);
    neuron.neuronFees =
        ICP.fromE8s(fullNeuron['neuronFees'].toString().toBigInt);
    neuron.maturityICPEquivalent =
        ICP.fromE8s(fullNeuron['maturityE8sEquivalent'].toString().toBigInt);
    neuron.createdTimestampSeconds =
        fullNeuron['createdTimestampSeconds'].toString();
    neuron.followees = _parseFollowees(fullNeuron['followees']);
    neuron.isCurrentUserController = fullNeuron['isCurrentUserController'];
    neuron.controller = fullNeuron['controller'];
    neuron.accountIdentifier = fullNeuron['accountIdentifier'];
    neuron.joinedCommunityFundTimestampSeconds = fullNeuron['joinedCommunityFundTimestampSeconds']?.toString().toBigInt;
    neuron.hotkeys = fullNeuron['hotKeys'].cast<String>();
  }

  List<BallotInfo> _parseRecentBallots(List<dynamic> recentBallots) => [
        ...recentBallots.map((e) {
          return BallotInfo()
            ..proposalId = e['proposalId'].toString()
            ..vote = Vote.values[e['vote'].toInt()];
        })
      ];

  List<Followee> _parseFollowees(List<dynamic> folowees) {
    final map = folowees.associate((e) => MapEntry(
        Topic.values[e['topic'] as int],
        (e['followees'] as List<dynamic>).cast<String>()));

    return Topic.values.mapToList((e) => Followee()
      ..topic = e
      ..followees = map[e] ?? []);
  }

  void _checkNeuronBalances(dynamic neurons) async {
    final bool anyRefreshed =
        await promiseToFuture(serviceApi.checkNeuronBalances(neurons));

    if (anyRefreshed) {
      print("Found neurons needing to be refreshed. Resyncing neurons...");
      sync(checkBalances: false);
    }
  }
}

class NeuronInfo extends NnsDappEntity {
  final BigInt neuronId;
  final BigInt dissolveDelaySeconds;
  final List<BallotInfo> recentBallots;
  final BigInt createdTimestampSeconds;
  final NeuronState state;
  final BigInt retrievedAtTimestampSeconds;
  final ICP votingPower;
  final BigInt ageSeconds;

  static fromResponse(dynamic response) {
    final neuronId = response['neuronId'].toString().toBigInt;
    final dissolveDelaySeconds =
        response['dissolveDelaySeconds'].toString().toBigInt;
    final recentBallots = <BallotInfo>[
      ...response['recentBallots'].map((e) => BallotInfo()
        ..proposalId = e['proposalId'].toString()
        ..vote = Vote.values[e['vote'].toInt()])
    ];
    final createdTimestampSeconds =
        response['createdTimestampSeconds'].toString().toBigInt;
    final state = NeuronState.values[response['state'].toInt()];
    final retrievedAtTimestampSeconds =
        response['retrievedAtTimestampSeconds'].toString().toBigInt;
    final votingPower =
        ICP.fromE8s(response['votingPower'].toString().toBigInt);
    final ageSeconds = response['ageSeconds'].toString().toBigInt;

    final obj = NeuronInfo(
      neuronId: neuronId,
      dissolveDelaySeconds: dissolveDelaySeconds,
      recentBallots: recentBallots,
      createdTimestampSeconds: createdTimestampSeconds,
      state: state,
      retrievedAtTimestampSeconds: retrievedAtTimestampSeconds,
      votingPower: votingPower,
      ageSeconds: ageSeconds,
    );
    return obj;
  }

  NeuronInfo(
      {required this.neuronId,
      required this.dissolveDelaySeconds,
      required this.recentBallots,
      required this.createdTimestampSeconds,
      required this.state,
      required this.retrievedAtTimestampSeconds,
      required this.votingPower,
      required this.ageSeconds});

  @override
  String get identifier => neuronId.toString();
}
