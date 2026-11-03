# 0024 — Explorer en 3D (solides, système solaire, corps)

- **Date** : 2026-11-03 · **Statut** : accepté (priorités 4 et 6 d'Antsa)
- **Décision** : un domaine « Explorer » : nommer un **solide** qui tourne en 3D (cube, pavé, boule puis cylindre,
  cône ; programme de CP), toucher une **planète** dans le système solaire en 3D qu'on tourne au doigt (ordre et
  tailles : NASA, https://science.nasa.gov/solar-system/planets/), toucher une **partie du corps** (maternelle).
- **Rendu** (`app/lib/ui/three.dart`) : petite 3D maison — facettes tournées, éclairées, triées par profondeur, dessinées
  par `Canvas.drawVertices`, donc rasterisées par le GPU (Impeller/Vulkan sur la SM-X135G). Aucun moteur 3D ajouté
  (APK 28,5 Mo). Les solides sont fermés (testé). Distances et tailles des planètes **pas à l'échelle** ; seul l'ordre
  des tailles est respecté.
- **Note** : le programme de maternelle exclut les représentations en perspective des solides ; elles sont donc
  placées au niveau CP.
- **Reste à faire** : organes du corps (programme de cycle 2/3 à relire), solides à manipuler librement (type
  GeoGebra), fluidité à mesurer sur une vraie tablette.
