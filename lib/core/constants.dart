import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class C {
  static const deviseDefaut = 'FCFA';

  static const operateurs = [
    'Orange Money', 'Moov Money', 'Telecel Money', 'Wave', 'Autre'
  ];
  /// Distincte de [operateurs] (Mobile Money) : les opérateurs de crédit
  /// communication n'ont pas le suffixe "Money" — avant l'introduction des
  /// listes dynamiques (v1.7), le formulaire Crédit utilisait par erreur
  /// [operateurs], proposant "Orange Money" pour un achat de crédit.
  static const operateursCredit = ['Orange', 'Moov', 'Telecel', 'Autre'];
  static const domaines = [
    'Informatique', 'Électricité', 'Électronique',
    'Vidéosurveillance', 'Réseaux & Télécom', 'Autre'
  ];
  static const dureesForfait = ['1 heure', '1 jour', '1 semaine', '1 mois'];
  static const categoriesProduit = [
    'Électricité', 'Télécom & Réseau', 'Accessoire PC', 'Accessoire téléphone'
  ];

  static const infosTypes = <TypeTransaction, (String, IconData, Color)>{
    TypeTransaction.prestationService: ('Prestation', Icons.build_rounded, Color(0xFF3D6FB4)),
    TypeTransaction.venteMateriel: ('Matériel', Icons.inventory_2_rounded, Color(0xFF7E57C2)),
    TypeTransaction.mobileMoney: ('Mobile Money', Icons.phone_android_rounded, Color(0xFFEF6C00)),
    TypeTransaction.creditCommunication: ('Crédit', Icons.sms_rounded, Color(0xFF00897B)),
    TypeTransaction.forfaitHotspot: ('Forfait', Icons.wifi_rounded, Color(0xFF039BE5)),
  };

  static final _fmt = NumberFormat('#,##0', 'fr_FR');
  /// Format monétaire — devise dynamique (profil entreprise).
  static String money(num v, [String? devise]) =>
      '${_fmt.format(v)} ${devise ?? deviseDefaut}';
  static String moisKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
