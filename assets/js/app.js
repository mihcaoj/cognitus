// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { Presence } from "phoenix";

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// DOM reference for the text editor
let editor = document.querySelector("#editor");

// Creates a Phoenix WebSocket connection to the backend
let socket = new Socket("/socket", { params: {userToken: "123"} });
socket.connect();

// Ask for username before the user can access editor (TODO: Random names?)
let username = prompt("Enter your username:")

// Join the editor channel (editor:lobby)
let channel = socket.channel("editor:lobby", { username });

// Store WebRTC connections (dictionary with {key: peerID, value: RTCPeerConnection})
let peerConnections = {};
// Store WebRTC data channels (dictionary with {key: peerId, value: RTCDataChannel})
let dataChannels = {};

let localSocketId = null; // used later on to prevent applying operations twice locally
let peer_list = []; // local list of peers in the network
let presences = {}; // store current presences

/*
************************************************************
**************** CHANNEL RELATED FUNCTIONS *****************
************************************************************
*/

// Join the channel - establishes a connection to the editor:lobby channel
channel.join()
  .receive("ok", ({ socket_id, peers }) => {
    console.log("Joined succesfully");
    localSocketId = socket_id; // save the local socket id
    console.log("Available peers:", peers)
    peer_list = peers; // update the list of peers
    
    // Iterate over all peers and connect
    peer_list.forEach((peerId) => {
      if (peerId !== localSocketId) {
        console.log("Connecting to peer:", peerId);
        let peerConnection = createPeerConnection(peerId);

        // Create and send a WebRTC offer to the peer
        peerConnection.createOffer().then((offer) => {
          peerConnection.setLocalDescription(offer);
          console.log("Sending WebRTC offer to:", peerId);
          channel.push("webrtc_offer", { offer: offer, to: peerId });
        }).catch((error) => {
          console.error("Error creating WebRTC offer for peer:", peerId, error);
        });

        // Store the peer connection
        peerConnections[peerId] = peerConnection;
      }
    });
  })
  .receive("error", () => console.log("Unable to join"));
  
/*
Handle incoming WebRTC offers
- Creates a RTCPeerConnection for the sender of the offer
- Sets the remote description
- Creates and sends an answer (webrtc_answer)
*/
channel.on("webrtc_offer", (payload) => {
  console.log("Received WebRTC offer payload:", payload);

  if (payload.to === localSocketId) {
    console.log("Processing WebRTC offer from:", payload.from);

    let peerConnection = createPeerConnection(payload.from);
    peerConnections[payload.from] = peerConnection;

    peerConnection.setRemoteDescription(new RTCSessionDescription(payload.offer))
      .then(() => {
        console.log("Set remote description for offer from:", payload.from);
        return peerConnection.createAnswer();
      })
      .then((answer) => {
        peerConnection.setLocalDescription(answer);
        console.log("Sending WebRTC answer to:", payload.from);
        channel.push("webrtc_answer", { answer: answer, to: payload.from });
      })
      .catch((error) => console.error("Error processing WebRTC offer:", error));
  }
});

/*
Handle incoming WebRTC answers
- Sets the remote description for the sender of the answer
*/
channel.on("webrtc_answer", (payload) => {
  console.log("Received WebRTC answer:", payload);

  if (payload.to === localSocketId) {
    console.log("Setting remote description for answer from:", payload.from);

    let peerConnection = peerConnections[payload.from];
    peerConnection.setRemoteDescription(new RTCSessionDescription(payload.answer))
      .then(() => console.log("Remote description set successfully for answer"))
      .catch((error) => console.error("Error setting remote description for answer:", error));
  }
});

/*
Handle ICE candidates for WebRTC connections
- Adds incoming ICE candidates to the appropriate RTCPeerConnection.
*/
channel.on("ice_candidate", (payload) => {
  console.log("Received ICE candidate:", payload);
  
  if (payload.to === localSocketId) {
    let peerConnection = peerConnections[payload.from];
    peerConnection.addIceCandidate(new RTCIceCandidate(payload.candidate))
      .then(() => console.log("ICE candidate added successfully"))
      .catch((error) => console.error("Error adding ICE candidate:", error));
  }
});

/*
Listen for peer list updates
- Adds connections for new peers
- Closes connections for peers that have left
*/
channel.on("peer_list_updated", (payload) => {
  console.log("Updated peer list received:", payload.peers);
  const updatedPeers = payload.peers;

  // Find new peers to connect to
  const newPeers = updatedPeers.filter(peer => !peer_list.includes(peer) && peer !== localSocketId);

  // Connect to new peers
  newPeers.forEach((peerId) => {
    console.log("Connecting to new peer:", peerId);
    let peerConnection = createPeerConnection(peerId);

    peerConnection.createOffer().then((offer) => {
      peerConnection.setLocalDescription(offer);
      console.log("Sending WebRTC offer to:", peerId);
      channel.push("webrtc_offer", { offer: offer, to: peerId });
    }).catch((error) => {
      console.error("Error creating WebRTC offer for new peer:", peerId, error);
    });

    // Store the peer connection
    peerConnections[peerId] = peerConnection;
  });

  // Find peers that have left
  const removedPeers = peer_list.filter(peer => !updatedPeers.includes(peer));

  // Close connections to removed peers
  removedPeers.forEach((peerId) => {
    console.log("Closing connection to removed peer:", peerId);
    if (peerConnections[peerId]) {
      peerConnections[peerId].close();
      delete peerConnections[peerId];
    }
  });

  // Update the local peer list
  peer_list = updatedPeers;
  console.log("Local peer list updated:", peer_list);
});

