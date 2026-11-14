import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../auth/ui/auth_controller.dart';
import '../data/account_api.dart';
import '../domain/account.dart';

final accountApiProvider = Provider<AccountApi>((ref) => AccountApi(ref.watch(apiClientProvider)));

/// True when the signed-in user is an admin (shows Settings › Users).
final isAdminProvider = Provider<bool>((ref) => ref.watch(authControllerProvider)?.user.isAdmin ?? false);

final adminUsersProvider = FutureProvider.autoDispose<List<UserSummary>>((ref) => ref.watch(accountApiProvider).users());

final adminInvitesProvider = FutureProvider.autoDispose<List<Invite>>((ref) => ref.watch(accountApiProvider).invites());

/// Clock used for invite status (overridable in tests).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
