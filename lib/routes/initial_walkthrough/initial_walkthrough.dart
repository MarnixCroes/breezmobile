import 'dart:async';
import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:breez/bloc/backup/backup_actions.dart';
import 'package:breez/bloc/backup/backup_bloc.dart';
import 'package:breez/bloc/backup/backup_model.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/bloc/pos_catalog/bloc.dart';
import 'package:breez/bloc/user_profile/user_actions.dart';
import 'package:breez/bloc/user_profile/user_profile_bloc.dart';
import 'package:breez/logger.dart';
import 'package:breez/routes/initial_walkthrough/dialogs/beta_warning_dialog.dart';
import 'package:breez/routes/initial_walkthrough/dialogs/restore_dialog.dart';
import 'package:breez/routes/initial_walkthrough/dialogs/select_backup_provider_dialog.dart';
import 'package:breez/routes/initial_walkthrough/loaders/loader_indicator.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/theme_data.dart';
import 'package:breez/utils/exceptions.dart';
import 'package:breez/widgets/error_dialog.dart';
import 'package:breez/widgets/flushbar.dart';
import 'package:breez_translations/breez_translations_locales.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class InitialWalkthroughPage extends StatefulWidget {
  final BackupBloc backupBloc;
  final UserProfileBloc userProfileBloc;
  final Sink<bool> reloadDatabaseSink;

  const InitialWalkthroughPage({
    @required this.backupBloc,
    @required this.userProfileBloc,
    @required this.reloadDatabaseSink,
  });

  @override
  State<InitialWalkthroughPage> createState() => _InitialWalkthroughPageState();
}