/*
************************************************************
******************* WEBRTC FUNCTIONS ***********************
************************************************************
*/

/*
Handle data channels
- Stores open channels in dataChannels
- Handles incoming messages and updates to the editor
*/
function setupDataChannel(dataChannel, peerId) {
  console.log("Setting up data channel with peer:", peerId);

  dataChannel.onopen = () => {
    console.log("Data channel open with peer:", peerId);
    dataChannels[peerId] = dataChannel;
  };

  dataChannel.onmessage = (event) => {
    console.log("Received message from peer:", peerId, "Message:", event.data);

    // Parse data
    let payload = JSON.parse(event.data);

    // Handle document updates
    if (payload.type === "insert") {
      let currentText = editor.value;
      editor.value =
        currentText.slice(0, payload.position) +
        payload.char +
        currentText.slice(payload.position);
    } else if (payload.type === "delete") {
      let currentText = editor.value;
      editor.value =
        currentText.slice(0, payload.position) +
        currentText.slice(payload.position + 1);
    }
  };

  dataChannel.onclose = () => {
    console.log("Data channel closed with peer:", peerId);
    delete dataChannels[peerId];
  };
}

/*
Create a new RTCPeerConnection for a peer
- Handles incoming RTCDataChannel events
*/
function createPeerConnection(peerId) {
  console.log(`Creating peer connection for peer: ${peerId}`);

  // Define the WebRTC configuration for STUN/TURN servers
  const configuration = {
    iceServers: [{ urls: "stun:stun.l.google.com:19302" }] // google STUN server
  };

  // Create a new RTCPeerConnection using the LAN-only configuration
  let peerConnection = new RTCPeerConnection(configuration);

  // Handle ICE candidates
  peerConnection.onicecandidate = (event) => {
    if (event.candidate) {
      console.log("Sending ICE candidate to peer:", peerId);
      channel.push("ice_candidate", { candidate: event.candidate, to: peerId });
    } else {
      console.log("All ICE candidates sent");
    }
  };  

  // Handle data channels
  peerConnection.ondatachannel = (event) => {
    console.log("Data channel created by remote peer:", peerId);
    setupDataChannel(event.channel, peerId);
  };

  // Create a data channel for sending/receiving messages
  let dataChannel = peerConnection.createDataChannel("editor");
  setupDataChannel(dataChannel, peerId);

  return peerConnection;
}

/*
Capture the changes in the editor and broadcast them to peers
- Sends insert or delete events via RTCDataChannel
*/
editor.addEventListener("input", (event) => {
  let char = event.data; // inserted char
  let position = editor.selectionStart - 1; // cursor position before input

  // Broadcast changes to all connected peers
  Object.values(dataChannels).forEach((dataChannel) => {
    if (dataChannel.readyState === "open") {
      let peerPayload = char
        ? { type: "insert", id: Date.now(), char: char, position: position }
        : { type: "delete", id: Date.now(), position: editor.selectionStart };

      dataChannel.send(JSON.stringify(peerPayload));
    }
  });
});

/*
************************************************************
******************** PRESENCE FUNCTIONS ********************
************************************************************
*/

/*
Format and render the presences in the UI
- Converts the "presence" object into an array of [id, presence] for easier iteration
- Extracts the first metadata entry for each user
- Creates an HTML list item (<li>) for each user and dynamically applies their assigned color
- Joins all generated list items into a single string to update the DOM efficiently
*/
let renderPresences = (presences) => {
  const userList = Object.entries(Presence.list(presences)).map(([id, presence]) => {
    const { username, color } = presence.metas[0];

    return `
      <li style="color: ${color}">
        ${username}
      </li> `;
  }).join("");

  document.querySelector("#user-list").innerHTML = userList;
};

/*
Listen for the initial presence state from the server
- The "presence_state" event provides the full list of users connected to the channel
- Syncs the initial state with the local "presences" object
- Renders the list of users in the UI
*/
channel.on("presence_state", (state) => {
  presences = Presence.syncState(presences, state);
  renderPresences(presences);
});

/*
Listen for updates to the presence state from the server
- The "presence_diff" event provides updates about users joining or leaving the channel
- Applies the changes to the local "presences" object
- Renders the list of users in the UI
*/
// Handle presence updates
channel.on("presence_diff", (diff) => {
  presences = Presence.syncDiff(presences, diff);
  renderPresences(presences);
});
