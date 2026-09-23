import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/env.dart';
import '../../data/store.dart';
import '../../models/enums.dart';
import '../../services/supabase_service.dart';
import '../shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  final _nom = TextEditingController();
  Role _role = Role.admin;
  bool _loading = false;
  bool _motDePasseVisible = false;

  bool get _cloud => Env.supabaseConfigured;

  Future<void> _entrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_cloud) {
      // ===== PRODUCTION : authentification réelle Supabase =====
      final ok = await SupabaseService.connexion(
          _email.text.trim(), _mdp.text.trim());
      if (!ok) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('❌ Email ou mot de passe incorrect')));
        }
        return;
      }
      if (!mounted) return;
      final store = context.read<Store>();
      final charge = await store.chargerDuCloud();
      if (!mounted) return;
      setState(() => _loading = false);
      if (charge == false) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Connecté mais impossible de charger les données. '
                'Vérifiez que le SQL a bien été exécuté dans Supabase.')));
        return;
      }
      // Authentifié mais aucune ligne public.users pour ce compte (Étape 5
      // du guide de déploiement non faite, ou faite pour un autre email) :
      // on prévient tout de suite plutôt que de laisser l'utilisateur
      // découvrir des erreurs RLS/UUID cryptiques à la première vente.
      if (store.profilCloudManquant) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: Duration(seconds: 8),
            content: Text('⚠️ Connecté, mais ce compte n\'a pas de profil '
                '(rôle) configuré côté base de données — contactez '
                'l\'administrateur (table public.users).')));
      }
      _ouvrirAccueil();
    } else {
      // ===== DÉMO locale : rôle libre, aucune donnée cloud =====
      context.read<Store>().changerRole(_role);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _loading = false);
      _ouvrirAccueil();
    }
  }

  void _ouvrirAccueil() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => const AppShell(),
        transitionsBuilder: (_, a1, a2, child) =>
            FadeTransition(opacity: a1, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 96, height: 96,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF10B981), width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 20,
                          offset: Offset(0, 8)),
                    ],
                  ),
                  // Symbole seul (fond transparent), pas la composition
                  // horizontale avec le lettrage « Nycta » — illisible une
                  // fois réduite dans un badge rond. BoxFit.contain (pas
                  // .cover comme pour l'ancienne image photo) : le PNG a
                  // déjà sa marge intégrée (voir LIRE-MOI.txt du kit), il
                  // ne doit pas être recadré/zoomé.
                  child: Image.asset(
                      'assets/images/nycta/couleur-fond-clair/nycta-icone.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront_rounded,
                          size: 40, color: Color(0xFF10B981))),
                ),
                const SizedBox(height: 20),
                const Text('PME Gestion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(
                  _cloud
                      ? 'Connexion sécurisée à votre espace'
                      : 'Mode démonstration — données sur cet appareil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _cloud
                          ? const Color(0xFF6EE7B7)
                          : Colors.white70),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 24,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                    if (_cloud)
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Email invalide' : null,
                      )
                    else
                      TextFormField(
                        controller: _nom,
                        decoration: const InputDecoration(
                            labelText: "Nom de l'utilisateur",
                            prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mdp,
                      obscureText: !_motDePasseVisible,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_motDePasseVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          tooltip: _motDePasseVisible
                              ? 'Masquer le mot de passe'
                              : 'Afficher le mot de passe',
                          onPressed: () => setState(
                              () => _motDePasseVisible = !_motDePasseVisible),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? '6 caractères min.' : null,
                    ),
                    if (!_cloud) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<Role>(
                        initialValue: _role,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Rôle (démo des permissions)',
                            prefixIcon: Icon(Icons.badge_outlined)),
                        items: [
                          for (final r in Role.values)
                            DropdownMenuItem(value: r, child: Text(r.label)),
                        ],
                        onChanged: (r) => setState(() => _role = r!),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _entrer,
                        child: _loading
                            ? const SizedBox(
                                height: 22, width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Se connecter'),
                      ),
                    ),
                  ]),
                ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }
}

/// Démarrage automatique : session Supabase encore valide → on charge
/// le cloud puis on ouvre directement l'application (sans repasser par
/// la connexion).
class CloudLoader extends StatefulWidget {
  const CloudLoader({super.key});
  @override
  State<CloudLoader> createState() => _CloudLoaderState();
}

class _CloudLoaderState extends State<CloudLoader> {
  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final store = context.read<Store>();
    final ok = await store.chargerDuCloud();
    if (!mounted) return;
    // Note : contrairement à LoginScreen._entrer(), pas d'alerte ici si
    // store.profilCloudManquant est vrai (reconnexion silencieuse au
    // démarrage, écran déjà en train de disparaître) — l'utilisateur voit
    // quand même le badge de synchronisation bloquée (AppShell) dès qu'une
    // écriture échoue côté RLS.
    if (ok) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()));
    } else {
      // Session invalide ou cloud inaccessible : retour à la connexion.
      await SupabaseService.client?.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Connexion à votre espace…'),
        ])),
      );
}
