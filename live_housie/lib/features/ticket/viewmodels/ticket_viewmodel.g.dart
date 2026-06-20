// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userTickets)
const userTicketsProvider = UserTicketsFamily._();

final class UserTicketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TicketModel>>,
          List<TicketModel>,
          FutureOr<List<TicketModel>>
        >
    with
        $FutureModifier<List<TicketModel>>,
        $FutureProvider<List<TicketModel>> {
  const UserTicketsProvider._({
    required UserTicketsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'userTicketsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userTicketsHash();

  @override
  String toString() {
    return r'userTicketsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TicketModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TicketModel>> create(Ref ref) {
    final argument = this.argument as String?;
    return userTickets(ref, gameId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserTicketsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userTicketsHash() => r'3b770a352925e72a219e910692bdf74934e78045';

final class UserTicketsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TicketModel>>, String?> {
  const UserTicketsFamily._()
    : super(
        retry: null,
        name: r'userTicketsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserTicketsProvider call({String? gameId}) =>
      UserTicketsProvider._(argument: gameId, from: this);

  @override
  String toString() => r'userTicketsProvider';
}
