# Zanak'i Antsa

Application éducative hors ligne, dès 5 ans et sans limite d'âge (de la GS au collège, et plus à mesure des versions), en français, avec l'anglais parmi les thèmes.
Sans compte, sans pub, sans achat intégré, sans pistage.

**Télécharger, découvrir, lire les nouvelles : https://raantss18.github.io/zanakiantsa/**

Dernière version : voir les [versions publiées](https://github.com/raantss18/zanakiantsa/releases). Le fichier se
télécharge aussi depuis le site, avec les gestes d'installation.

## Dans le dépôt

- `app/` : l'application (Flutter), `content/` : le contenu pédagogique (YAML, sourcé), `docs/` : vision, pédagogie, décisions
  (`docs/adr/`), `docs/TODO.md` : l'avancement.
- `site/` : le site vitrine (HTML et CSS, sans script de suivi). `python3 tool/build_site.py --releases releases.json --out _site`
  le construit ; `.github/workflows/site.yml` le publie sur GitHub Pages.

Licences : code Apache-2.0 (`LICENSE`) ; contenu original CC BY-SA 4.0 (voir `docs/adr/0001`) ; programmes séparés
sous GPL-3 et autres sources : `docs/licences.md`.
