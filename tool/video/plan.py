"""Le scénario de la vidéo d'aide (ADR 0058) : chaque plan vient d'un vrai enregistrement de la tablette SM-X135G
(screenrecord, 800 × 1340), à la seconde donnée (images tirées à 10 par seconde dans fr_<clip>/). Les cibles du doigt sont en pixels de l'écran de la tablette.

  ('chap', numéro, titre)                       carton de chapitre
  ('still', clip, temps, titre, texte, cible)   arrêt sur image, le doigt vient toucher la cible (ou None)
  ('play', clip, début, fin, durée)              le film joué entre deux temps, sur la durée donnée
"""

PLAN = [
    ('chap', 1, 'Télécharger'),
    ('still', 'z_dl', 0, 'Ouvrez le site', 'Sur la tablette, ouvrez Chrome et allez sur raantss18.github.io/zanakiantsa', None),
    ('play', 'z_dl', 1, 4, 1.6),
    ('still', 'z_dl', 5, 'Touchez le bouton violet', '« Télécharger pour Android ». Le fichier fait environ 36 Mo.', (416, 812)),
    ('still', 'z_dl', 25, 'Chrome vous met en garde',
     'Il le fait pour toute application qui ne vient pas de Google Play. Le fichier vient du site de Zanak’i Antsa : touchez « Télécharger quand même ».',
     (506, 896)),
    ('still', 'z_dl', 53, 'Le fichier est téléchargé',
     'Sur notre tablette Samsung, « Ouvrir » n’a rien lancé. Passez plutôt par l’application Mes fichiers.', None),

    ('chap', 2, 'Installer'),
    ('still', 'z_inst2', 23, 'Ouvrez « Mes fichiers »', 'C’est l’icône jaune, en bas de l’écran d’accueil.', (176, 1200)),
    ('still', 'z_inst2', 29, 'Touchez « Téléchargements »', 'Vos fichiers téléchargés y sont rangés.', (190, 240)),
    ('still', 'z_inst2', 31, 'Touchez le fichier', 'Celui qui commence par « zanakiantsa ».', (400, 430)),
    ('still', 'z_inst2', 40, 'Android demande une autorisation',
     'Pour votre sécurité, il bloque les applications qui ne viennent pas de Google Play. Touchez « Paramètres ».', (533, 1172)),
    ('still', 'z_inst2', 73, 'Activez l’autorisation',
     'Touchez l’interrupteur « Octroi d’autorisation » pour Mes fichiers, puis revenez avec la flèche. Une seule fois.', (716, 385)),
    ('still', 'z_inst2', 75, 'Touchez « Installer »', 'Android demande de confirmer.', (550, 1172)),
    ('still', 'z_inst2', 82, 'Google Play Protect',
     'Google propose d’analyser l’application. Sur notre tablette, nous avons touché « Plus de détails »…', (400, 896)),
    ('still', 'z_inst2', 85, '… puis « Installer sans analyser »', 'L’installation prend quelques secondes.', (400, 1181)),
    ('still', 'z_inst2', 87, 'C’est installé !', 'Touchez « Ouvrir ».', (540, 1164)),

    ('chap', 3, 'Préparer l’espace parent'),
    ('still', 'z_conf', 1, 'La première fois', 'L’application demande un adulte. Touchez « Espace parent ».', (400, 900)),
    ('still', 'z_conf', 18, 'Un petit calcul',
     'Il protège cet espace des enfants. Écrivez le résultat (ici 9 × 9 = 81), puis touchez « Entrer ».', (516, 594)),
    ('still', 'z_conf', 21, 'Garçon ou fille',
     'L’application propose des mondes adaptés : robots, voitures, espace ; ou fées, poupées, princesses.', (132, 862)),
    ('still', 'z_conf', 40, 'L’âge et la classe',
     'Réglez l’âge avec – et + : la classe suit, et les leçons commencent au bon niveau. Vous pouvez aussi choisir la classe.', (345, 1138)),
    ('still', 'z_conf', 49, 'Le temps de jeu par jour',
     'De 30 minutes à 1 h 30, partagé en trois activités, avec une pause entre deux.', None),

    ('chap', 4, 'Jouer'),
    ('still', 'z_jeu', 1, 'Trois activités par jour', 'L’enfant touche le gros bouton rond de l’activité proposée.', (150, 875)),
    ('still', 'z_jeu', 18, 'Une courte présentation', 'Puis l’enfant touche « C’est parti ! ».', (400, 1164)),
    ('still', 'z_jeu', 50, 'D’abord un exemple',
     'Pour une notion nouvelle, l’application montre la réponse. Puis : « J’ai compris, à moi ! ».', (400, 1164)),
    ('still', 'z_jeu', 103, 'Se tromper n’est pas grave', 'L’application explique et aide. Jamais de punition.', None),
    ('still', 'z_jeu', 112, 'Bravo !', 'Chaque bonne réponse gagne une étoile.', None),

    ('chap', 5, 'Explorer'),
    ('still', 'z_expl', 4, '« Tout explorer »', 'Il ouvre tous les domaines, à tout moment.', (400, 1047)),
    ('play', 'z_expl', 7, 27, 3.0),
    ('still', 'z_expl', 31, 'Dans chaque domaine',
     'Les leçons, « Je sais déjà » pour sauter ce qui est connu, un défi, et le carnet. Ici : les échecs.', None),
    ('still', 'z_expl', 42, '« Mes livres »', '55 livres illustrés à lire, même sans internet.', (400, 1172)),
    ('still', 'z_expl', 50, 'La bibliothèque', 'Les livres sont rangés par thème et par niveau.', None),

    ('chap', 6, 'Mettre à jour'),
    ('still', 'z_maj', 1, 'Ouvrez l’espace parent', 'Touchez le cadenas, puis faites le petit calcul.', (744, 122)),
    ('still', 'z_maj', 66, 'Une nouvelle version ?',
     'Dans « Mises à jour », touchez « Installer ». Depuis la version 0.11.1, l’application la cherche seule et l’affiche en haut.',
     (400, 1055)),
    ('still', 'z_maj', 100, 'Android demande une autorisation',
     'La première fois : activez « Octroi d’autorisation » pour Zanak’i Antsa, puis revenez avec la flèche.', (716, 385)),
    ('still', 'z_maj', 124, 'Touchez de nouveau « Installer »', 'Cette fois, l’installation démarre.', (400, 1155)),
    ('still', 'z_maj', 134, 'Confirmez', 'Touchez « Mettre à jour ».', (540, 1172)),
    ('still', 'z_maj', 143, 'Google Play Protect', 'Comme à l’installation : « Plus de détails »…', (400, 896)),
    ('still', 'z_maj', 145, '… puis « Installer sans analyser »', 'Rien n’est perdu : l’enfant garde ses progrès.', (400, 1181)),
    ('still', 'z_maj', 155, 'C’est à jour !', 'Touchez « Ouvrir ».', (540, 1164)),
]
