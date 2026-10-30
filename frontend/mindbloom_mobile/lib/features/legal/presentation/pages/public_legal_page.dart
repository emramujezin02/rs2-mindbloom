import 'package:flutter/material.dart';
import '../../../../core/widgets/public_footer.dart';

enum PublicLegalDocument { terms, privacy }

class PublicLegalPage extends StatelessWidget {
  final PublicLegalDocument document;
  const PublicLegalPage({super.key, required this.document});

  String get title => document == PublicLegalDocument.terms
      ? 'Uslovi korištenja'
      : 'Politika privatnosti';

  @override
  Widget build(BuildContext context) {
    final sections = document == PublicLegalDocument.terms ? _terms : _privacy;
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFF),
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Card(
                        color: Color(0xFFFFF3DD),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'RADNI NACRT — za pregled prije javne objave. '
                            'Ovaj sadržaj nije konačan pravno odobren dokument '
                            'i ne mijenja ranije evidentirane saglasnosti. '
                            'Podaci o pružaocu usluge i pravni uslovi još trebaju biti potvrđeni.',
                          ),
                        ),
                      ),
                      for (final section in sections) ...[
                        const SizedBox(height: 24),
                        Semantics(
                          header: true,
                          child: Text(
                            section.$1,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          section.$2,
                          style: const TextStyle(height: 1.6, fontSize: 16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const PublicFooter(),
          ],
        ),
      ),
    );
  }

  static const _terms = [
    (
      'O aplikaciji',
      'MindBloom omogućava pregled terapeuta i edukativnih članaka, zahtjeve za termine, '
          'članarine, komunikaciju i recenzije. Dostupne funkcije zavise od prijavljene uloge. '
          'Pregled javnih informacija ne zahtijeva registraciju.',
    ),
    (
      'Korisnički nalog',
      'Registracija uključuje podatke profila i potvrdu traženih saglasnosti. '
          'Pristupne podatke čuvajte i ne dijelite s drugim osobama. '
          'Koristite samo vlastiti nalog i podatke kojima imate pravo pristupa.',
    ),
    (
      'Termini, članarine i plaćanja',
      'Zahtjev za termin nije isto što i prihvaćen termin. '
          'Status zahtjeva možete pratiti u aplikaciji. Pri zakazivanju i kupovini '
          'pregledajte prikazane podatke, cijenu i dostupne mogućnosti članarine ili plaćanja. '
          'Ovaj nacrt ne određuje nove naknade, rokove otkazivanja ili pravila povrata novca.',
    ),
    (
      'Recenzije i sadržaj',
      'Recenzija se može ostaviti za završeni termin i prolazi administratorsku moderaciju. '
          'Objavljujte sadržaj za koji imate pravo objave i ne unosite tuđe povjerljive podatke. '
          'Javni edukativni članci pružaju opće informacije i nisu individualna procjena korisnika.',
    ),
    (
      'Šta treba potvrditi prije objave',
      'Potrebno je potvrditi identitet i službeni kontakt pružaoca usluge, konačne uslove '
          'korištenja, postupak prigovora, pravila naplate i povrata, odgovornosti i primjenjivi '
          'pravni okvir. Ti podaci nisu utvrđeni ovim nacrtom.',
    ),
  ];

  static const _privacy = [
    (
      'Podaci u aplikaciji',
      'Registracija i profil uključuju podatke poput imena, email adrese, datuma rođenja '
          'i spola. Aplikacija obrađuje podatke naloga i prijave, terapeutske profile, termine, '
          'recenzije, komunikaciju, članarine, evidenciju plaćanja i notifikacije. '
          'Ako koristite dnevnike ili procjene, obrađuju se i podaci uneseni u tim funkcijama.',
    ),
    (
      'Javna vidljivost i recenzije',
      'Postavke profila upravljaju njegovom javnom vidljivošću. Javne recenzije koriste '
          'inicijale autora i prethodno prolaze moderaciju. Spol i dob uz recenziju prikazuju '
          'se samo uz zaseban pristanak punoljetnog autora s javnim profilom. '
          'Pristanak možete dati ili povući uređivanjem recenzije. '
          'Puni datum rođenja nije dio javne recenzije.',
    ),
    (
      'Pristup i izbori privatnosti',
      'Za zaštićene funkcije i podatke primjenjuju se provjere prijave, korisničke uloge '
          'i povezanosti s konkretnim zapisima. Postoje posebne postavke za dijeljenje '
          'raspoloženja i emocija s terapeutima. Evidenciju prihvaćenih dokumenata '
          'možete pregledati u dijelu aplikacije za privatnost i saglasnosti.',
    ),
    (
      'Plaćanja i dostava obavijesti',
      'Plaćanja su povezana sa Stripe integracijom, a aplikacija vodi povezanu evidenciju '
          'plaćanja i članarina. Koristi i servise za komunikaciju i dostavu obavijesti. '
          'Konačni dokument treba precizirati pružaoce obrade, primaoce, lokacije obrade '
          'i eventualne prijenose podataka; ovaj nacrt ih ne utvrđuje.',
    ),
    (
      'Šta treba potvrditi prije objave',
      'Potrebno je potvrditi identitet odgovornog pružaoca usluge, kontakt za pitanja '
          'privatnosti, svrhe i pravne osnove obrade, rokove čuvanja po kategorijama '
          'podataka, primaoce, postupke ostvarivanja korisničkih prava i ostale pravne obaveze. '
          'Ovaj nacrt ne predstavlja garanciju usklađenosti s određenim propisom.',
    ),
  ];
}
