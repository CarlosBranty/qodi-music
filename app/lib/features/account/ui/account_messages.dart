import '../../../l10n/l10n.dart';
import '../domain/account.dart';

/// Localized text of an [AccountError] (null stays null, for validators).
String? accountErrorText(AppLocalizations l, AccountError? e) => switch (e) {
      null => null,
      AccountError.enterUsername => l.enterUsername,
      AccountError.usernameRule => l.usernameRule,
      AccountError.enterPassword => l.enterPassword,
      AccountError.passwordRule => l.passwordRule,
      AccountError.passwordsDiffer => l.passwordsDiffer,
      AccountError.enterInvite => l.enterInvite,
      AccountError.invalidInvite => l.invalidInvite,
      AccountError.usernameTaken => l.usernameTaken,
      AccountError.badRequest => l.badRequest,
      AccountError.wrongCurrentPassword => l.wrongCurrentPassword,
    };

String inviteStatusLabel(AppLocalizations l, InviteStatus s) => switch (s) {
      InviteStatus.active => l.statusActive,
      InviteStatus.expired => l.statusExpired,
      InviteStatus.usedUp => l.statusUsedUp,
    };
