# 0066 — Des mondes par tranche d'âge

- **Date** : 2026-11-08 · **Statut** : accepté (demande d'Antsa : « adapte à la catégorie d'âge », après « à douze ans on ne
  compte plus les voitures »).
- **Décision** : trois tranches, d'après l'âge réglé par le parent.
  - **Petits (jusqu'à 7 ans)** : les 6 mondes d'avant, selon le genre (ADR 0014), inchangés.
  - **8–11 ans** : 3 mondes mixtes, au choix de l'enfant : l'expédition (Kali), le laboratoire (Ada), l'océan (Maé).
  - **12 ans et plus** : 3 mondes mixtes, ton d'ado : mission Mars (Véga), le studio (Sam), le tour du monde (Lou).
  - Quand l'enfant change de tranche, il passe au premier monde de la nouvelle ; il peut en changer. Chaque monde a ses
    mots (FR/EN), son histoire, ses couleurs (contraste AA, `tool/contrast.py`), ses autocollants, son bruitage et sa
    trame sonore synthétisés (ADR 0017, 0025). 49 dessins Twemoji v17.0.3 ajoutés (CC BY 4.0).
- **Noms des domaines** (2026-11-08, question d'Antsa : « pourquoi à 17 ans encore Lire et écrire ? ») : chaque domaine a
  un nom par tranche (`noms` dans `_theme.yaml`) : Lire et écrire → Le français → Français ; Les nombres → Les maths →
  Mathématiques ; Le vivant → Les sciences → Sciences ; Explorer → Histoire et monde → Histoire-géographie ; Le code →
  Informatique. Les échecs, le dessin et les domaines des petits gardent leur nom.
- **Vérifié** : `test/worlds_test.dart`, `test/universe_test.dart` ; tablette SM-X135G à 12 ans (Mars, studio), 9 ans
  (expédition), puis remise à 7 ans (robots) ; voix écoutée avec `tool/ecoute.py`.
- **Faits cités** (vérifiés) : tour Eiffel 330 m ; atterrissage dans le cratère Jezero (Perseverance, 2021) ; voyage vers
  Mars d'environ 7 mois.
