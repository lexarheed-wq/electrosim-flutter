
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_industrial_physical_plate.dart';
import 'f18_home.dart';
import 'f18_product_library_pages.dart';
import 'f18_session_coordinator.dart';
import 'f18_v1_navigation_flow.dart';
import 'reference_components/disjoncteur_3d.dart';
import 'f9_ui_context.dart';
import 'runtime/electrosim_lan_sync.dart';
import 'runtime/electrosim_persistence_controller.dart';
import 'runtime/electrosim_tp_session_controller.dart';

import 'f18_workspace_page.dart';
export 'f18_workspace_page.dart' show F18WorkspacePage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final physicalTextures = Disjoncteur3D.prechargerTextures();
  final industrialTextures = F18PhysicalPlateAssets.preload();
  final ElectroSimPersistenceController persistenceController =
      await ElectroSimPersistenceController.createDefault();
  await physicalTextures;
  await industrialTextures;
  runApp(ElectroSimApp(persistenceController: persistenceController));
}

class ElectroSimApp extends StatelessWidget {
  const ElectroSimApp({super.key, this.persistenceController});

  final ElectroSimPersistenceController? persistenceController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElectroSim',
      theme: ElectroSimTheme.light(),
      home: F9HomePage(persistenceController: persistenceController),
    );
  }
}

class F9HomePage extends StatelessWidget {
  const F9HomePage({super.key, this.persistenceController});

  final ElectroSimPersistenceController? persistenceController;

  @override
  Widget build(BuildContext context) {
    return F18HomeSurface(
      onCreateSession: () => _openSessionShell(context, persistenceController),
      onMaintenance: () =>
          _openMaintenanceCenter(context, persistenceController),
      onDesign: () => _openDesignCenter(context, persistenceController),
      onJoinSession: () => _joinLanSession(context, persistenceController),
    );
  }

  static Future<void> _joinLanSession(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) async {
    final _NetworkJoinRequest? request = await showDialog<_NetworkJoinRequest>(
      context: context,
      builder: (BuildContext dialogContext) => const _NetworkJoinDialog(),
    );
    if (request == null || !context.mounted) return;

    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController();
    final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
      controller: controller,
      sessionCode: request.sessionCode,
      clientId: ElectroSimLanSyncClient.generateClientId(),
    );
    try {
      await client.connect(request.endpoint);
      if (!context.mounted) {
        await client.close();
        controller.dispose();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => F18WorkspacePage(
            entryLabel: 'Session élève',
            initialWorkspace: 'Recherche de dérangement',
            sessionNavigation: true,
            role: F9UserRole.student,
            tpSessionController: controller,
            persistenceController: persistenceController,
            syncClient: client,
          ),
        ),
      );
    } on Object catch (error) {
      await client.close();
      controller.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Connexion à la session impossible : $error')),
        );
    }
  }

  static void _openDesignCenter(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'design-center'),
        builder: (BuildContext routeContext) => F18DesignCenterPage(
          onHome: () => Navigator.of(
            routeContext,
          ).popUntil((Route<dynamic> route) => route.isFirst),
          onWiring: () => _openWorkspace(
            routeContext,
            'Centre de conception',
            initialWorkspace: 'Câblage',
            persistenceController: persistenceController,
            parentRouteName: 'design-center',
          ),
          onSchemaLibrary: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'design-schema-library'),
              builder: (BuildContext libraryContext) => F18SchemaLibraryPage(
                library: buildV2ProductLibrary(),
                onOpen: (ExampleDefinition schema) => _openWorkspace(
                  libraryContext,
                  'Bibliothèque de schémas',
                  initialWorkspace: 'Câblage',
                  initialCircuit: schema.circuit,
                  persistenceController: persistenceController,
                  parentRouteName: 'design-schema-library',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _openMaintenanceCenter(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'maintenance-center'),
        builder: (BuildContext routeContext) => F18MaintenanceCenterPage(
          onHome: () => Navigator.of(
            routeContext,
          ).popUntil((Route<dynamic> route) => route.isFirst),
          onTroubleshooting: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(
                name: 'maintenance-troubleshooting-setup',
              ),
              builder: (BuildContext setupContext) => F18ActivitySetupPage(
                pageKey: const Key('maintenance-troubleshooting-setup-page'),
                title: 'Préparer une recherche de dérangement',
                description:
                    'Préparez le diagnostic avant d’ouvrir l’atelier de maintenance.',
                parentLabel: 'centre de maintenance',
                onBack: () => Navigator.of(setupContext).pop(),
                onOpenWorkshop: () => _openWorkspace(
                  setupContext,
                  'Centre de maintenance',
                  initialWorkspace: 'Recherche de dérangement',
                  persistenceController: persistenceController,
                  parentRouteName: 'maintenance-center',
                ),
              ),
            ),
          ),
          onFaultLibrary: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'maintenance-fault-library'),
              builder: (BuildContext libraryContext) => F18FaultLibraryPage(
                library: buildV2ProductLibrary(),
                onLaunch: (FaultScenarioDefinition scenario) => _openWorkspace(
                  libraryContext,
                  'Bibliothèque de pannes',
                  initialWorkspace: 'Recherche de dérangement',
                  initialCircuit: scenario.faultyCircuit,
                  persistenceController: persistenceController,
                  parentRouteName: 'maintenance-fault-library',
                ),
              ),
            ),
          ),
          onStudentValidation: () => Navigator.of(routeContext).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(
                name: 'student-situation-validation',
              ),
              builder: (BuildContext validationContext) =>
                  F18StudentSituationValidationPage(
                    onBack: () => Navigator.of(validationContext).pop(),
                    onLaunch: (String referenceCircuit, String faultScenario) {
                      _openWorkspace(
                        validationContext,
                        'Validation en situation élève',
                        initialWorkspace: 'Recherche de dérangement',
                        persistenceController: persistenceController,
                        parentRouteName: 'maintenance-center',
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openSessionShell(
    BuildContext context,
    ElectroSimPersistenceController? persistenceController,
  ) async {
    final F18SessionCreationDraft? draft =
        await showDialog<F18SessionCreationDraft>(
          context: context,
          builder: (BuildContext dialogContext) =>
              const F18CreateSessionDialog(),
        );
    if (draft == null || !context.mounted) return;

    final String sessionCode = ElectroSimLanSyncHost.generateSessionCode();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'teacher-session'),
        builder: (BuildContext routeContext) =>
            F18TeacherSessionCoordinatorPage(
              sessionName: draft.name,
              sessionCode: sessionCode,
              workspaceBuilder:
                  (
                    BuildContext workspaceContext,
                    ElectroSimTpSessionController controller,
                    String workspace,
                    VoidCallback onDashboard,
                    ValueChanged<CircuitState> onManageSession,
                  ) => F18WorkspacePage(
                    entryLabel: 'Session active',
                    initialWorkspace: workspace,
                    sessionNavigation: true,
                    tpSessionController: controller,
                    persistenceController: persistenceController,
                    onSessionDashboard: onDashboard,
                    onSessionManageWithCircuit: onManageSession,
                  ),
            ),
      ),
    );
  }

  static void _openWorkspace(
    BuildContext context,
    String entryLabel, {
    required String initialWorkspace,
    CircuitState? initialCircuit,
    bool sessionNavigation = false,
    ElectroSimPersistenceController? persistenceController,
    String? parentRouteName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: initialWorkspace == 'Câblage'
              ? 'cabling-workspace'
              : 'troubleshooting-workspace',
        ),
        builder: (BuildContext workspaceContext) => F18WorkspacePage(
          entryLabel: entryLabel,
          initialWorkspace: initialWorkspace,
          initialCircuit: initialCircuit,
          sessionNavigation: sessionNavigation,
          persistenceController: persistenceController,
          onExitWorkspace: parentRouteName == null
              ? null
              : () => Navigator.of(workspaceContext).popUntil(
                  (Route<dynamic> route) =>
                      route.settings.name == parentRouteName,
                ),
        ),
      ),
    );
  }
}

