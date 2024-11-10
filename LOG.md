## 09.11 et 10.11

Note: La grande majorité des ajouts qui ont étés faits sont dans "editor_channel.ex" et "app.js", d'autres changements sont dans "document.ex", et le CSS et HTML se trouvent dans "app.css" et "home.html.heex" respectivement.

# Peer-to-peer:

-> Les peers se connectent à un Phoenix Channel (editor:lobby) et echangent le "signaling data" 

-> Chaque peer maintien: 
    - une list des autres peers
    - une connection WebRTC (RTCPeerConnection) pour chaque peer
    - un WebRTC data channel (RTCDataChannel) pour envoyer des messages avec les autres peers

-> Le signaling est fait à travers le server Phoenix et permet la communication entre les peers

1. Un client se connecte au PhoenixChannel et recoit:
    - un socket_id unique
    - une liste des autres peers connectés
2. Chaque Peer établie une connection WebRTC avec les autres peers
3. Une fois que les connections sont établies, les peers utilisent WebRTC pour echanger les données

---

# La liste des peers: 

-> Les peers maintiennent une list des autres peers connectés (peer_list)
-> Le server Phoenix utilise "Erlang Term Storage" (ETS) pour garder une list global des peers connectés
-> Les updates de la liste des peers est fait de manière dynamique
    - Quand un peer rejoint, il est ajouté à la ETS et la liste est partagée avec les autres
    - Quand un peer quitte, il est enlevé de la ETS et les autres peers sont notifiés

---

# L'implémentation du Phoenix Channel

-> CognitusWeb.EditorChannel

Ce channel supporte les opérations:
    - join : ajoute le peer au réseau et retourne la liste actuelle des peers
    - terminate : enlève le peer du réseau et broadcast la mise à jour aux autres peers

    - webrtc_offer : relaie les "offers" entre les peers
    - webrtc_answer : relaie les "answers" entre les peers
    - ice_candidate : relaie les "ICE candidates" entre les peers

---

# Le text editing:

-> Les changements fait par un peer sont refletés pour les autres peers
-> Ces changements sont envoyés via les data channels WebRTC
-> Ces data channels contiennent des payloads structurés (type, char, position etc.)
-> Les changements faits sont appliqués localement selon les messages entrants

1. Un client écrit dans l'éditeur de texte -> input event
2. Les changements sont "serialized" en payloads JSON et envoyés via les data channels WebRTC à tous les peers connectés
3. Chaque peer applique les changements reçus