class _InitialWalkthroughPageState extends State<InitialWalkthroughPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey scaffoldKey = GlobalKey<ScaffoldState>();
  AnimationController controller;
  Animation<int> animation;

  StreamSubscription<BackupSettings> _backupSettingsSubscription;
  BackupSettings _backupSettings;

  bool _registered = false;

  @override
  void initState() {
    super.initState();

    /// Breez Logo Animation
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2720),
    )..forward(from: 0.0);
    animation = IntTween(begin: 0, end: 67).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value
        });
      });
    controller.forward();

    _backupSettingsSubscription = widget.backupBloc.backupSettingsStream.listen(
      (backupSettings) {
        setState(() {
          _backupSettings = backupSettings;
        });
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _backupSettingsSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_registered) {
      exit(0);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.texts();
    final themeData = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: blueTheme.appBarTheme.systemOverlayStyle,
      child: Theme(
        data: blueTheme,
        child: WillPopScope(
          onWillPop: () => _onWillPop(),
          child: Scaffold(
            key: scaffoldKey,
            body: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        flex: 200,
                        child: Container(),
                      ),
                      Expanded(
                        flex: 171,
                        child: AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget child) {
                            String frame =
                                animation.value.toString().padLeft(2, '0');
                            return Image.asset(
                              'src/animations/welcome/frame_${frame}_delay-0.04s.png',
                              gaplessPlayback: true,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 200,
                        child: Container(),
                      ),
                      Expanded(
                        flex: 48,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, right: 24),
                          child: AutoSizeText(
                            texts.initial_walk_through_welcome_message,
                            textAlign: TextAlign.center,
                            style: theme.welcomeTextStyle,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 60,
                        child: Container(),
                      ),
                      SizedBox(
                        height: 48.0,
                        width: 168.0,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            backgroundColor: themeData.primaryColor,
                            elevation: 0.0,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            texts.initial_walk_through_lets_breeze,
                            style: themeData.textTheme.labelLarge,
                          ),
                          onPressed: () => _letsBreez(),
                        ),
                      ),
                      Expanded(
                        flex: 40,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: GestureDetector(
                            onTap: () => _restoreFromBackup(),
                            child: Text(
                              texts.initial_walk_through_restore_from_backup,
                              style: theme.restoreLinkStyle,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 120,
                        child: Container(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* Let's Breez */

  void _letsBreez() async {
    log.info("Registering new node");
    await showDialog(
      useRootNavigator: false,
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => BetaWarningDialog(),
    ).then((approved) async {
      if (approved) {
        try {
          EasyLoading.show(indicator: const LoaderIndicator());

          await _signOut().timeout(
            const Duration(seconds: 8),
            onTimeout: () => log.info("sign out timed out"),
          );
          await _resetBackupSettings();
          await _resetSecurityModel();
          _register();
        } catch (error) {
          EasyLoading.dismiss();

          _handleError(error);
        }
      }
    });
  }

  Future _resetBackupSettings() {
    var updateAction = UpdateBackupSettings(BackupSettings.initial());
    widget.backupBloc.backupActionsSink.add(updateAction);
    return updateAction.future;
  }

  Future _resetSecurityModel() async {
    var resetAction = ResetSecurityModel();
    widget.userProfileBloc.userActionsSink.add(resetAction);
    return resetAction.future;
  }

  void _register() {
    EasyLoading.dismiss();

    setState(() {
      _registered = true;
    });
    widget.userProfileBloc.registerSink.add(null);
    Navigator.of(context).pop();
  }

  void _handleError(dynamic exception) {
    final texts = context.texts();
    final themeData = Theme.of(context);
    promptError(
      context,
      texts.security_and_backup_internal_error,
      Text(
        extractExceptionMessage(exception, texts: texts),
        style: themeData.dialogTheme.contentTextStyle,
      ),
    );
  }

  /* Restore From Backup */

  void _restoreFromBackup() async {
    log.info("Restore from Backup");
    // Timeout is added for Graphene/CalyxOS devices
    await _signOut().timeout(
      const Duration(seconds: 8),
      onTimeout: () => log.info("sign out timed out"),
    );
    _showSelectProviderDialog().then((snapshots) {
      _showRestoreDialog(snapshots).then((restoreRequest) {
        _restore(restoreRequest);
      });
    });
  }

  Future _signOut() {
    var signOutAction = SignOut(promptOnError: false);
    widget.backupBloc.backupActionsSink.add(signOutAction);
    return signOutAction.future;
  }

  Future<List<SnapshotInfo>> _showSelectProviderDialog() {
    return showDialog<List<SnapshotInfo>>(
      useRootNavigator: false,
      context: context,
      builder: (_) => SelectBackupProviderDialog(
        backupSettings: _backupSettings,
        isRestoreFlow: true,
      ),
    );
  }

  Future<RestoreRequest> _showRestoreDialog(
    List<SnapshotInfo> snapshots,
  ) async {
    if (snapshots != null && snapshots.isNotEmpty) {
      return _selectSnapshotToRestore(snapshots);
    } else {
      return null;
    }
  }

  Future<RestoreRequest> _selectSnapshotToRestore(
    List<SnapshotInfo> snapshots,
  ) async {
    return showDialog<RestoreRequest>(
      useRootNavigator: false,
      context: context,
      builder: (_) => RestoreDialog(
        snapshots,
        _backupSettings,
        widget.reloadDatabaseSink,
      ),
    );
  }

  Future<void> _restore(RestoreRequest restoreRequest) {
    if (restoreRequest == null) {
      return null;
    }
    var restoreBackupAction = RestoreBackup(restoreRequest);
    widget.backupBloc.backupActionsSink.add(restoreBackupAction);
    final texts = context.texts();
    // TODO Remove ... from translation
    EasyLoading.show(
      indicator: LoaderIndicator(
        message: texts.initial_walk_through_restoring,
      ),
    );
    return restoreBackupAction.future.then(
      (isRestored) => _completeRestoration(isRestored),
      onError: (error) => _handleRestoreBackupError(error),
    );
  }

  void _completeRestoration(bool isRestored) async {
    EasyLoading.dismiss();

    if (isRestored) {
      final posCatalogBloc = AppBlocsProvider.of<PosCatalogBloc>(context);
      posCatalogBloc.reloadPosItemsSink.add(true);
      widget.reloadDatabaseSink.add(true);
      widget.userProfileBloc.registerSink.add(null);
      Navigator.popUntil(context, (route) => route.settings.name == "/");
    }
  }

  void _handleRestoreBackupError(error) {
    EasyLoading.dismiss();

    String errorMessage = error.toString();
    if (errorMessage.contains("FileSystemException")) {
      errorMessage = context.texts().enter_backup_phrase_error;
    }
    showFlushbar(
      context,
      duration: const Duration(seconds: 3),
      message: errorMessage,
    );
  }
}
