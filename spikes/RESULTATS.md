# Résultats du spike (2026-11-02)

Deux Galaxy Tab A11 SM-X135G (écran **90 Hz**, GPU **Mali-G57 MC2**), APK release arm64. Scripts : `measure.sh`
(taille, `am start -W`, PSS après 20 s, fps) et `first_frame.sh` (temps réel jusqu'au premier rendu de l'activité).
Médianes de 5 lancements à froid ; A = `R8YYA0CZ5ZV` (désencombrée), B = `R8YL11BAJ7D` (d'origine).

| Mesure | Flutter 3.47 + Flame 1.38 | Kotlin + Compose (BOM 2026.06.01) | Godot 4.7.2 |
| --- | --- | --- | --- |
| Taille d'APK | 15,2 Mo | **0,8 Mo** (R8 activé) | 25,2 Mo |
| Premier rendu réel (A / B) | **272 / 269 ms** | 338 / 337 ms | 2 546 / 2 618 ms |
| `am start -W` TotalTime (A / B) | 533 / 501 ms | 380 / 373 ms | 407 / 426 ms ⚠ |
| Mémoire PSS (A / B) | 79 / 80 Mo | **35 / 36 Mo** | 223 / 228 Mo |
| Images/s (A / B) | 90,0 / 90,1 | 90,1 / 90,2 | 89,2 / 89,3 |
| Rendu GPU | Vulkan (journal `vulkan`) | HWUI Vulkan (`ro.hwui.use_vulkan=true`) | Vulkan « Forward Mobile », Mali-G57 |
| Voix fr-FR (TTS Google) | oui | oui | oui |
| Parcours complet testé (compter, répondre, tour suivant) | oui | oui | oui |

⚠ Pour Godot, `TotalTime` s'arrête à l'écran de démarrage : le premier rendu de la scène arrive ≈ 2,5 s après.

Les deux tablettes donnent les mêmes résultats à quelques pour cent près : le désencombrement ne change rien de
mesurable pour une app seule.

## Ce qui n'est pas mesuré

Son entendu à l'oreille (seuls les journaux TTS le confirment) ; consommation batterie ; ML Kit (encre, étiquetage)
dans chaque stack ; plusieurs heures d'usage.
