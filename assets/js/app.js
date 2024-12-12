import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Get CSRF token for security
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
// Define Phoenix LiveView hooks
let Hooks = {};

// Editor hook for handling real-time text updates
Hooks.EditorHook = {
    mounted() {
        console.log("EditorHook mounted");
        let editor = this.el;

        // Handle incoming text updates from other users via LiveView push_event
        this.handleEvent("text_updated", ({ text }) => {
            console.log("Updating editor with text:", text);
            editor.value = text;
        });

        // Event listener for local user input
        editor.addEventListener("input", (event) => {
            let ch_value = event.data; // inserted char
            let cursor_position = editor.selectionStart; // cursor position before input
            
            // Send the appropriate event to LiveView based on the input type
            if (ch_value != null){
                this.pushEvent("insert_character", { ch_value: ch_value, position: cursor_position - 1 });
            } else
            {
                this.pushEvent("delete_character", { position: cursor_position });
            }
        });
    }
};

// Define live socket and connect to the live endpoint
let liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken }, hooks: Hooks 
})

console.log("LiveSocket initialized", liveSocket);

liveSocket.connect()

console.log("LiveSocket connected");
