# 0010 — Stack : Flutter + Flame (proposée)

- **Date** : 2026-11-02 · **Statut** : **proposé**, à valider par Antsa
- **Mesures** (`spikes/RESULTATS.md`) : Flutter tient tous les budgets (APK 15,2 Mo < 60 ; PSS 80 Mo < 250 ; premier
  rendu ≈ 270 ms < 3 s ; 90 i/s). Compose est le plus léger (0,8 Mo, 36 Mo). Godot dépasse presque le budget mémoire
  (≈ 225 Mo) et met ≈ 2,5 s à afficher la scène : **écarté**.
- **Choix proposé : Flutter + Flame.** Une seule base de code (iOS possible plus tard), même stack que l'app COMIMa
  d'Antsa (Flutter), Flame pour les mini-jeux, plugins ML Kit encre et étiquetage publiés sur pub.dev
  (`google_mlkit_digital_ink_recognition` 0.16.1, `google_mlkit_image_labeling` 0.16.1, 2026-08-17 ; non testés).
- **Alternative** : Compose si la mémoire devient critique (2 fois moins) ou si les plugins ML Kit Flutter échouent.
- **GPU** : les trois stacks rendent déjà sur le GPU en Vulkan ; règle : vérifier le moteur Vulkan dans le journal à
  chaque version et ne jamais forcer le rendu logiciel.