final class _NetworkJoinRequest {
  const _NetworkJoinRequest({
    required this.endpoint,
    required this.sessionCode,
  });

  final Uri endpoint;
  final String sessionCode;
}

class _NetworkJoinDialog extends StatefulWidget {
  const _NetworkJoinDialog();

  @override
  State<_NetworkJoinDialog> createState() => _NetworkJoinDialogState();
}

class _NetworkJoinDialogState extends State<_NetworkJoinDialog> {
  final TextEditingController _endpoint = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rejoindre une session'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const Key('join-session-endpoint'),
              controller: _endpoint,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Adresse du professeur',
                hintText: 'ws://192.168.1.20:12345/electrosim-sync',
              ),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            TextField(
              key: const Key('join-session-code'),
              controller: _code,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code de session',
                hintText: 'ABC234',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.sm),
              Text(_error!, key: const Key('join-session-error')),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('join-session-submit'),
          onPressed: _submit,
          child: const Text('Rejoindre'),
        ),
      ],
    );
  }

  void _submit() {
    final String rawEndpoint = _endpoint.text.trim();
    final String rawCode = _code.text.trim().toUpperCase();
    final Uri? endpoint = Uri.tryParse(
      rawEndpoint.startsWith('ws://') || rawEndpoint.startsWith('wss://')
          ? rawEndpoint
          : 'ws://$rawEndpoint',
    );
    if (endpoint == null ||
        (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') ||
        endpoint.host.isEmpty) {
      setState(() {
        _error = 'Adresse réseau invalide.';
      });
      return;
    }
    if (rawCode.length != 6 || RegExp(r'[^A-Z2-9]').hasMatch(rawCode)) {
      setState(() {
        _error = 'Le code de session doit contenir 6 caractères.';
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_NetworkJoinRequest(endpoint: endpoint, sessionCode: rawCode));
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _code.dispose();
    super.dispose();
  }
}

/// Compatibility entry point used by legacy tests and proof binaries.
///
/// It no longer injects a product demo circuit. Callers that need a deterministic
/// regression fixture must provide [initialCircuit] explicitly.
class F9WorkspaceDemoPage extends F18WorkspacePage {
  const F9WorkspaceDemoPage({
    super.key,
    super.entryLabel = 'Centre de conception',
    super.initialWorkspace = 'Câblage',
    super.sessionNavigation = false,
    super.initialSelectedElementId,
    super.initialCircuit,
    super.initialCabinetLayout,
    super.role = F9UserRole.teacher,
    super.tpSessionController,
    super.persistenceController,
    super.layoutPreferences,
    super.syncClient,
    super.onSessionDashboard,
    super.onSessionManage,
    super.onSessionManageWithCircuit,
    super.onExitWorkspace,
  });
}

